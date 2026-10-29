import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { test } from "node:test";

const utilitiesUrl = new URL("./dashboard-utils.js", import.meta.url).href;

// Set TZ before importing the utilities: formatDate caches its formatter at load time.
const probe = `
  import { formatDate, formatDateTime } from ${JSON.stringify(utilitiesUrl)};

  process.stdout.write(JSON.stringify({
    timeZone: new Intl.DateTimeFormat().resolvedOptions().timeZone,
    dateOnlyWinter: formatDate("2026-01-15"),
    dateOnlySummer: formatDate("2026-07-15"),
    timestampDateWinter: formatDate("2026-01-15T00:30:00Z"),
    timestampDateSummer: formatDate("2026-07-15T00:30:00Z"),
    dateObjectSummer: formatDate(new Date("2026-07-15T00:30:00Z")),
    dateTimeWinter: formatDateTime("2026-01-15T00:30:00Z"),
    dateTimeSummer: formatDateTime("2026-07-15T00:30:00Z"),
  }));
`;

const sharedCases = [
  ["date-only winter input keeps its calendar date", "dateOnlyWinter", "January 15, 2026"],
  ["date-only summer input keeps its calendar date", "dateOnlySummer", "July 15, 2026"],
];

const zoneCases = {
  UTC: [
    ["winter timestamp uses the local calendar date", "timestampDateWinter", "January 15, 2026"],
    ["summer timestamp uses the local calendar date", "timestampDateSummer", "July 15, 2026"],
    ["Date object uses the local calendar date", "dateObjectSummer", "July 15, 2026"],
    ["winter datetime includes the local hour and minute", "dateTimeWinter", "January 15, 2026 at 12:30 AM"],
    ["summer datetime includes the local hour and minute", "dateTimeSummer", "July 15, 2026 at 12:30 AM"],
  ],
  "America/Los_Angeles": [
    ["winter timestamp uses the local calendar date", "timestampDateWinter", "January 14, 2026"],
    ["summer timestamp uses the local calendar date", "timestampDateSummer", "July 14, 2026"],
    ["Date object uses the local calendar date", "dateObjectSummer", "July 14, 2026"],
    ["winter datetime uses Pacific standard time", "dateTimeWinter", "January 14, 2026 at 4:30 PM"],
    ["summer datetime uses Pacific daylight time", "dateTimeSummer", "July 14, 2026 at 5:30 PM"],
  ],
};

for (const [timeZone, cases] of Object.entries(zoneCases)) {
  test(`date formatting in ${timeZone}`, async (t) => {
    const output = execFileSync(process.execPath, ["--input-type=module", "--eval", probe], {
      encoding: "utf8",
      env: { ...process.env, TZ: timeZone },
      timeout: 10_000,
    });
    const actual = JSON.parse(output);

    assert.equal(actual.timeZone, timeZone, "The probe must use the requested time zone");

    for (const [name, key, expected] of [...sharedCases, ...cases]) {
      await t.test(name, () => {
        assert.equal(actual[key], expected);
      });
    }
  });
}
