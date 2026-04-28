# Clear Lake Watch

This folder contains a late-prototype / early-MVP public Clear Lake environmental dashboard.

Clear Lake Watch is intended to become a lake-focused publication product on top of a broader local-first environmental monitoring backbone. The public dashboard should remain static, reviewed, and publication-safe, while private intake, QA, field observations, and future weather/soil telemetry stay behind reviewed export boundaries.

## Project brief

For a short shareable overview, see:

- [Project brief (Markdown)](docs/project-brief.md)
- [Project brief (PDF)](docs/Clear-Lake-Watch-Project-Brief.pdf)

## What is here

- `index.html`: Single-page dashboard prototype
- `project.html`: Project roadmap, source inventory, MVP modules, and implementation guardrails
- `methodology.html`: Public methodology, interpretation guidance, and disclaimer page
- `styles.css`: Visual system and responsive layout
- `app.js`: Client-side rendering from local JSON
- `data/sources.json`: Structured source inventory, arm strategy, MVP modules, and ML roadmap
- `data/live.json`: Latest generated public-data snapshot
- `data/sites.json`: Starter site registry for stable IDs, coordinates, and reviewed arm assignments
- `data/reports.json`: Normalized FHABS Clear Lake report export
- `data/observations.json`: Normalized observation export combining USGS daily values and FHABS results
- `data/sites-normalized.json`: Generated normalized copy of the site registry
- `data/site-review.json`: Generated site-registry and current-marker review queue
- `data/site-review-decisions.example.json`: Example review-before-write decision file for site-registry QA
- `data/analytics.json`: Generated historical summaries for dashboard charts
- `data/manifest.json`: Generated source-status manifest with source freshness, row counts, and output inventory
- `data/lake-shoreline.json`: OpenStreetMap-derived Clear Lake shoreline multipolygon used by the SVG map
- `data/lake-shoreline-county-simplified-25ft.json`: County GIS shoreline candidate for source/visual review
- `geometry-preview.html`: Local comparison page for OSM vs county GIS shoreline candidates
- `data/weather-context.json`: Current public weather-context status export, currently marked unavailable until live telemetry is reviewed
- `data/weather-context.example.json`: Example public-safe weather-context export from the shared backbone
- `data/forecast-output.example.json`: Example-only forecast output contract with required experimental metadata
- `docs/backlog.md`: Prioritized issue-style backlog for trust hardening and future work
- `docs/backbone-integration.md`: Shared-backbone boundary between Clear Lake Watch and the broader environmental monitoring platform
- `docs/conversation-log.md`: Project conversation memory, implementation decisions, and next-step context
- `docs/deployment.md`: Static hosting, validation, and public deployment notes
- `docs/forecast-boundary.md`: Experimental forecast-output boundary and required metadata
- `docs/local-git-workflow.md`: Local Git discovery and repository-decision notes
- `docs/site-registry-decision-workflow.md`: Review-before-write workflow for updating site-registry assignments
- `docs/site-registry-high-priority.md`: Focused review packet for the current high-priority FHABS marker checks
- `docs/weather-context-contract.md`: Schema and guardrails for optional weather-context integration
- `scripts/refresh-live-data.ps1`: Public-data refresh script for USGS and FHABS snapshot data
- `scripts/refresh-osm-shoreline.ps1`: Public OpenStreetMap shoreline refresh script
- `scripts/build-site-review-report.ps1`: Generates site-registry QA JSON and Markdown review queue
- `scripts/preview-site-review-decisions.ps1`: Dry-run checker for proposed site-registry review decisions
- `scripts/find-local-git.ps1`: Locates PATH, system, or GitHub Desktop Git without changing global settings
- `scripts/validate-dashboard.ps1`: Local validation checks for required files, JSON contracts, JavaScript syntax, and optional HTTP endpoints

## Current maturity

Status: late prototype / early MVP.

Already implemented:

- static public dashboard shell with dark mode, responsive layout, active navigation, and favicon
- public methodology and disclaimer page
- generated public-data snapshot loading from `data/live.json`
- USGS hydrology and FHABS-derived live snapshot cards, including Lakeport lake level in feet Rumsey with approximate water-surface elevation context
- OSM-derived Clear Lake shoreline overlay with attribution
- registry-backed map markers and arm summaries
- signal-type badges for observed, reported, derived, planning, and experimental content
- reporting-pattern analytics with inline caveats against bloom-severity overreading
- generated source-status manifest with public source, output, and interpretation-note panels
- source freshness and unavailable-state handling
- site-registry review queue generation
- visible site-registry QA summary for current map-marker review status
- prioritized site-registry review reasons and high-priority QA counts
- map trust filter for all, reviewed-only, and needs-review marker views
- optional weather-context dashboard panel with a clear not-connected state
- documented `weather-context.json` publication contract and example export
- dedicated project page for roadmap, source inventory, modules, and guardrails
- local validation and deployment notes

Still maturing:

- local review of prioritized FHABS landmark-to-arm assignments
- stronger trust checks around partial refreshes and source lag
- private intake/review surface for field and microscopy records
- live weather-context export from the shared environmental monitoring backbone
- public/private deployment posture for combined lake, weather, and field workflows

## Why this shape

The current dashboard is intentionally no-build. That keeps the public publication layer easy to open, edit, validate, and mirror while we harden the public data contracts for:

- Lake County CLAMP monitoring
- Big Valley cyanotoxin monitoring
- California Water Boards FHABS data
- California satellite HAB layers
- USGS tributary and lake-level drivers
- CEDEN chemistry history

## Next implementation priorities

1. Review the two high-priority site-registry checks identified in `docs/site-registry-high-priority.md` and record decisions using the workflow in `docs/site-registry-decision-workflow.md`.
2. Expand the snapshot manifest into a fuller QA panel for validation status, missing feeds, and source lag.
3. Harden analytics copy so report counts cannot be mistaken for bloom severity.
4. Generate a real `data/weather-context.json` export from the environmental monitoring backbone once public-safe weather telemetry exists.
5. Move detailed review queues and private field/microscopy workflows behind a private surface before they contain sensitive or unpublished data.
6. Keep the public dashboard focused on reviewed situational awareness while project planning remains on `project.html`.

## Site registry

`data/sites.json` is the maintained place for stable site IDs and arm assignments. The current file is a starter registry: USGS station assignments are reviewed starters, while FHABS landmarks should still get local review before they are treated as authoritative.

Use `data/site-review-decisions.example.json` as the review-before-write template before changing registry assignments. This keeps local evidence, reviewer notes, and publication decisions separate from generated public outputs.

For real review work, copy that shape into an ignored local file such as `data/site-review-decisions.local.json` so private reviewer notes are not published.

Preview proposed review decisions before editing the registry:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\preview-site-review-decisions.ps1 -DecisionPath .\data\site-review-decisions.local.json
```

The refresh script now attempts registry matching before falling back to heuristics:

- `source-id`: exact source identifier match
- `alias`: landmark or site text matched a registry alias
- `proximity`: coordinates fell within a registry site's match radius
- `heuristic`: no registry match, arm estimated from coordinates or text

## Generated data products

The refresh script writes six dashboard-ready JSON files:

- `data/live.json`: compact snapshot for the public dashboard
- `data/reports.json`: FHABS Clear Lake report records normalized to stable field names
- `data/observations.json`: observation-shaped records for USGS daily values and FHABS results
- `data/sites-normalized.json`: stable site registry export for joins, downloads, and future ML features
- `data/analytics.json`: report trends by year, advisory distributions by arm, and observation coverage summaries
- `data/manifest.json`: refresh/source-status manifest with source row counts, latest observation dates, resource file ages, generated outputs, and interpretation notes

The Lakeport lake-level card labels the USGS gage height as feet Rumsey and includes approximate water-surface elevation using Zero Rumsey = 1318.256 ft above mean sea level.

`scripts/build-site-review-report.ps1` writes `data/site-review.json`, `docs/site-registry-review.md`, and `docs/site-registry-high-priority.md`. These files make unresolved arm assignments visible without pretending they have been locally certified. The review queue includes priority, evidence notes, targeted review actions, map links, and decision checklists so local review can start with the most suspicious matches first.

The validator intentionally warns, rather than fails, when current map markers still need local review. That keeps the public trust cue visible while allowing the prototype to remain shareable during review.

`scripts/new-site-review-decisions.ps1` creates an ignored private starter file at `data/site-review-decisions.local.json` from the current high-priority queue. The generated decisions keep all items unresolved by default, so local evidence can be recorded before any registry changes are made.

The Henderson Point / Riviera Point Launch marker is now split from generic Soda Bay into its own unresolved `fhabs-henderson-point` registry entry. The source spelling `Riveria` is preserved as an alias, and the likely corrected `Riviera` spelling is included as a review hint. It remains `needs-local-review`.

`scripts/refresh-osm-shoreline.ps1` writes `data/lake-shoreline.json` from OpenStreetMap relation `4046481`. The dashboard uses this public geometry for the lake shoreline overlay and falls back to the original schematic if the file is unavailable.

`scripts/refresh-county-shoreline-candidate.ps1` can generate Lake County public GIS shoreline candidates from the local county GIS `waterfeatures/lakes` layer. These files are for source and visual review until attribution and public-use terms are confirmed. Use `geometry-preview.html` to compare the current OSM geometry against the 25 ft and 50 ft simplified county candidates. See `docs/county-gis-public-use-check.md` for the current conservative public-use decision.

## Public interpretation guidance

`methodology.html` explains how to read the dashboard, what each signal type means, and why the project should not be interpreted as official public-health guidance. Keep this page updated whenever new sources, forecast features, or site-assignment rules are added.

## Future field-data intake

A later stretch goal is to add authenticated data entry for lakeside field observations and freshwater phytoplankton sampling/identification performed with a light microscope, including work that may be collected on behalf of NOAA. This should be designed as a reviewed intake workflow rather than a direct public posting form.

Minimum fields should include sample date and time, collector, organization or program, site, GPS precision, lake arm, sample type, preservation method, microscope method, magnification, taxon name, identification confidence, abundance estimate, photo or voucher reference, QA reviewer, and permission-to-publish status.

These records should stay separate from public agency feeds until they pass review. Approved records can later support the dashboard, data exports, and ML features as a distinct "field/microscopy" source family.

## Local-first architecture

Clear Lake Watch should default to a local-first operating model wherever practical. The goal is to improve resilience during outages, reduce unnecessary cloud dependence, keep operational control close to the monitoring workflow, and limit higher-energy compute to places where it adds clear value.

### Design principle

Build the system as:

**edge collection -> local processing -> local storage -> optional sync/public mirror**

That means the monitoring stack should still be able to collect, store, review, and summarize data when public hosting, cloud APIs, or outside network access are temporarily unavailable.

### What stays local by default

- Sensor ingest and device control: edge devices should handle polling, timestamping, unit normalization, buffering, and basic health checks locally.
- Primary operational storage: raw observations, cleaned records, and reviewed intermediate products should be stored locally first.
- Dashboard generation: the public dashboard should continue to be generated from local JSON snapshots and static files.
- Core QA/QC and review workflows: site matching, validation, and reviewed publication decisions should not depend on a remote AI service.
- Basic analytics: threshold checks, simple summaries, and lightweight anomaly detection should run locally when feasible.

### Suggested operating tiers

#### Tier 1 - Edge node

Raspberry Pi, Jetson, or similar field-adjacent hardware can support sensor polling and buffering, local preprocessing, outage-tolerant caching, simple rule-based alerts, and optional lightweight on-device inference.

#### Tier 2 - Local hub

A home, lab, or community-hosted machine can serve as the operational hub for receiving synced data from edge nodes, storing canonical datasets, running normalization and validation scripts, regenerating dashboard-ready JSON files, and exposing a stable local API for future tools.

#### Tier 3 - Public mirror

A static host or secondary server can publish the public dashboard, normalized exports, methodology, and reviewed summaries. This layer should be treated as a publication target, not the only place the system can function.

### AI and model use

Any future LLM or edge-AI layer should be treated as an assistive feature over a stable local pipeline, not as a dependency for core monitoring functions.

Good uses include natural-language querying of local sensor data, operator support and troubleshooting, reviewed draft summaries of anomalies, and controlled experimental analyses through a local API.

Core functions that should still work without an LLM include ingest, storage, validation, reviewed publication, dashboard refresh, and basic alerting.

### Compute and carbon guardrail

Use the smallest sufficient compute for each task:

- rules and thresholds first
- lightweight local analytics second
- larger models only where they clearly improve interpretation or usability

The project should avoid placing heavyweight inference in the critical path for tasks that can be handled by simpler logic, cached computations, or direct database queries.

## Stretch goals

### Conversational edge monitoring

Explore a HydroSuite-AI-style conversational wrapper paired with edge-AI devices such as Raspberry Pi or Jetson nodes for Clear Lake monitoring. The goal would be to let reviewed field or community-science deployments query local sensor streams, run controlled diagnostics, and package on-device analyses for later review.

This should remain an experimental extension of LLM-assisted hydrology workflow patterns, not a replacement for the core telemetry, QA/QC, site registry, or public dashboard pipeline.

Guardrails:

- Any edge-agent output should remain reviewable, logged, and reproducible, including prompt history, model version, input data window, and generated result.
- Core monitoring functions must still work without an LLM layer.
- Community-science or field submissions generated through this path should remain separate from public agency feeds until reviewed.

### Weather sensing integration

If the separate weather-sensing project is connected later, the recommended shape is a shared environmental observability backbone with separate domain modules. Weather should feed Clear Lake Watch as contextual driver data, but atmospheric observations and lake-health interpretations should remain distinct in public-facing language, QA rules, and alert logic.

The dashboard now includes a weather-context panel backed by
`data/weather-context.json`. The current file is deliberately marked
`unavailable` until reviewed, public-safe weather telemetry exists. Use
`docs/weather-context-contract.md` and `data/weather-context.example.json` as
the target contract for the backbone-generated public export.

## Refresh live snapshot

Run this from PowerShell to update `data/live.json` with current public data:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\refresh-live-data.ps1
```

The refresh script resolves FHABS CSV resource URLs from the CA Open Data `package_show` metadata instead of pinning dated download filenames. It also refuses to stamp a new snapshot if the FHABS resource filename date is older than the configured freshness window.

Optional environment variables:

- `CLEAR_LAKE_FHABS_BLOOM_REPORTS_URL`: override the bloom-report CSV URL if the catalog changes unexpectedly
- `CLEAR_LAKE_FHABS_RESULTS_URL`: override the lab-results CSV URL if the catalog changes unexpectedly
- `CLEAR_LAKE_FHABS_MAX_RESOURCE_AGE_DAYS`: allow an older dated FHABS resource when the public source is intentionally lagged

Run this to refresh the cached OpenStreetMap shoreline geometry:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\refresh-osm-shoreline.ps1
```

Run this to rebuild the site-registry review queue:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-site-review-report.ps1
```

## Validate before publishing

Run this before sharing or deploying the dashboard:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-dashboard.ps1
```

If the local server is not running and you only want file and JSON checks:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-dashboard.ps1 -SkipHttp
```

See `docs/deployment.md` for GitHub Pages and static-hosting notes.

## Local Git discovery

If `git` is unavailable in the shell, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\find-local-git.ps1
```

This project currently treats Git setup as an explicit decision point. The script can locate GitHub Desktop's bundled Git, but `git diff` still requires the folder to be inside a Git repository.

## Local desktop shortcut

Run this to create a pin-friendly Windows shortcut:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\create-windows-shortcut.ps1
```

The script creates:

- `shortcuts\Clear Lake Watch.lnk`
- `Clear Lake Watch.lnk` on the Windows Desktop

The shortcut launches the local dashboard with Windows PowerShell 5.1 and keeps runtime PID/log files under `%LOCALAPPDATA%\ClearLakeWatch\runtime`, outside the static web root.
