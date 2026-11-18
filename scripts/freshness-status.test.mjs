import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { test } from "node:test";

import {
  calendarAgeDays,
  evaluateObservation,
  parseInstant,
} from "./freshness-status.js";

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
