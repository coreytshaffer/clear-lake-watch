import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import {
  calendarAgeDays,
  evaluateObservation,
  parseInstant,
  projectManifestSource,
  projectWeatherContext,
} from "./freshness-status.js";

const loadFixture = (name) =>
  JSON.parse(
    readFileSync(new URL(`../tests/fixtures/freshness/${name}`, import.meta.url), "utf8"),
  );

const deepFreeze = (value) => {
  if (typeof value === "object" && value !== null && !Object.isFrozen(value)) {
    Object.values(value).forEach(deepFreeze);
    Object.freeze(value);
  }

  return value;
};

const moduleUrl = new URL("./freshness-status.js", import.meta.url).href;
const PACIFIC = "America/Los_Angeles";
const SIX_HOURS = { limit: 21600, unit: "seconds" };
const FOURTEEN_DAYS = { limit: 14, unit: "calendar_days" };
const at = (iso) => Date.parse(iso);

const operational = (observedThrough, budget = SIX_HOURS) => ({
  observedThrough,
  mode: "operational",
  budget,
  timeZone: PACIFIC,
});

// The module must use the caller's clock exclusively.
const withForbiddenNow = (callback) => {
  const originalNow = Date.now;
  Date.now = () => {
    throw new Error("freshness-status.js must not read the ambient clock");
  };

  try {
    return callback();
  } finally {
    Date.now = originalNow;
  }
};

test("weather elapsed age is inclusive at the limit", () => {
  const observedAt = "2026-11-17T06:00:00Z";
  const cases = [
    ["2026-11-17T11:59:59Z", 21599, "within_expected_lag"],
    ["2026-11-17T12:00:00Z", 21600, "within_expected_lag"],
    ["2026-11-17T12:00:00.001Z", 21600.001, "lagging"],
    ["2026-11-17T12:00:01Z", 21601, "lagging"],
  ];

  withForbiddenNow(() => {
    for (const [asOf, age, dataCurrency] of cases) {
      assert.deepEqual(
        evaluateObservation(operational(observedAt), at(asOf)),
        { dataCurrency, age, limit: 21600, unit: "seconds", reason: null },
        `observation ${observedAt} evaluated at ${asOf}`,
      );
    }
  });
});

const calendarProbe = `
  import { calendarAgeDays, evaluateObservation } from ${JSON.stringify(moduleUrl)};

  const pairs = [
    ["2026-11-02", "2026-11-17T07:59:59Z", "2026-11-17T08:00:00Z"],
    ["2026-07-01", "2026-07-16T06:59:59Z", "2026-07-16T07:00:00Z"],
  ];
  const budget = { limit: 14, unit: "calendar_days" };
  const rows = [];

  for (const [date, before, after] of pairs) {
    for (const asOf of [before, after]) {
      const asOfMs = Date.parse(asOf);
      rows.push({
        date,
        asOf,
        age: calendarAgeDays(date, asOfMs, "America/Los_Angeles"),
        evaluation: evaluateObservation(
          { observedThrough: date, mode: "operational", budget, timeZone: "America/Los_Angeles" },
          asOfMs,
        ),
      });
    }
  }

  process.stdout.write(JSON.stringify({
    timeZone: new Intl.DateTimeFormat().resolvedOptions().timeZone,
    rows,
  }));
`;

test("calendar age changes at Pacific midnight", async (t) => {
  const expected = [
    ["2026-11-02", "2026-11-17T07:59:59Z", 14, "within_expected_lag"],
    ["2026-11-02", "2026-11-17T08:00:00Z", 15, "lagging"],
    ["2026-07-01", "2026-07-16T06:59:59Z", 14, "within_expected_lag"],
    ["2026-07-01", "2026-07-16T07:00:00Z", 15, "lagging"],
  ];

  for (const hostZone of ["UTC", PACIFIC, "Asia/Tokyo"]) {
    await t.test(`host TZ=${hostZone}`, () => {
      const output = execFileSync(
        process.execPath,
        ["--input-type=module", "--eval", calendarProbe],
        { encoding: "utf8", env: { ...process.env, TZ: hostZone }, timeout: 10_000 },
      );
      const actual = JSON.parse(output);

      assert.equal(actual.timeZone, hostZone, "The probe must run in the requested host zone");
      assert.equal(actual.rows.length, expected.length);

      expected.forEach(([date, asOf, age, dataCurrency], index) => {
        const row = actual.rows[index];
        assert.equal(row.date, date);
        assert.equal(row.asOf, asOf);
        assert.equal(row.age, age, `${date} at ${asOf}`);
        assert.deepEqual(row.evaluation, {
          dataCurrency,
          age,
          limit: 14,
          unit: "calendar_days",
          reason: null,
        });
      });
    });
  }
});

test("accept offset-bearing exports at millisecond precision", () => {
  withForbiddenNow(() => {
    const parsed = parseInstant("2026-05-13T23:17:06.3490220-07:00");
    assert.equal(typeof parsed, "number");
    assert.equal(new Date(parsed).toISOString(), "2026-05-14T06:17:06.349Z");

    // Fractional seconds are truncated, never rounded up into the next millisecond.
    assert.equal(
      new Date(parseInstant("2026-05-14T05:57:00.9999999+00:00")).toISOString(),
      "2026-05-14T05:57:00.999Z",
    );
    assert.equal(
      new Date(parseInstant("2026-11-17T12:00:00.1Z")).toISOString(),
      "2026-11-17T12:00:00.100Z",
    );
    assert.equal(
      new Date(parseInstant("2024-02-29T00:00:00+14:00")).toISOString(),
      "2024-02-28T10:00:00.000Z",
    );

    const rejected = [
      ["February 30", "2026-02-30T12:00:00Z"],
      ["February 29 in a common year", "2026-02-29T12:00:00Z"],
      ["24:00", "2026-11-17T24:00:00Z"],
      ["offset-free local datetime", "2026-11-17T12:00:00"],
      ["date-only string", "2026-11-17"],
      ["numeric input", Date.parse("2026-11-17T12:00:00Z")],
      ["ten fractional digits", "2026-11-17T12:00:00.0000000000Z"],
      ["leap second", "2026-12-31T23:59:60Z"],
      ["offset without colon", "2026-11-17T12:00:00-0700"],
      ["offset minutes out of range", "2026-11-17T12:00:00-07:60"],
      ["lowercase designators", "2026-11-17t12:00:00z"],
      ["surrounding whitespace", " 2026-11-17T12:00:00Z"],
      ["empty string", ""],
      ["null", null],
      ["undefined", undefined],
      ["Date object", new Date("2026-11-17T12:00:00Z")],
    ];

    for (const [label, value] of rejected) {
      assert.equal(parseInstant(value), null, label);
    }
  });
});

test("calendarAgeDays rejects unusable dates, clocks, and zones", () => {
  const asOfMs = at("2026-11-17T12:00:00Z");

  withForbiddenNow(() => {
    assert.equal(calendarAgeDays("2026-11-17", asOfMs, PACIFIC), 0);
    assert.equal(calendarAgeDays("2026-11-18", asOfMs, PACIFIC), -1);
    assert.equal(calendarAgeDays("2026-02-30", asOfMs, PACIFIC), null);
    assert.equal(calendarAgeDays("2026-11-17T00:00:00Z", asOfMs, PACIFIC), null);
    assert.equal(calendarAgeDays("2026-11-17", Number.NaN, PACIFIC), null);
    assert.equal(calendarAgeDays("2026-11-17", "2026-11-17T12:00:00Z", PACIFIC), null);
    assert.equal(calendarAgeDays("2026-11-17", asOfMs, "Not/AZone"), null);
    assert.equal(calendarAgeDays("2026-11-17", asOfMs, undefined), null);
  });
});

test("unknown evidence has an explicit reason", () => {
  const asOfIso = "2026-11-17T12:00:00Z";
  const asOfMs = at(asOfIso);
  const unknown = (reason) => ({
    dataCurrency: "unknown",
    age: null,
    limit: null,
    unit: null,
    reason,
  });

  const cases = [
    ["null observation", operational(null), asOfMs, "missing_observation"],
    ["undefined observation", operational(undefined), asOfMs, "missing_observation"],
    ["blank observation", operational("  "), asOfMs, "missing_observation"],
    ["February 30 instant", operational("2026-02-30T06:00:00Z"), asOfMs, "invalid_observation"],
    [
      "February 30 date",
      operational("2026-02-30", FOURTEEN_DAYS),
      asOfMs,
      "invalid_observation",
    ],
    ["offset-free observation", operational("2026-11-17T06:00:00"), asOfMs, "invalid_observation"],
    ["numeric observation", operational(asOfMs - 1000), asOfMs, "invalid_observation"],
    [
      "observation one millisecond after the clock",
      operational("2026-11-17T12:00:00.001Z"),
      asOfMs,
      "future_observation",
    ],
    [
      "date after the Pacific evaluation day",
      operational("2026-11-18", FOURTEEN_DAYS),
      asOfMs,
      "future_observation",
    ],
    [
      "operational observation without a budget",
      { observedThrough: "2026-11-17T06:00:00Z", mode: "operational", timeZone: PACIFIC },
      asOfMs,
      "missing_budget",
    ],
    [
      "operational observation with a null budget",
      operational("2026-11-17T06:00:00Z", null),
      asOfMs,
      "missing_budget",
    ],
    [
      "negative limit",
      operational("2026-11-17T06:00:00Z", { limit: -1, unit: "seconds" }),
      asOfMs,
      "invalid_budget",
    ],
    [
      "non-numeric limit",
      operational("2026-11-17T06:00:00Z", { limit: "21600", unit: "seconds" }),
      asOfMs,
      "invalid_budget",
    ],
    [
      "unrecognized unit",
      operational("2026-11-17T06:00:00Z", { limit: 6, unit: "hours" }),
      asOfMs,
      "invalid_budget",
    ],
    [
      "date-only observation against a seconds budget",
      operational("2026-11-17", SIX_HOURS),
      asOfMs,
      "invalid_budget",
    ],
    [
      "instant observation against a calendar-day budget",
      operational("2026-11-17T06:00:00Z", FOURTEEN_DAYS),
      asOfMs,
      "invalid_budget",
    ],
    [
      "unrecognized mode",
      { ...operational("2026-11-17T06:00:00Z"), mode: "live" },
      asOfMs,
      "invalid_budget",
    ],
    ["NaN as-of", operational("2026-11-17T06:00:00Z"), Number.NaN, "invalid_clock"],
    ["string as-of", operational("2026-11-17T06:00:00Z"), asOfIso, "invalid_clock"],
    ["missing as-of", operational("2026-11-17T06:00:00Z"), undefined, "invalid_clock"],
    [
      "date-only arithmetic without a time zone",
      { ...operational("2026-11-02", FOURTEEN_DAYS), timeZone: undefined },
      asOfMs,
      "invalid_clock",
    ],
  ];

  withForbiddenNow(() => {
    for (const [label, input, clock, reason] of cases) {
      assert.deepEqual(evaluateObservation(input, clock), unknown(reason), label);
    }
  });
});

test("reviewed snapshot dates are historical without an age claim", () => {
  const asOfMs = at("2026-11-17T12:00:00Z");
  const reviewed = (observedThrough, extra = {}) => ({
    observedThrough,
    mode: "reviewed_snapshot",
    timeZone: PACIFIC,
    ...extra,
  });

  withForbiddenNow(() => {
    for (const date of ["2024-01-11", "2026-11-17"]) {
      assert.deepEqual(evaluateObservation(reviewed(date), asOfMs), {
        dataCurrency: "historical",
        age: null,
        limit: null,
        unit: null,
        reason: null,
      });
    }

    // The reviewed mode ignores any budget instead of turning it into an age claim.
    assert.equal(
      evaluateObservation(reviewed("2024-01-11", { budget: FOURTEEN_DAYS }), asOfMs).dataCurrency,
      "historical",
    );
    assert.equal(
      evaluateObservation(reviewed("2026-11-18"), asOfMs).reason,
      "future_observation",
    );
    assert.equal(
      evaluateObservation(reviewed("2026-02-30"), asOfMs).reason,
      "invalid_observation",
    );
    assert.equal(evaluateObservation(reviewed(null), asOfMs).reason, "missing_observation");
  });
});

// Task 2: projections of the pinned public replay inputs.
const REPLAY_CLOCK = at("2026-11-17T12:00:00Z");
const WEATHER_GENERATED_AT = "2026-05-14T06:17:06.349Z";
const KELC1_OBSERVED_AT = "2026-05-14T05:57:00.000Z";
const MANIFEST_GENERATED_AT = "2026-05-05T08:44:50.025Z";

const unknownBecause = (reason) => ({
  dataCurrency: "unknown",
  age: null,
  limit: null,
  unit: null,
  reason,
});

test("weather status and station ages are independent", () => {
  const weather = deepFreeze(loadFixture("clw-weather-context-2026-05-13.json"));
  const atLimit = at("2026-05-14T11:57:00Z");
  const overLimit = at("2026-05-14T11:57:01Z");
  const kelc1 = (evaluation) => ({
    stationId: "KELC1",
    displayName: "KONOCTI",
    observedThrough: KELC1_OBSERVED_AT,
    evaluation,
  });
  const within = (age) => ({
    dataCurrency: "within_expected_lag",
    age,
    limit: 21600,
    unit: "seconds",
    reason: null,
  });
  const lagging = (age) => ({ ...within(age), dataCurrency: "lagging" });

  withForbiddenNow(() => {
    assert.deepEqual(projectWeatherContext(weather, atLimit), {
      exportStatus: "partial",
      snapshotGeneratedAt: WEATHER_GENERATED_AT,
      staleAfterHours: 6,
      stations: [kelc1(within(21600))],
      currentObservationsAllowed: false,
    });

    // The stored, age-independent status does not move when the station ages out.
    assert.deepEqual(projectWeatherContext(weather, overLimit), {
      exportStatus: "partial",
      snapshotGeneratedAt: WEATHER_GENERATED_AT,
      staleAfterHours: 6,
      stations: [kelc1(lagging(21601))],
      currentObservationsAllowed: false,
    });

    // A stored "live" status cannot rescue an over-limit observation.
    const storedLive = deepFreeze({ ...weather, machineReadableStatus: "live" });
    assert.deepEqual(projectWeatherContext(storedLive, overLimit), {
      exportStatus: "live",
      snapshotGeneratedAt: WEATHER_GENERATED_AT,
      staleAfterHours: 6,
      stations: [kelc1(lagging(21601))],
      currentObservationsAllowed: false,
    });

    // A second station observed one second earlier gets its own statement.
    const mixed = deepFreeze({
      ...weather,
      stations: [
        weather.stations[0],
        {
          ...weather.stations[0],
          stationId: "TEST2",
          displayName: "Second test station",
          observedAt: "2026-05-14T05:56:59Z",
        },
      ],
    });
    const mixedProjection = projectWeatherContext(mixed, atLimit);
    assert.equal(mixedProjection.currentObservationsAllowed, false);
    assert.deepEqual(mixedProjection.stations, [
      kelc1(within(21600)),
      {
        stationId: "TEST2",
        displayName: "Second test station",
        observedThrough: "2026-05-14T05:56:59.000Z",
        evaluation: lagging(21601),
      },
    ]);
  });
});

test("generation and stored results cannot fill missing observations", async (t) => {
  const weather = deepFreeze(loadFixture("clw-weather-context-2026-05-13.json"));
  const manifest = deepFreeze(loadFixture("clw-manifest-2026-05-05.json"));
  const withStation = (overrides, exportOverrides = {}) =>
    deepFreeze({
      ...weather,
      ...exportOverrides,
      stations: [{ ...weather.stations[0], ...overrides }],
    });
  const { observedAt: _omitted, ...stationWithoutTime } = weather.stations[0];

  await t.test("weather observation problems null the observation evidence", () => {
    const cases = [
      ["null observedAt", withStation({ observedAt: null }), "missing_observation"],
      [
        "absent observedAt",
        deepFreeze({ ...weather, stations: [stationWithoutTime] }),
        "missing_observation",
      ],
      [
        "malformed observedAt",
        withStation({ observedAt: "2026-02-30T05:57:00Z" }),
        "invalid_observation",
      ],
      [
        "offset-free observedAt",
        withStation({ observedAt: "2026-05-14T05:57:00" }),
        "invalid_observation",
      ],
      ["date-only observedAt", withStation({ observedAt: "2026-05-14" }), "invalid_observation"],
      [
        "future observedAt",
        withStation({ observedAt: "2026-11-17T12:00:00.001Z" }),
        "future_observation",
      ],
    ];

    withForbiddenNow(() => {
      for (const [label, exportData, reason] of cases) {
        const projection = projectWeatherContext(exportData, REPLAY_CLOCK);
        assert.equal(projection.snapshotGeneratedAt, WEATHER_GENERATED_AT, label);
        assert.equal(projection.exportStatus, "partial", label);
        assert.equal(projection.stations.length, 1, label);
        assert.equal(projection.stations[0].stationId, "KELC1", label);
        assert.equal(projection.stations[0].observedThrough, null, label);
        assert.deepEqual(projection.stations[0].evaluation, unknownBecause(reason), label);
      }
    });
  });

  await t.test("unusable weather budgets keep the observation time visible", () => {
    const cases = [
      ['numeric-string "6"', { staleAfterHours: "6" }, "invalid_budget"],
      ["zero", { staleAfterHours: 0 }, "invalid_budget"],
      ["negative", { staleAfterHours: -6 }, "invalid_budget"],
      ["null", { staleAfterHours: null }, "missing_budget"],
    ];

    withForbiddenNow(() => {
      for (const [label, exportOverrides, reason] of cases) {
        const projection = projectWeatherContext(withStation({}, exportOverrides), REPLAY_CLOCK);
        assert.equal(projection.staleAfterHours, null, label);
        assert.equal(projection.stations[0].observedThrough, KELC1_OBSERVED_AT, label);
        assert.deepEqual(projection.stations[0].evaluation, unknownBecause(reason), label);
      }

      const { staleAfterHours: _absent, ...withoutBudget } = weather;
      const projection = projectWeatherContext(deepFreeze(withoutBudget), REPLAY_CLOCK);
      assert.equal(projection.stations[0].observedThrough, KELC1_OBSERVED_AT);
      assert.deepEqual(projection.stations[0].evaluation, unknownBecause("missing_budget"));
    });
  });

  await t.test("weather export status and station lists normalize conservatively", () => {
    withForbiddenNow(() => {
      const statusOf = (machineReadableStatus) =>
        projectWeatherContext(deepFreeze({ ...weather, machineReadableStatus }), REPLAY_CLOCK)
          .exportStatus;

      assert.equal(statusOf("stale"), "stale");
      assert.equal(statusOf("unavailable"), "unavailable");
      assert.equal(statusOf(" Live "), "live");
      assert.equal(statusOf("ok"), "unknown");
      assert.equal(statusOf(undefined), "unknown");
      assert.equal(statusOf(""), "unknown");

      const empty = projectWeatherContext(deepFreeze({ ...weather, stations: [] }), REPLAY_CLOCK);
      assert.deepEqual(empty.stations, []);
      const { stations: _none, ...stationless } = weather;
      assert.deepEqual(projectWeatherContext(deepFreeze(stationless), REPLAY_CLOCK).stations, []);

      const badGeneration = projectWeatherContext(
        deepFreeze({ ...weather, generatedAt: "2026-05-13T23:17:06" }),
        REPLAY_CLOCK,
      );
      assert.equal(badGeneration.snapshotGeneratedAt, null);
      assert.equal(badGeneration.stations[0].evaluation.dataCurrency, "lagging");

      assert.deepEqual(projectWeatherContext(null, REPLAY_CLOCK), {
        exportStatus: "unknown",
        snapshotGeneratedAt: null,
        staleAfterHours: null,
        stations: [],
        currentObservationsAllowed: false,
      });
    });
  });

  await t.test("manifest status and observation are separate evidence", () => {
    const {
      status: _status,
      latestObservationDate: _observation,
      ...stripped
    } = manifest.sources[0];

    withForbiddenNow(() => {
      assert.deepEqual(projectManifestSource(deepFreeze(stripped), manifest, REPLAY_CLOCK), {
        sourceLoadState: "unknown",
        observedThrough: null,
        snapshotGeneratedAt: MANIFEST_GENERATED_AT,
        sourceResourceDate: null,
        resourceDaysBeforeSnapshot: null,
        dataCurrency: "unknown",
        currentObservationsAllowed: false,
      });

      const restored = projectManifestSource(
        deepFreeze({ ...stripped, status: "ok" }),
        manifest,
        REPLAY_CLOCK,
      );
      assert.equal(restored.sourceLoadState, "loaded");
      assert.equal(restored.dataCurrency, "unknown");
      assert.equal(restored.observedThrough, null);

      const loadStateOf = (status) =>
        projectManifestSource(deepFreeze({ ...stripped, status }), manifest, REPLAY_CLOCK)
          .sourceLoadState;
      assert.equal(loadStateOf("   "), "unknown");
      assert.equal(loadStateOf(null), "unknown");
      assert.equal(loadStateOf("error"), "attention");
      assert.equal(loadStateOf("stale"), "attention");
    });
  });

  await t.test("a calendar date after generation is not historical evidence", () => {
    const source = manifest.sources[0];
    const projectDate = (latestObservationDate, manifestData = manifest, clock = REPLAY_CLOCK) =>
      projectManifestSource(
        deepFreeze({ ...source, latestObservationDate }),
        manifestData,
        clock,
      );

    withForbiddenNow(() => {
      // Generation is 2026-05-05 in the source's Pacific calendar.
      const afterGeneration = projectDate("2026-05-06");
      assert.equal(afterGeneration.observedThrough, null);
      assert.equal(afterGeneration.dataCurrency, "unknown");

      const generationDay = projectDate("2026-05-05");
      assert.equal(generationDay.observedThrough, "2026-05-05");
      assert.equal(generationDay.dataCurrency, "historical");

      // Without a usable generation instant, the render date is the only bound.
      const noGeneration = deepFreeze({ ...manifest, generatedAt: "not-a-time" });
      assert.equal(projectDate("2026-05-06", noGeneration).dataCurrency, "historical");
      assert.equal(projectDate("2026-11-18", noGeneration).dataCurrency, "unknown");
      assert.equal(projectDate("2026-11-18", noGeneration).observedThrough, null);

      // The render date bounds even a valid generation date.
      assert.equal(
        projectDate("2026-05-03", manifest, at("2026-05-02T12:00:00Z")).dataCurrency,
        "unknown",
      );

      assert.equal(projectDate("2026-02-30").dataCurrency, "unknown");
      assert.equal(projectDate("2026-05-03T00:00:00Z").dataCurrency, "unknown");
    });
  });

  await t.test("resource dates stay separate from observation dates", () => {
    const fhabs = manifest.sources.find((source) => source.id === "fhabs-results");
    const project = (sourceOverrides, manifestData = manifest) =>
      projectManifestSource(deepFreeze({ ...fhabs, ...sourceOverrides }), manifestData, REPLAY_CLOCK);

    withForbiddenNow(() => {
      const afterGeneration = project({ resourceDate: "2026-05-06" });
      assert.equal(afterGeneration.sourceResourceDate, "2026-05-06");
      assert.equal(afterGeneration.resourceDaysBeforeSnapshot, null);

      const sameDay = project({ resourceDate: "2026-05-05" });
      assert.equal(sameDay.resourceDaysBeforeSnapshot, 0);

      const noGeneration = project({}, deepFreeze({ ...manifest, generatedAt: null }));
      assert.equal(noGeneration.sourceResourceDate, "2026-05-04");
      assert.equal(noGeneration.resourceDaysBeforeSnapshot, null);
      assert.equal(noGeneration.snapshotGeneratedAt, null);

      const invalid = project({ resourceDate: "2026-02-30" });
      assert.equal(invalid.sourceResourceDate, null);
      assert.equal(invalid.resourceDaysBeforeSnapshot, null);
    });
  });
});

test("four source clocks replay as reviewed history", () => {
  const expected = {
    "usgs-lake-level": ["2026-05-03", null, null],
    "usgs-cole-creek-discharge": ["2026-05-03", null, null],
    "fhabs-bloom-reports": ["2025-09-07", "2026-05-04", 1],
    "fhabs-results": ["2024-01-11", "2026-05-04", 1],
  };
  const pinned = deepFreeze(loadFixture("clw-manifest-2026-05-05.json"));
  const conflicting = loadFixture("clw-manifest-2026-05-05.json");
  conflicting.sources.forEach((source) => {
    if (source.id.startsWith("fhabs-")) {
      source.resourceAgeDays = 999;
    }
  });
  deepFreeze(conflicting);

  const replay = (manifest) =>
    manifest.sources.map((source) => [source.id, projectManifestSource(source, manifest, REPLAY_CLOCK)]);

  withForbiddenNow(() => {
    for (const manifest of [pinned, conflicting]) {
      const rows = replay(manifest);
      assert.deepEqual(
        rows.map(([id]) => id),
        Object.keys(expected),
        "source identity and order are preserved",
      );

      for (const [id, projection] of rows) {
        const [observedThrough, sourceResourceDate, resourceDaysBeforeSnapshot] = expected[id];
        assert.deepEqual(
          projection,
          {
            sourceLoadState: "loaded",
            observedThrough,
            snapshotGeneratedAt: MANIFEST_GENERATED_AT,
            sourceResourceDate,
            resourceDaysBeforeSnapshot,
            dataCurrency: "historical",
            currentObservationsAllowed: false,
          },
          id,
        );
      }
    }

    assert.deepEqual(replay(pinned), replay(pinned), "identical replays are equal");
    assert.deepEqual(replay(conflicting), replay(pinned), "stored resourceAgeDays is ignored");
  });
});
