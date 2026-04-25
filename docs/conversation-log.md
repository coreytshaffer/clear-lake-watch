# Conversation Log

This document captures the working context from the Codex conversation that started on April 17, 2026. It is not a verbatim transcript; it is a project memory aid for future development.

## Original Goal

Build a publicly available dashboard for environmental information related to the health of Clear Lake in Lake County, California.

The dashboard should pull from public online sources and support a later machine-learning goal: predicting cyanobacterial harmful algal bloom severity in different arms of the lake.

## User Context

- The project owner is an Environmental Science student at SNHU and a beginner-to-intermediate Python developer.
- Relevant interests include water-quality monitoring, GIS, IoT sensors, environmental data pipelines, and edge AI/ML.
- Preferred standards include Python 3.11+, PEP 8, type hints, modular design, explicit errors, and no global package installs.
- The project should remain transparent, public-source based, and careful about public-health interpretation.

## Dashboard Direction

The first implementation should be static and no-build so it can be inspected, edited, and published easily while source contracts are still being validated.

Core public sections:

- Latest public snapshot
- Hydrology trends
- Recent FHABS reports
- Advisory mix
- Arm-level summaries
- Map layer
- Normalized data products
- Historical analytics
- Public methodology and disclaimers

The dashboard must keep observed data, reports, advisories, geographic context, and future forecasts visually distinct.

## Public Sources Identified

- Lake County CLAMP monitoring
- Big Valley Band of Pomo Indians cyanotoxin monitoring
- California Water Boards FHABS data
- California satellite HAB map
- USGS lake-level and tributary data
- CEDEN chemistry data
- OpenStreetMap shoreline geometry

## Major Implementation Milestones

### Static MVP

Created the initial static dashboard:

- `index.html`
- `methodology.html`
- `styles.css`
- `app.js`
- `data/sources.json`
- `docs/source-audit.md`
- `README.md`

### Public Data Refresh

Added `scripts/refresh-live-data.ps1` to fetch and normalize public USGS and FHABS data into dashboard JSON files:

- `data/live.json`
- `data/reports.json`
- `data/observations.json`
- `data/sites-normalized.json`
- `data/analytics.json`

The dashboard displays source observation dates separately from dashboard refresh dates.

### Site Registry

Added `data/sites.json` as a starter site registry with stable IDs, aliases, coordinates, arm assignments, assignment status, and matching radii.

The refresh pipeline attempts these matching methods:

- `source-id`
- `alias`
- `proximity`
- `heuristic`

FHABS landmarks marked `needs-local-review` should be reviewed before being treated as authoritative.

### Demo Server

The local demo has been run from:

```text
C:\Users\corey\Documents\Codex\2026-04-17-i-want-to-build-a-publicly
```

Local URL:

```text
http://127.0.0.1:4173/
```

Historical server PID and log files are runtime artifacts, not source assets. The dashboard launcher now keeps runtime files outside the static web root so local process state and logs are not accidentally served or published.

### Data Freshness

On April 20, 2026, the public data refresh produced:

- USGS data current through April 18, 2026 in the source feed.
- Latest Clear Lake FHABS report: September 7, 2025, Soda Bay, `Caution`.
- Latest FHABS lab-linked sample: January 11, 2024.

The dashboard now includes a freshness badge and keeps observation dates explicit.

### Field And Microscopy Stretch Goal

Captured a future feature for authenticated lakeside data entry, including work performed on behalf of NOAA for freshwater phytoplankton sampling and light-microscope identification.

Design decision:

- Do not make this a direct public submission form.
- Use a reviewed intake workflow with QA before public display or model training.

Minimum metadata should include:

- Sample date and time
- Collector
- Organization or program
- Site
- GPS precision
- Lake arm
- Sample type
- Preservation method
- Microscope method
- Magnification
- Taxon name
- Identification confidence
- Abundance estimate
- Photo or voucher reference
- QA reviewer
- Permission-to-publish status

### External Review Response

An external review suggested improvements around accessibility, active navigation, data freshness, dark mode, bar-chart readability, marker focus behavior, and mobile polish.

Implemented items include:

- Skip links
- Larger nav touch targets
- Active nav state via `IntersectionObserver`
- Data freshness badge
- Dark-mode toggle
- Accessible sparkline labels
- Safer map marker projection
- Focus movement to marker details
- Solid analytical bar fills
- Observation coverage show-all behavior

Chart.js and external fonts were intentionally deferred to preserve the current no-build/static architecture.

### OpenStreetMap Shoreline Geometry

The user asked whether OpenStreetMap could populate the lake overlay and later asked to replicate the shoreline geometry using publicly available data.

Implemented:

- `scripts/refresh-osm-shoreline.ps1`
- `data/lake-shoreline.json`

The shoreline is fetched from OpenStreetMap relation `4046481` using Overpass, then cached as static JSON.

Current generated geometry:

- One outer shoreline ring
- Eleven inner island rings
- 2,784 coordinate points

Dashboard behavior:

- Use OSM geometry when `data/lake-shoreline.json` is available.
- Fall back to the original schematic path if the file is unavailable.
- Keep OSM attribution and ODbL license links visible under the map.

Important design decision:

- OSM is used as geographic context only.
- OSM is not used as a water-quality, advisory, bloom, or monitoring-data source.

## Verification Performed

Repeated checks during the conversation included:

- PowerShell public-data refresh script runs successfully.
- OSM shoreline refresh script runs successfully.
- `data/sources.json`, `data/live.json`, and `data/lake-shoreline.json` parse as JSON.
- Dashboard and methodology endpoints return `200`.
- `app.js` passes `node --check`.
- Browser smoke tests in Microsoft Edge confirmed rendering, live cards, map markers, freshness badge, active nav, dark-mode toggle, OSM shoreline path, OSM attribution, and shoreline data product.
- `scripts/validate-dashboard.ps1` checks required files, JSON shape, source/output manifest data, public/private runtime-file separation, weather-context guardrails, page separation, and trust labels.

## April 22, 2026 Trust-Hardening Update

The public prototype moved from a combined dashboard/project page into two clearer surfaces:

- `index.html` is now focused on public situational awareness.
- `project.html` holds the source inventory, module roadmap, guardrails, phases, and future ML roadmap.
- `methodology.html` links back to both surfaces.

Additional public trust surfaces were added:

- A source-status panel summarizes `data/manifest.json`.
- A generated-output panel lists public snapshot artifacts.
- Manifest notes explain source freshness and interpretation limits.
- A site-registry QA strip summarizes registry sites, current markers, reviewed markers, and records needing local review.
- A weather-context panel reads `data/weather-context.json` and currently shows an explicit unavailable status until the environmental monitoring backbone has live telemetry proof.

The weather bridge is now documented by `docs/weather-context-contract.md` and represented by both `data/weather-context.json` and `data/weather-context.example.json`.

Important boundary:

- Weather context is driver/context information only.
- It remains separate from lake-health interpretation and is not public-health guidance.

Environment note:

- Git was not available in the local PowerShell session during this work, so validation used targeted file checks, JSON parsing, JavaScript syntax checks, dashboard validation, local HTTP checks, and browser smoke tests.

## April 22, 2026 Site-Registry QA Triage

The site-registry review workflow was upgraded from a flat queue into a prioritized QA queue.

Implemented:

- `scripts/build-site-review-report.ps1` now assigns `reviewPriority`, `reviewReason`, and a targeted `recommendedReviewAction` to each current mapped marker.
- `data/site-review.json` now summarizes high-, medium-, and low-priority review counts.
- `docs/site-registry-review.md` now includes priority and evidence-note columns.
- `docs/site-registry-high-priority.md` now provides a focused review packet with map links and decision checklists for the current high-priority markers.
- `docs/site-registry-decision-workflow.md` and `data/site-review-decisions.example.json` define a review-before-write decision path before changing registry assignments.
- `scripts/preview-site-review-decisions.ps1` validates proposed decisions and prints a dry-run preview without modifying registry files.
- The dashboard site-registry QA strip now includes a high-priority checks card.
- The map now includes a trust filter for all markers, reviewed-only markers, and markers needing local review.
- `scripts/validate-dashboard.ps1` now emits non-failing warnings when all current markers still need local review or high-priority review items remain open.
- `scripts/validate-dashboard.ps1` checks the new site-review fields.

Current generated review split:

- High priority: 2 current markers
- Medium priority: 3 current markers
- Low priority: 3 current markers

Important boundary:

- This pass did not promote FHABS sites to `reviewed-local`.
- It made the review queue more actionable while preserving conservative `needs-local-review` status until local landmark/arm review is actually complete.

## Current High-Value Next Steps

1. Review the two high-priority FHABS site-registry checks first: `Jones bay` matched by proximity and `Riveria Point Launch at Henderson Point in Soda Bay` with a large registry offset.
2. Move detailed review queues and future private observations behind a private intake/review surface while keeping public exports sanitized.
3. Generate a real `weather-context.json` export from the environmental monitoring backbone after live weather telemetry is proven.
4. Add CLAMP, CEDEN, or Tribal cyanotoxin ingestion once source contracts are stable.
5. Use the map trust filter while reviewing site-registry assignments so public viewers can distinguish reviewed sites from provisional context.
6. Define ML severity labels only after reviewed data contracts, source boundaries, and training exclusions are documented.

## Guardrails To Preserve

- This dashboard is not official public-health guidance.
- Observation dates matter more than dashboard generation dates.
- Public reports are not the same as bloom severity.
- Satellite and OSM layers are contextual, not direct health determinations.
- Future forecasts must be labeled experimental.
- Field and microscopy records require QA review before public use.

## April 22, 2026 Restore Recovery And Shortcut Check

After an unexpected power loss and system restore to roughly 2 PM, the active project folder was confirmed as:

```text
C:\Users\corey\Documents\Codex\2026-04-17 Clear Lake Watch
```

Recovery actions:

- Restored the missing `app.js` into the active project folder from the surviving restored folder.
- Re-applied the map trust filter wiring and high-priority site-review card logic.
- Restored `assets\clear-lake-watch.ico`.
- Created a Desktop shortcut and project shortcut with `scripts\create-windows-shortcut.ps1`.
- Verified the shortcut launches the local dashboard through `scripts\launch-dashboard.ps1`.

Validation after recovery:

- `app.js` passed JavaScript syntax validation.
- All JSON files under `data\` parsed successfully.
- `scripts\preview-site-review-decisions.ps1` ran as a no-write preview.
- `scripts\validate-dashboard.ps1 -SkipHttp` passed.
- Full HTTP validation passed while the local server was running.
- Browser smoke confirmed the map trust filter: 8 all markers, 0 reviewed markers, and 8 needs-review markers.

Environment notes:

- Windows PowerShell 5.1 can run the project scripts.
- PowerShell 7 (`pwsh`) appears damaged after restore because built-in module folders such as `Microsoft.PowerShell.Management` are empty.
- Git was still unavailable on PATH during recovery diagnostics.
- The older slug folder `C:\Users\corey\Documents\Codex\2026-04-17-i-want-to-build-a-publicly` exists but appears to be only a partial restored artifact.

## April 22, 2026 County GIS Geometry Candidate

The local Lake County public GIS bundle from the North Shore Risk Analysis work was inspected for better Clear Lake geometry.

Candidate source:

```text
C:\Users\corey\Documents\Codex\North Shore Risk Analysis Document\02_data_raw\lake_county_public_gis_2026_04_21\extracted\waterfeatures\lakes.shp
```

Implementation:

- Added `scripts\refresh-county-shoreline-candidate.ps1`.
- Generated a raw county candidate and two simplified browser candidates.
- Added `geometry-preview.html` as a local comparison page for OSM vs county GIS geometry.

Comparison:

- Current OSM `data\lake-shoreline.json`: 12 rings, 2,784 points, about 609 KB.
- Raw county candidate: 15 rings, 41,778 points, about 9.1 MB.
- County 25 ft simplified candidate: 15 rings, 2,946 points, about 646 KB.
- County 50 ft simplified candidate: 15 rings, 1,683 points, about 372 KB.

Decision pending:

- Whether to promote the 25 ft simplified Lake County GIS candidate into `data\lake-shoreline.json`.
- Before promotion, confirm public attribution and publication terms for the county GIS layer.

## April 22, 2026 County GIS Public-Use Check

The Lake County GIS shoreline candidate was checked against official county GIS pages, the public `WaterFeatures` ArcGIS REST service, the public ArcGIS portal metadata, and the local shapefile metadata.

Decision:

- Do not promote the county candidate yet.
- Keep the OpenStreetMap-derived shoreline as the active public dashboard geometry.
- Keep the county JSON outputs as internal candidate-review artifacts.

Reason:

- The county GIS portal and `WaterFeatures` service are public-facing, and the service names `USGS; Lake County CA I.T. Dept` as copyright text.
- The local shapefile metadata describes the source lineage, but its access/use constraint fields contain placeholder required text rather than actual public reuse terms.
- Public visibility is not the same as an explicit license to redistribute derived coordinate JSON inside the static dashboard bundle.

Follow-up:

- Added `docs\county-gis-public-use-check.md`.
- Updated `docs\source-audit.md` and `README.md` to point future work to the conservative public-use decision.

## April 22, 2026 Henderson Point / Riviera Point Registry Split

The FHABS landmark `Riveria Point Launch at Henderson Point in Soda Bay` was reviewed as a likely `Riviera Point` spelling issue near Henderson Point rather than a generic Soda Bay marker.

Implementation:

- Added unresolved registry site `fhabs-henderson-point`.
- Preserved FHABS source spelling `Riveria Point Launch at Henderson Point in Soda Bay` as an alias.
- Added likely corrected spelling `Riviera Point Launch at Henderson Point in Soda Bay` as an alias.
- Regenerated `data\live.json`, `data\manifest.json`, `data\sites-normalized.json`, `data\site-review.json`, `docs\site-registry-review.md`, and `docs\site-registry-high-priority.md`.

Trust boundary:

- The marker now resolves to `Henderson Point / Riviera Point Launch` instead of generic `Soda Bay`.
- The site remains `needs-local-review`; this is a better unresolved match, not local certification.

## April 22, 2026 Local Git Availability Check

The project backlog item for Git availability was investigated.

Findings:

- `git` is not available on the default shell `PATH`.
- System Git was not found under `C:\Program Files\Git`.
- GitHub Desktop's bundled Git was found under the user profile.
- The bundled Git reports `git version 2.47.3.windows.1`.
- The active Clear Lake Watch folder is not currently a Git repository, so `git --no-pager diff` cannot work until a repository decision is made.

Implementation:

- Added `scripts\find-local-git.ps1`.
- Added `docs\local-git-workflow.md`.
- Updated deployment notes, README, and backlog status.

Decision pending:

- Initialize this folder as a repository, move it into a cloned repository, or manage it through GitHub Desktop.

## April 23, 2026 Rumsey Gage Height Card Update

The Lakeport lake-level card was updated to show the USGS gage-height value explicitly as feet Rumsey.

Implementation:

- Added a Rumsey zero constant to `scripts\refresh-live-data.ps1`.
- Updated the Lakeport live card value to use `ft Rumsey`.
- Added approximate water-surface elevation context using Zero Rumsey = 1318.256 ft above mean sea level.
- Added validation checks so the Rumsey label and zero-elevation context stay visible in `data\live.json`.

Trust boundary:

- This is hydrology context from USGS station `11450000`.
- It remains driver/context information, not a direct lake-health or public-health advisory.

## April 23, 2026 Forecast Boundary Contract

The forecasting backlog item was hardened without adding any live forecast output.

Implementation:

- Added `docs\forecast-boundary.md`.
- Added `data\forecast-output.example.json`.
- Updated the project-page forecasting copy to point future work at the boundary contract.
- Updated the ML roadmap responsible-release copy to require model date, training window, input summary, uncertainty notes, and public-health disclaimer language.

Trust boundary:

- Forecasting remains experimental and not live.
- Forecast output must not be mixed into current observed conditions or official/advisory records.
- Unreviewed field observations, private reviewer notes, unresolved site assignments, and unpublished microscopy records must not be used as labels or public forecast inputs.
