# Weather Context Contract

This document defines the optional `data/weather-context.json` export used to
connect Clear Lake Watch to the broader environmental monitoring backbone.

The export is intentionally contextual. It can help explain recent rainfall,
wind, heat, and station-health conditions, but it must not silently become a
lake-health conclusion or public-health advisory.

## Purpose

`weather-context.json` gives the static Clear Lake Watch dashboard a
publication-safe way to read weather/soil backbone outputs without connecting
directly to MQTT, private databases, Grafana, or a local gateway.

The file should be generated upstream by the environmental monitoring backbone
after deterministic validation and publication filtering.

Until reviewed public-safe weather telemetry exists, use the local unavailable
writer to regenerate the honest not-connected export:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-weather-context-unavailable.ps1
```

This command updates `data/weather-context.json` without implying live weather
telemetry, lake-health interpretation, or public-health guidance.

For a reviewed public-source weather snapshot, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-weather-context-public-source.ps1
```

This command writes a public-safe weather.gov station snapshot. It should be
treated as environmental-driver context only, not live telemetry, not
lake-health interpretation, and not public-health guidance.

## Publication Boundary

The public dashboard may read:

- reviewed weather summary cards
- curated context windows
- station health labels
- quality notes
- coarse public station metadata

The public dashboard must not read:

- raw MQTT payloads
- internal broker URLs
- private device identifiers
- exact private station locations
- unpublished diagnostics
- unreviewed sensor records
- AI-generated lake-health claims

## Required Top-Level Fields

```json
{
  "schemaVersion": "weather-context-v1",
  "generatedAt": "2026-04-22T12:00:00-07:00",
  "sourceName": "Environmental Monitoring Backbone",
  "machineReadableStatus": "unavailable",
  "staleAfterHours": 6,
  "stations": [],
  "summaryCards": [],
  "contextWindows": [],
  "qualityNotes": []
}
```

## Status Values

Use one of these `machineReadableStatus` values:

- `live`
- `stale`
- `partial`
- `unavailable`

Use `partial` for a reviewed public-source snapshot that is useful as context
but is not a continuous local telemetry stream.

## Station Records

Station records should use this shape:

```json
{
  "stationId": "weather-site-01-public",
  "displayName": "Public Weather Station 01",
  "visibility": "public",
  "latitude": null,
  "longitude": null,
  "observedAt": "2026-04-22T11:55:00-07:00",
  "healthLabel": "ok",
  "metrics": [
    {
      "label": "Air temperature",
      "value": 21.4,
      "unit": "C",
      "status": "ok"
    }
  ]
}
```

If location precision is sensitive, use `null` for coordinates or publish only
a coarse public location label.

## Summary Cards

Summary cards are dashboard-friendly weather context records.

```json
{
  "label": "24-hour rainfall",
  "value": "0.0 mm",
  "note": "No measurable rainfall in the reviewed public weather window.",
  "status": "ok"
}
```

Recommended summary cards include:

- 24-hour rainfall
- 72-hour rainfall
- wind context
- heat context
- station health

## Context Windows

Context windows are derived environmental driver windows.

```json
{
  "label": "Wind context",
  "windowHours": 6,
  "summary": "Light winds; surface-scum movement context is limited.",
  "status": "context-only"
}
```

Context windows should be labeled as context, not causal claims.

## Quality Notes

Quality notes should explain source age, missing data, provisional status, or
publication limits.

Examples:

- `Weather context is unavailable until a public export is generated.`
- `Station location is generalized for privacy.`
- `Weather context is not an official lake-health interpretation.`

## Dashboard Behavior

If `data/weather-context.json` is missing, Clear Lake Watch should show an
explicit not-connected state and continue rendering the public lake-source
dashboard.

If the file exists but reports `stale`, `partial`, or `unavailable`, the
dashboard should display that status without suppressing the lake-source data.

### Two Weather Clocks

A weather export carries two different times, and the dashboard shows them
separately:

- `generatedAt` is when the export was written, and `machineReadableStatus` is
  the status stored at that time. The dashboard labels it "Export status at
  generation" and shows a stored `live` as "Reported live by source." It is
  never treated as an observation age.
- `stations[].observedAt` is when each station observation was made. Each
  station gets its own age statement against the export's `staleAfterHours`.

An observation is within the expected age while its elapsed age is at most
`staleAfterHours`. It exceeds the expected age only when strictly greater
(`age > limit`), compared in milliseconds before any display rounding, and the
station then shows a visible "Stale observation" cue. A missing, unreadable,
offset-free, or future `observedAt` shows "Observation time unavailable." A
valid `observedAt` with a missing or non-positive numeric `staleAfterHours`
shows "Observation age unavailable." The generation time never stands in for an
observation time.

Weather instants are displayed in fixed Pacific time with a zone abbreviation
(for example, "May 13, 2026 at 10:57 PM PDT"), whatever the viewer's browser
time zone.

### Page-Load Evaluation

The dashboard reads one clock value after its data files load and uses it for
every weather and lake-source freshness statement on the page. Ages are
evaluated once and are not refreshed while the page stays open; reloading the
page evaluates them again. Calendar-day arithmetic uses the America/Los_Angeles
calendar from the browser's bundled time-zone data.

Lake-source dates from `data/manifest.json` are shown as reviewed history: each
source card shows "Historical observation" with its latest observation date,
and FHABS cards show the resource file date and its distance from snapshot
generation. The stored `resourceAgeDays` value is not displayed. The snapshot
status strip uses the same validated dates, so a date the source card rejects
(after the render date or the snapshot generation date) shows as unavailable in
both places.

The evaluation logic lives in `scripts/freshness-status.js` and runs in CI with
`node --test scripts/freshness-status.test.mjs`.

### Local Browser Check

`scripts/freshness-render.check.mjs` loads the production page in Chromium with
a frozen page clock, substitutes only the manifest and weather-context fixture
paths, blocks non-loopback requests, and confirms that the service worker's
static cache includes the freshness module. Playwright is not a project
dependency; install it outside the checkout and point the check at it:

```bash
PLAYWRIGHT_MODULE=/absolute/path/to/node_modules/playwright/index.js node scripts/freshness-render.check.mjs
```

This check runs locally and is not part of CI.

## Unavailable Placeholder Format

The unavailable export is a placeholder format for when no reviewed weather
export exists: `machineReadableStatus` is `unavailable`, `stations` is empty,
and the quality notes say weather context is not connected. See
`data/weather-context.example.json` and
`scripts/write-weather-context-unavailable.ps1`. The dashboard shows its
generation status and "Observation time unavailable" with no observation-age
statement, and it does not label an `unavailable` export as a reviewed
public-source snapshot.

Use the placeholder until the environmental monitoring backbone has a reviewed
export with public-safe station metadata, reviewed metrics, and quality notes.

The placeholder may be regenerated for release hygiene, but regeneration is not evidence of live telemetry.

## Guardrail

Weather context can support interpretation of environmental drivers, but it
must remain separate from lake-health claims, cyanotoxin advisories, bloom
severity labels, and public-health guidance.
