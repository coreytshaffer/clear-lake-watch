# Clear Lake Watch

[![Status: Late Prototype / Early MVP](https://img.shields.io/badge/status-late%20prototype%20%2F%20early%20MVP-2f6f5f)](https://github.com/coreytshaffer/clear-lake-watch)
[![License: MIT](https://img.shields.io/badge/license-MIT-1f2937)](./LICENSE)
[![Live Dashboard](https://img.shields.io/badge/live%20dashboard-GitHub%20Pages-0b7285)](https://coreytshaffer.github.io/clear-lake-watch/)

Clear Lake Watch is a late-prototype / early-MVP public dashboard for organizing Clear Lake environmental context, source freshness, map review status, and cautious methodology notes.

It is not official public-health guidance, an official advisory, a validated forecast, or a deployed sensor network.

**Live public mirror:** [coreytshaffer.github.io/clear-lake-watch](https://coreytshaffer.github.io/clear-lake-watch/)

![Clear Lake Watch dashboard preview](assets/clear-lake-watch-preview.png)

## What This Public Mirror Shows

- Public environmental data integration across FHABS, USGS, and OpenStreetMap.
- Static dashboard pages that can be served directly from GitHub Pages.
- Source-status metadata and visible uncertainty around generated outputs.
- Site-registry review cues for markers that still need local review.
- Conservative methodology language for a sensitive environmental topic.

## Known Limitations

- This dashboard does not issue public-health, recreation, regulatory, or emergency guidance.
- Some FHABS landmarks still require local review before arm assignments should be treated as authoritative.
- Weather context is intentionally marked unavailable until reviewed public-safe telemetry exists.
- Field and microscopy workflows are represented as reviewed-public export placeholders, not public submission forms.

## Open First

- [Dashboard](index.html)
- [Project page](project.html)
- [Methodology](methodology.html)
- [Project brief](docs/project-brief.md)
- [Project brief PDF](docs/Clear-Lake-Watch-Project-Brief.pdf)
- [Portfolio case study](docs/clear_lake_watch_portfolio_case_study.md)
- [Public backlog](docs/public-backlog.md)
- [Public snapshot release note - 2026-05-13](docs/public-snapshot-release-note-2026-05-13.md)

## Public Documentation

- [Source audit](docs/source-audit.md)
- [Forecast boundary](docs/forecast-boundary.md)
- [Weather context contract](docs/weather-context-contract.md)
- [Field/microscopy intake contract](docs/field-microscopy-intake-contract.md)
- [Local-first operating model](docs/local-first-operating-model.md)
- [Public mirror boundary](docs/public-mirror-boundary.md)
- [Publication review checklist](docs/publication-review-checklist.md)
- [Public backlog](docs/public-backlog.md)
- [Public snapshot release note - 2026-05-13](docs/public-snapshot-release-note-2026-05-13.md)
- [Research readiness brief](docs/research-readiness-brief.md)
- [Published commentary tracker](docs/published-commentary.md)
- [Resume and LinkedIn snippets](docs/resume-linkedin-snippets.md)
- [Deployment notes](docs/deployment.md)

## Public Data Files

- `data/live.json`: compact current-condition snapshot for the dashboard
- `data/reports.json`: normalized FHABS Clear Lake report export
- `data/observations.json`: normalized USGS and FHABS observation records
- `data/sites.json`: starter site registry
- `data/sites-normalized.json`: normalized site registry export
- `data/site-review-summary.json`: public-safe aggregate site-review summary
- `data/analytics.json`: generated historical summaries for dashboard charts
- `data/manifest.json`: source-status manifest
- `data/lake-shoreline.json`: OpenStreetMap-derived Clear Lake shoreline geometry
- `data/weather-context.json`: public weather-context status, currently unavailable
- `data/reviewed-field-observations.json`: reviewed-public field/microscopy placeholder

## Validate This Mirror

Run the public mirror validation check from PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-public-mirror.ps1
```

If a local server is running on `http://127.0.0.1:4173/`, include endpoint checks:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-public-mirror.ps1 -CheckHttp
```

The broader private review packet and trusted-review materials are intentionally not part of this public mirror branch.
