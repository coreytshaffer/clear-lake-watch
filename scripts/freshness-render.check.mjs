// Local production-page check for observation freshness (CHE-22).
//
// Serves this checkout on an ephemeral loopback port, loads the real
// index.html/app.js in Chromium with a frozen page clock, substitutes only the
// manifest and weather-context fixture paths, and asserts the rendered DOM.
// A separate context with the service worker enabled checks that the shipped
// static cache includes the freshness module.
//
//   node scripts/freshness-render.check.mjs
//
// Playwright is not a project dependency. Set PLAYWRIGHT_MODULE to the
// absolute path of a Playwright package entry point (for example an isolated
// install's node_modules/playwright/index.js), or run from a directory where
// `require("playwright")` resolves. Keep that installation outside the checkout.

import { readFileSync } from "node:fs";
import { readFile, stat } from "node:fs/promises";
import { createServer } from "node:http";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const FIXTURE_DIR = path.join(ROOT, "tests", "fixtures", "freshness");
const STATIC_CACHE = "clear-lake-watch-static-v5";
const FRESHNESS_MODULE_PATH = "/scripts/freshness-status.js";

const MIME_TYPES = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".ico": "image/x-icon",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".pdf": "application/pdf",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".webmanifest": "application/manifest+json",
};

const readJson = (filePath) => JSON.parse(readFileSync(filePath, "utf8"));
const pinnedManifest = () => readJson(path.join(FIXTURE_DIR, "clw-manifest-2026-05-05.json"));
const pinnedWeather = () =>
  readJson(path.join(FIXTURE_DIR, "clw-weather-context-2026-05-13.json"));
const unavailableWeather = () => readJson(path.join(ROOT, "data", "weather-context.example.json"));

const loadPlaywright = async () => {
  const explicitPath = process.env.PLAYWRIGHT_MODULE;

  if (explicitPath) {
    const loaded = await import(pathToFileURL(path.resolve(explicitPath)).href);
    return loaded.chromium ? loaded : loaded.default;
  }

  try {
    return createRequire(path.join(process.cwd(), "noop.cjs"))("playwright");
  } catch (error) {
    throw new Error(
      "Playwright could not be loaded. Set PLAYWRIGHT_MODULE to the absolute path of a " +
        `Playwright package entry point outside this checkout. (${error.message})`,
    );
  }
};

const startServer = () =>
  new Promise((resolve, reject) => {
    const server = createServer(async (request, response) => {
      try {
        const { pathname } = new URL(request.url, "http://127.0.0.1");
        const relative = decodeURIComponent(pathname).replace(/^\/+/, "") || "index.html";
        const filePath = path.resolve(ROOT, relative);
        const insideRoot = filePath.startsWith(`${ROOT}${path.sep}`);
        const hidden = relative.split("/").some((segment) => segment.startsWith("."));
        const info = insideRoot && !hidden ? await stat(filePath).catch(() => null) : null;

        if (!info?.isFile()) {
          response.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
          response.end("Not found");
          return;
        }

        response.writeHead(200, {
          "cache-control": "no-store",
          "content-type":
            MIME_TYPES[path.extname(filePath).toLowerCase()] ?? "application/octet-stream",
        });
        response.end(await readFile(filePath));
      } catch (error) {
        response.writeHead(500, { "content-type": "text/plain; charset=utf-8" });
        response.end(String(error));
      }
    });

    server.on("error", reject);
    server.listen(0, "127.0.0.1", () => resolve(server));
  });

const isLoopback = (url) => {
  const { protocol, hostname } = new URL(url);
  return (
    ["data:", "blob:", "about:"].includes(protocol) ||
    hostname === "127.0.0.1" ||
    hostname === "localhost" ||
    hostname === "[::1]"
  );
};

const normalize = (text) => (text ?? "").replace(/\s+/g, " ").trim();

// ---------------------------------------------------------------------------
// Page inspection helpers

const cardsIn = (page, gridSelector) =>
  page.$$eval(`${gridSelector} > *`, (elements) =>
    elements.map((element) => ({
      text: element.textContent.replace(/\s+/g, " ").trim(),
      visible: element.getClientRects().length > 0 &&
        getComputedStyle(element).visibility !== "hidden",
      times: Array.from(element.querySelectorAll("time")).map((time) => ({
        datetime: time.getAttribute("datetime"),
        text: time.textContent.replace(/\s+/g, " ").trim(),
      })),
      exactTexts: Array.from(element.querySelectorAll("*"))
        .filter((child) => child.children.length === 0)
        .map((child) => child.textContent.replace(/\s+/g, " ").trim()),
      // Snapshot strip cards: label and value as separate fields.
      label: element.querySelector(".stat-label")?.textContent.replace(/\s+/g, " ").trim() ?? null,
      value:
        element.querySelector(".snapshot-status-value")?.textContent.replace(/\s+/g, " ").trim() ??
        null,
    })),
  );

const stripValue = (stripCards, label) =>
  stripCards.find((card) => card.label === label)?.value ?? null;

const assertStripValue = (check, stripCards, label, expected) => {
  const actual = stripValue(stripCards, label);
  check.ok(actual === expected, `snapshot strip "${label}": expected "${expected}", saw "${actual}"`);
};

const makeChecker = () => {
  const failures = [];
  return {
    failures,
    ok(condition, message) {
      if (!condition) {
        failures.push(message);
      }
    },
    includes(haystack, needle, where) {
      if (!haystack.includes(needle)) {
        failures.push(`${where}: expected text "${needle}"`);
      }
    },
    excludes(haystack, needle, where) {
      if (haystack.includes(needle)) {
        failures.push(`${where}: unexpected text "${needle}"`);
      }
    },
  };
};

const findCard = (cards, needle) => cards.find((card) => card.text.includes(needle));

const assertObservationTime = (check, card, where) => {
  const time = card?.times.find((entry) => entry.datetime === "2026-05-14T05:57:00.000Z");
  check.ok(Boolean(time), `${where}: missing <time datetime="2026-05-14T05:57:00.000Z">`);

  if (time) {
    check.ok(
      time.text === "May 13, 2026 at 10:57 PM PDT",
      `${where}: observation time text was "${time.text}"`,
    );
  }
};

const assertGenerationShownSeparately = (check, cards, where) => {
  const generation = cards
    .flatMap((card) => card.times)
    .find((entry) => entry.datetime === "2026-05-14T06:17:06.349Z");
  check.ok(Boolean(generation), `${where}: missing export generation <time>`);
  check.ok(
    cards.some((card) => card.text.includes("Export generated:")),
    `${where}: missing "Export generated:" line`,
  );
};

const assertNoBareLive = (check, cards, where) => {
  for (const card of cards) {
    for (const text of card.exactTexts) {
      check.ok(!/^live$/i.test(text), `${where}: bare "Live" label`);
      check.ok(!/^status:\s*live$/i.test(text), `${where}: bare "Status: Live" label`);
    }

    const stripped = card.text.replaceAll("Reported live by source", "");
    check.ok(!/\blive\b/i.test(stripped.replaceAll("Not live", "")), `${where}: live claim in "${card.text}"`);
  }
};

const assertFourSourceCards = (check, sourceCards, where) => {
  const visible = sourceCards.filter((card) => card.visible);
  check.ok(visible.length === 4, `${where}: expected 4 visible source cards, saw ${visible.length}`);
};

// ---------------------------------------------------------------------------
// Cases

const T = "2026-11-17T12:00:00Z";
const AT_LIMIT = "2026-05-14T11:57:00Z";
const ONE_SECOND_BEFORE_LIMIT = "2026-05-14T11:56:59Z";
const ONE_SECOND_OVER_LIMIT = "2026-05-14T11:57:01Z";

const withinStatement = "Observation within expected age (6 hours)";
const exceedsStatement = "Observation exceeds expected age (6 hours)";

const weatherAgeCase = (name, asOf, timezoneId, expectStale) => ({
  name,
  asOf,
  timezoneId,
  substitutions: { weather: pinnedWeather(), manifest: pinnedManifest() },
  async verify({ weatherCards }, check) {
    const all = weatherCards.map((card) => card.text).join(" | ");
    const station = findCard(weatherCards, "KELC1");

    check.includes(all, "Reviewed public-source snapshot", "weather grid");
    check.includes(all, "Export status at generation: Partial", "weather grid");
    check.ok(Boolean(station), "weather grid: no KELC1 station card");
    assertObservationTime(check, station, "KELC1 card");
    assertGenerationShownSeparately(check, weatherCards, "weather grid");

    if (station) {
      if (expectStale) {
        check.includes(station.text, exceedsStatement, "KELC1 card");
        check.includes(station.text, "Stale observation", "KELC1 card");
        check.excludes(station.text, "within expected age", "KELC1 card");
      } else {
        check.includes(station.text, withinStatement, "KELC1 card");
        check.excludes(station.text, "exceeds expected age", "KELC1 card");
        check.excludes(station.text, "Stale observation", "KELC1 card");
      }
    }
  },
});

const buildCases = () => [
  weatherAgeCase("F01 one second before limit", ONE_SECOND_BEFORE_LIMIT, "Asia/Tokyo", false),
  weatherAgeCase("F01 exactly at limit", AT_LIMIT, "Asia/Tokyo", false),
  weatherAgeCase("F01 exactly at limit (Pacific browser)", AT_LIMIT, "America/Los_Angeles", false),
  weatherAgeCase("F02 one second over limit", ONE_SECOND_OVER_LIMIT, "Asia/Tokyo", true),
  {
    name: "F02 stored live export over limit",
    asOf: ONE_SECOND_OVER_LIMIT,
    timezoneId: "UTC",
    substitutions: {
      weather: { ...pinnedWeather(), machineReadableStatus: "live" },
      manifest: pinnedManifest(),
    },
    async verify({ weatherCards }, check) {
      const all = weatherCards.map((card) => card.text).join(" | ");
      const station = findCard(weatherCards, "KELC1");

      check.includes(all, "Export status at generation: Reported live by source", "weather grid");
      assertNoBareLive(check, weatherCards, "weather grid");
      check.ok(Boolean(station), "weather grid: no KELC1 station card");
      check.includes(station?.text ?? "", exceedsStatement, "KELC1 card");
      check.includes(station?.text ?? "", "Stale observation", "KELC1 card");
    },
  },
  {
    name: "F02 mixed stations at limit",
    asOf: AT_LIMIT,
    timezoneId: "Asia/Tokyo",
    substitutions: {
      weather: (() => {
        const weather = pinnedWeather();
        weather.stations.push({
          ...weather.stations[0],
          stationId: "TEST2",
          displayName: "Second test station",
          observedAt: "2026-05-14T05:56:59Z",
        });
        return weather;
      })(),
      manifest: pinnedManifest(),
    },
    async verify({ weatherCards }, check) {
      const kelc1 = findCard(weatherCards, "KELC1");
      const second = findCard(weatherCards, "TEST2");

      check.ok(Boolean(kelc1), "weather grid: no KELC1 station card");
      check.ok(Boolean(second), "weather grid: no TEST2 station card");
      check.ok(kelc1 !== second, "weather grid: stations share one card");
      check.includes(kelc1?.text ?? "", withinStatement, "KELC1 card");
      check.excludes(kelc1?.text ?? "", "Stale observation", "KELC1 card");
      check.includes(second?.text ?? "", exceedsStatement, "TEST2 card");
      check.includes(second?.text ?? "", "Stale observation", "TEST2 card");
      const indexOf = (card) => weatherCards.indexOf(card);
      check.ok(indexOf(kelc1) < indexOf(second), "weather grid: stations out of input order");
    },
  },
  {
    name: "F04 missing observation and source status",
    asOf: T,
    timezoneId: "Asia/Tokyo",
    substitutions: {
      weather: (() => {
        const weather = pinnedWeather();
        weather.stations[0].observedAt = null;
        return weather;
      })(),
      manifest: (() => {
        const manifest = pinnedManifest();
        delete manifest.sources[0].status;
        delete manifest.sources[0].latestObservationDate;
        return manifest;
      })(),
    },
    async verify({ weatherCards, sourceCards }, check) {
      const all = weatherCards.map((card) => card.text).join(" | ");
      const station = findCard(weatherCards, "KELC1");

      check.includes(station?.text ?? "", "Observation time unavailable", "KELC1 card");
      check.excludes(all, "within expected age", "weather grid");
      check.excludes(all, "exceeds expected age", "weather grid");
      check.ok(
        !(station?.times ?? []).some((time) => time.datetime === "2026-05-14T06:17:06.349Z"),
        "KELC1 card: generation time used in place of the observation",
      );
      check.includes(sourceCards[0]?.text ?? "", "Source check status unknown", "first source card");
      check.includes(sourceCards[0]?.text ?? "", "Latest observation: unavailable", "first source card");
      check.excludes(sourceCards[0]?.text ?? "", "Historical observation", "first source card");
      assertFourSourceCards(check, sourceCards, "source grid");
    },
  },
  {
    name: "F08 reviewed history at T",
    asOf: T,
    timezoneId: "Asia/Tokyo",
    substitutions: { weather: pinnedWeather(), manifest: pinnedManifest() },
    async verify({ sourceCards, stripCards, freshnessBadge }, check) {
      const strip = stripCards.map((card) => card.text).join(" | ");
      check.includes(strip, "Reviewed snapshot generated", "snapshot strip");
      check.includes(strip, "May 5, 2026", "snapshot strip");
      assertStripValue(check, stripCards, "USGS observations through", "May 3, 2026");
      assertStripValue(check, stripCards, "Latest Clear Lake FHABS report", "September 7, 2025");
      assertStripValue(check, stripCards, "Latest FHABS lab-linked sample", "January 11, 2024");

      const expected = [
        ["USGS Lakeport lake level", "May 3, 2026", false],
        ["USGS Cole Creek discharge", "May 3, 2026", false],
        ["FHABS bloom reports", "September 7, 2025", true],
        ["FHABS lab results", "January 11, 2024", true],
      ];

      for (const [label, date, hasResource] of expected) {
        const card = findCard(sourceCards, label);
        const where = `${label} card`;
        check.ok(Boolean(card), `source grid: no ${label} card`);
        check.includes(card?.text ?? "", "Source loaded at snapshot generation", where);
        check.includes(card?.text ?? "", "Historical observation", where);
        check.includes(card?.text ?? "", `Latest observation: ${date}`, where);
        check.excludes(card?.text ?? "", "Resource file age", where);

        if (hasResource) {
          check.includes(
            card?.text ?? "",
            "Resource file date: May 4, 2026 (1 day before snapshot generation)",
            where,
          );
        } else {
          check.excludes(card?.text ?? "", "Resource file date", where);
        }
      }

      assertFourSourceCards(check, sourceCards, "source grid");
      check.ok(freshnessBadge?.visible === true, "lake snapshot age cue is not visible");
      check.ok(
        /^Snapshot is \d+ days old$/.test(freshnessBadge?.text ?? ""),
        `lake snapshot age cue text was "${freshnessBadge?.text}"`,
      );
    },
  },
  {
    name: "Weather unavailable (HTTP 404)",
    asOf: T,
    timezoneId: "Asia/Tokyo",
    substitutions: { weather: { status: 404 }, manifest: pinnedManifest() },
    async verify({ weatherCards, sourceCards, stripCards }, check) {
      const all = weatherCards.map((card) => card.text).join(" | ");
      check.includes(all, "Weather backbone not connected yet", "weather grid");
      check.excludes(all, "expected age", "weather grid");
      check.excludes(all, "Reviewed public-source snapshot", "weather grid");
      assertFourSourceCards(check, sourceCards, "source grid");
      check.includes(
        stripCards.map((card) => card.text).join(" | "),
        "Reviewed snapshot generated",
        "snapshot strip",
      );
    },
  },
  {
    name: "Weather unavailable export (no stations)",
    asOf: T,
    timezoneId: "Asia/Tokyo",
    substitutions: { weather: unavailableWeather(), manifest: pinnedManifest() },
    async verify({ weatherCards, sourceCards }, check) {
      const all = weatherCards.map((card) => card.text).join(" | ");
      check.includes(all, "Export status at generation: Unavailable", "weather grid");
      check.includes(all, "Observation time unavailable", "weather grid");
      check.excludes(all, "expected age", "weather grid");
      check.excludes(all, "Stale observation", "weather grid");
      check.excludes(all, "Reviewed public-source snapshot", "weather grid");
      assertNoBareLive(check, weatherCards, "weather grid");
      assertFourSourceCards(check, sourceCards, "source grid");
    },
  },
  {
    // One fixture, checked in both the source cards and the snapshot strip.
    name: "Unusable observation dates agree in cards and strip",
    asOf: T,
    timezoneId: "Asia/Tokyo",
    substitutions: {
      weather: pinnedWeather(),
      manifest: (() => {
        const manifest = pinnedManifest();
        const byId = (id) => manifest.sources.find((source) => source.id === id);
        // After the render date (2026-11-17 Pacific at T).
        byId("fhabs-bloom-reports").latestObservationDate = "2026-11-18";
        // After the 2026-05-05 Pacific generation date, before the render date.
        byId("usgs-lake-level").latestObservationDate = "2026-05-06";
        return manifest;
      })(),
    },
    async verify({ sourceCards, stripCards }, check) {
      for (const label of ["FHABS bloom reports", "USGS Lakeport lake level"]) {
        const card = findCard(sourceCards, label);
        check.includes(card?.text ?? "", "Latest observation: unavailable", `${label} card`);
        check.excludes(card?.text ?? "", "Historical observation", `${label} card`);
      }

      check.includes(
        findCard(sourceCards, "USGS Cole Creek discharge")?.text ?? "",
        "Latest observation: May 3, 2026",
        "USGS Cole Creek discharge card",
      );
      assertStripValue(check, stripCards, "Latest Clear Lake FHABS report", "Unavailable");
      assertStripValue(check, stripCards, "USGS observations through", "May 3, 2026");
      assertStripValue(check, stripCards, "Latest FHABS lab-linked sample", "January 11, 2024");

      const strip = stripCards.map((card) => card.text).join(" | ");
      check.excludes(strip, "November 18, 2026", "snapshot strip");
      check.excludes(strip, "May 6, 2026", "snapshot strip");
    },
  },
];

// ---------------------------------------------------------------------------
// Runner

// Defense in depth beside the per-context routes: no proxy, and no host
// resolves except the loopback server.
const LAUNCH_ARGS = [
  "--no-proxy-server",
  "--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE 127.0.0.1",
];

const guardNetwork = async (context, origin, blocked) => {
  context.on("request", (request) => {
    if (!isLoopback(request.url())) {
      blocked.push(request.url());
    }
  });

  await context.route("**/*", (route) => {
    const url = route.request().url();
    return isLoopback(url) && url.startsWith(origin) ? route.fallback() : route.abort();
  });
};

const substitute = async (context, origin, substitutions) => {
  const routes = {
    manifest: `${origin}/data/manifest.json`,
    weather: `${origin}/data/weather-context.json`,
  };

  for (const [key, body] of Object.entries(substitutions)) {
    await context.route(
      (url) => url.href.split("?")[0] === routes[key],
      (route) =>
        body?.status === 404
          ? route.fulfill({ status: 404, contentType: "text/plain", body: "Not found" })
          : route.fulfill({
              status: 200,
              contentType: "application/json; charset=utf-8",
              body: JSON.stringify(body),
            }),
    );
  }
};

const runCase = async (browser, origin, testCase) => {
  const check = makeChecker();
  const pageErrors = [];
  const blocked = [];
  const context = await browser.newContext({
    serviceWorkers: "block",
    timezoneId: testCase.timezoneId,
    locale: "en-US",
  });

  try {
    await guardNetwork(context, origin, blocked);
    await substitute(context, origin, testCase.substitutions);

    const page = await context.newPage();
    page.on("pageerror", (error) => pageErrors.push(error.message));
    await page.clock.setFixedTime(new Date(testCase.asOf));
    await page.goto(`${origin}/index.html`);
    await page.waitForFunction(
      () =>
        document.querySelector("#weather-context-grid")?.children.length > 0 &&
        document.querySelector("#source-status-grid")?.children.length > 0 &&
        document.querySelector("#snapshot-status-grid")?.children.length > 0,
      null,
      { timeout: 15_000 },
    );

    const evidence = {
      pageClock: await page.evaluate(() => new Date().toISOString()),
      weatherCards: await cardsIn(page, "#weather-context-grid"),
      sourceCards: await cardsIn(page, "#source-status-grid"),
      stripCards: await cardsIn(page, "#snapshot-status-grid"),
      freshnessBadge: await page
        .$eval("#freshness-row .freshness-badge", (badge) => ({
          text: badge.textContent.replace(/\s+/g, " ").trim(),
          visible: badge.getClientRects().length > 0,
        }))
        .catch(() => null),
    };

    check.ok(
      evidence.pageClock === new Date(testCase.asOf).toISOString(),
      `page clock was ${evidence.pageClock}`,
    );
    await testCase.verify(evidence, check);
    return { evidence, failures: check.failures, pageErrors, blocked };
  } catch (error) {
    return { evidence: null, failures: [...check.failures, error.message], pageErrors, blocked };
  } finally {
    await context.close();
  }
};

const runAssetCacheCheck = async (browser, origin) => {
  const failures = [];
  const blocked = [];
  const pageErrors = [];
  const context = await browser.newContext({ serviceWorkers: "allow", locale: "en-US" });

  try {
    context.on("request", (request) => {
      if (!isLoopback(request.url())) {
        blocked.push(request.url());
      }
    });

    const page = await context.newPage();
    page.on("pageerror", (error) => pageErrors.push(error.message));
    await page.goto(`${origin}/index.html`);
    const result = await page.evaluate(
      async ({ cacheName, modulePath }) => {
        const timeout = new Promise((_, reject) =>
          setTimeout(() => reject(new Error("service worker not ready after 15 s")), 15_000),
        );
        await Promise.race([navigator.serviceWorker.ready, timeout]);
        const cacheNames = await caches.keys();
        const cache = await caches.open(cacheName);
        const urls = (await cache.keys()).map((request) => request.url);
        const moduleUrl = new URL(`.${modulePath}`, location.href).href;
        return { cacheNames, moduleUrl, cached: urls.includes(moduleUrl), urlCount: urls.length };
      },
      { cacheName: STATIC_CACHE, modulePath: FRESHNESS_MODULE_PATH },
    );

    if (!result.cacheNames.includes(STATIC_CACHE)) {
      failures.push(`cache ${STATIC_CACHE} missing; saw ${result.cacheNames.join(", ") || "none"}`);
    }

    if (!result.cached) {
      failures.push(`${result.moduleUrl} is not in ${STATIC_CACHE}`);
    }

    return { evidence: result, failures, pageErrors, blocked };
  } catch (error) {
    return { evidence: null, failures: [...failures, error.message], pageErrors, blocked };
  } finally {
    await context.close();
  }
};

const summarize = (evidence) => {
  if (!evidence) {
    return [];
  }

  if (!evidence.weatherCards) {
    return [`    cache: ${JSON.stringify(evidence)}`];
  }

  const weather = evidence.weatherCards
    .filter((card) => !/^(Weather source|Air temperature|Relative humidity|Wind speed)\b/.test(card.text))
    .map((card) => card.text);
  return [
    `    page clock: ${evidence.pageClock}`,
    ...weather.map((text) => `    weather: ${text}`),
    `    source[0]: ${evidence.sourceCards[0]?.text ?? "(none)"}`,
    `    strip[0]: ${evidence.stripCards[0]?.text ?? "(none)"}`,
    `    age cue: ${evidence.freshnessBadge?.text ?? "(none)"}`,
  ];
};

const report = (name, detail, result) => {
  const failures = [
    ...result.failures,
    ...result.pageErrors.map((message) => `uncaught page error: ${message}`),
    ...result.blocked.map((url) => `non-loopback request attempted: ${url}`),
  ];
  console.log(`${failures.length ? "FAIL" : "PASS"} ${name} ${detail}`);
  summarize(result.evidence).forEach((line) => console.log(line));
  failures.forEach((failure) => console.log(`    ✗ ${failure}`));
  return failures.length === 0;
};

const main = async () => {
  const playwright = await loadPlaywright();
  const server = await startServer();
  const origin = `http://127.0.0.1:${server.address().port}`;
  let browser;
  let passed = 0;
  let failed = 0;

  try {
    browser = await playwright.chromium.launch({ args: LAUNCH_ARGS });
    console.log(`playwright ${playwright.chromium.name()} ${browser.version()} at ${origin}`);

    for (const testCase of buildCases()) {
      const result = await runCase(browser, origin, testCase);
      const ok = report(testCase.name, `(${testCase.timezoneId}, clock ${testCase.asOf})`, result);
      ok ? passed++ : failed++;
    }

    const cacheResult = await runAssetCacheCheck(browser, origin);
    const ok = report("Service worker static cache", `(${STATIC_CACHE})`, cacheResult);
    ok ? passed++ : failed++;
  } finally {
    await browser?.close();
    await new Promise((resolve) => server.close(resolve));
  }

  console.log(`${passed} passed, ${failed} failed`);
  return failed === 0 ? 0 : 1;
};

main().then(
  (code) => {
    process.exitCode = code;
  },
  (error) => {
    console.error(error);
    process.exitCode = 1;
  },
);
