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

## Guardrail

Weather context can support interpretation of environmental drivers, but it
must remain separate from lake-health claims, cyanotoxin advisories, bloom
severity labels, and public-health guidance.
