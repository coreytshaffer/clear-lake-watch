# Clear Lake Watch Backlog

This backlog is ordered around public trust first, then data quality, then feature growth.

## P0-01 Fix Freshness Semantics And Timestamp Fallback

Priority: P0

Status: Done

Why it matters:

The dashboard must never imply that live data is current when the public snapshot file is missing, invalid, or unavailable. Observation dates and successful refresh dates are trust signals.

Acceptance criteria:

- Header shows `Live snapshot unavailable` when `data/live.json` cannot be loaded.
- Header does not fall back to the current date when live data is missing.
- Live snapshot area shows an unavailable freshness badge when the bundle fails.
- Validation prevents reintroducing a current-date fallback.

## P0-02 Complete Site Registry QA And Arm Assignment Review

Priority: P0

Status: In progress; prioritized review queue implemented

Why it matters:

Arm-level summaries, map grouping, and future ML labels depend on trustworthy site-to-arm assignment.

Acceptance criteria:

- Every high-visibility FHABS landmark has reviewed arm membership or explicit unresolved status.
- `needs-local-review` entries are either resolved or documented with a review reason.
- Registry records preserve stable IDs, aliases, coordinates, arm, assignment status, and match radius.
- Map/list UI clearly surfaces unresolved or heuristic assignments.
- The review queue now includes `reviewPriority`, `reviewReason`, and targeted review actions for current mapped FHABS markers.
- A focused high-priority review packet exists for the first manual review pass.
- A review-before-write decision template exists before any registry mutation workflow is automated.

## P0-03 Add Visible Signal-Type And Confidence Labels

Priority: P0

Status: Done for current UI

Why it matters:

The methodology distinguishes observed, reported, derived, heuristic, and experimental signals. The UI should show that distinction at the point of use.

Acceptance criteria:

- Live cards and map markers show labels such as `Observed`, `Reported`, `Derived`, `Heuristic`, or `Needs review`.
- Derived analytics are visibly labeled as reporting/monitoring patterns.
- Users can tell what is measured versus inferred without opening the methodology page.

## P0-04 Split Public Dashboard From Project Roadmap Content

Priority: P0

Status: Done

Why it matters:

The homepage currently serves both public users and technical reviewers. A public visitor should first see current conditions, map context, recent reports, downloads, and methodology links.

Acceptance criteria:

- Homepage focuses on public situational awareness.
- Source inventory, modules, guardrails, phases, and ML roadmap move to a separate project page.
- The project page is linked from the dashboard and methodology pages.
- Validation checks that project-only roadmap sections stay off the dashboard homepage.

## P1-01 Replace Planning Cards With Stable Feed Values

Priority: P1

Status: Not started

Why it matters:

The dashboard becomes more useful as prominent cards move from roadmap framing to source-backed values.

Acceptance criteria:

- USGS-backed cards remain automated and source-dated.
- New source cards only appear when their data contract is stable.
- Lagged or sparse feeds are explicitly labeled.

## P1-02 Add Snapshot Manifest And Source Status Panel

Priority: P1

Status: Done for current public manifest surface

Why it matters:

A manifest makes refresh health auditable without reading logs.

Acceptance criteria:

- A machine-readable manifest includes dashboard version, last successful refresh, source fetch results, row counts, missing feeds, and validation status.
- A public status panel summarizes manifest health in plain language.
- Validation checks the manifest before publish.
- The dashboard shows source status, generated outputs, and manifest interpretation notes from `data/manifest.json`.

## P1-03 Harden Analytics Against Over-Interpretation

Priority: P1

Status: Done for current UI

Why it matters:

Report counts and advisory distributions can be mistaken for bloom severity unless chart cards carry caveats directly.

Acceptance criteria:

- Rename analytics section to emphasize reporting and monitoring patterns.
- Add inline caveats to annual reports and advisory distribution cards.
- Charts do not visually present report counts as severity estimates.

## P1-04 Improve Map Trust Cues

Priority: P1

Status: Partially done; QA priority counts visible

Why it matters:

The map is persuasive, so it needs visible uncertainty and source context.

Acceptance criteria:

- Marker cards show match method or confidence status.
- Reviewed and heuristic/provisional points are visually distinguishable.
- Users can filter or identify reviewed-only points.
- Official/source links are included where possible.
- The dashboard includes a site-registry QA strip summarizing registry sites, current markers, reviewed markers, and records needing local review.
- The dashboard surfaces high-priority site-registry checks separately from general local-review counts.
- The dashboard includes a map trust filter for all markers, reviewed-only markers, and markers needing local review.

## P2-01 Expand Validation From Structure To Trust Checks

Priority: P2

Status: Partially done; site-review schema checks added

Why it matters:

The validator should catch partial or misleading refresh states before publication.

Acceptance criteria:

- Validation fails on stale snapshot age beyond threshold unless explicitly allowed.
- Validation checks required dates, empty series, unresolved assignment thresholds, and missing base files.
- Validation output is understandable to collaborators.
- Current validation checks required public files, JSON shape, source/output manifest data, OSM attribution, weather-context guardrails, stale FHABS URL pinning, and runtime-file placement.
- Current validation checks that site-review outputs include high-priority review counts and per-marker review reasons.

## P2-02 Quarantine Forecasting Behind Experimental Boundary

Priority: P2

Status: Contracted; no live forecast output

Why it matters:

Forecast outputs must never appear equivalent to observed conditions or official advisories.

Acceptance criteria:

- Forecast roadmap lives on the project page, not in the current-conditions flow.
- Future model outputs include model date, training window, inputs, uncertainty, and public-health disclaimer.
- Forecasts are labeled experimental everywhere they appear.
- `docs/forecast-boundary.md` defines the public placement rule, metadata requirements, exclusions, and disclaimer.
- `data/forecast-output.example.json` provides an example-only forecast export shape.
- Validation checks that forecast output examples remain experimental and disclaimer-protected.

## P2-03 Design Reviewed Field And Microscopy Intake

Priority: P2

Status: Not started

Why it matters:

Community science can strengthen the dashboard only if reviewed records stay distinct from agency/public feeds.

Acceptance criteria:

- Intake schema covers custody, site precision, microscope method, taxonomic confidence, reviewer, and permission-to-publish status.
- Unreviewed submissions are excluded from public summaries and ML training data.
- Field/microscopy records remain a separate source family.

## P2-04 Troubleshoot Local Git Availability

Priority: P2

Status: Partially done; GitHub Desktop bundled Git located, repository decision pending

Why it matters:

Local Git should be available so dashboard changes can be reviewed with `git --no-pager diff`, staged intentionally, committed, and eventually published through a normal branch/PR workflow.

Acceptance criteria:

- `git --version` works from the project PowerShell session.
- `git --no-pager diff` can be run from the project root without access-denied errors.
- The project has a clear recommendation for using system Git, bundled Git, or GitHub Desktop Git without global package installs.
- The README or deployment notes document the chosen local Git path and a fallback review workflow if Git is unavailable.
- `scripts/find-local-git.ps1` can locate GitHub Desktop's bundled Git without changing system `PATH`.
- Remaining decision: initialize this folder as a repo, move it into a cloned repo, or manage it through GitHub Desktop.

## P2-05 Formalize Local-First Architecture And Edge-AI Guardrails

Priority: P2

Status: Documented in README; implementation ongoing

Why it matters:

If resilience, community control, and carbon reduction are real project values, the architecture should make local collection, storage, QA/QC, and dashboard generation the default rather than an afterthought.

Acceptance criteria:

- The README documents a local-first operating model with edge, local hub, and public mirror tiers.
- Experimental LLM or edge-AI use is clearly labeled assistive rather than core infrastructure.
- Core monitoring functions are documented as working without an LLM dependency.
- Compute guidance favors thresholds and lightweight analytics before heavyweight inference.

## P2-06 Define Shared Backbone For Weather And Lake Monitoring

Priority: P2

Status: Documented; implementation ongoing

Why it matters:

Weather is a real driver of lake conditions, but weather sensing and lake-health interpretation should not be collapsed into one ambiguous public product.

Acceptance criteria:

- A shared backbone is defined for device management, messaging, storage, and local APIs.
- Weather and lake modules retain separate schemas, QA rules, public interpretation language, and alert logic.
- Weather context can be shown as driver data without being mistaken for direct lake-health measurement.
- The project documents a phased integration path instead of a premature full merge.

## P2-07 Formalize Private Operations And Public Mirror Posture

Priority: P2

Status: Documented; implementation ongoing

Why it matters:

As more live sensors, reviewed field data, weather context, and experimental AI layers are added, a premature full-public deployment increases the risk of false authority and interpretation drift.

Acceptance criteria:

- Deployment notes distinguish private operational layers from public documentation and demo layers.
- Internal-only artifacts such as raw sensor feeds, unreviewed submissions, and prompt/model logs are excluded from public deployment.
- Conditions for moving from private operation to public beta are documented.
- Public-facing mirrors remain explicit about not being official public-health guidance.

## P2-08 Define Weather Context Export Contract

Priority: P2

Status: Contract, unavailable status export, example, UI, and validation implemented; live export pending

Why it matters:

Clear Lake Watch should consume weather from the shared backbone through a stable, reviewed JSON contract rather than depending directly on MQTT, Grafana, InfluxDB, or private gateway services.

Acceptance criteria:

- `weather-context.json` schema is documented with version, generated time, source status, staleness threshold, stations, summary cards, context windows, and quality notes.
- Weather context is labeled as driver/context data, not a direct lake-health measurement.
- Public fields exclude private telemetry, exact sensitive station details, and unpublished diagnostics.
- The environmental monitoring backbone can generate a sample export that Clear Lake Watch can validate.
- `data/weather-context.json` currently provides a public-safe unavailable status until the weather backbone has live telemetry proof.

## P2-09 Move Detailed QA Review Artifacts Behind Private Portal

Priority: P2

Status: Not started

Why it matters:

The public dashboard should show confidence and transparency without exposing detailed draft review workflows once private observations, reviewer notes, and unpublished QA decisions exist.

Acceptance criteria:

- Public pages show aggregate site-registry confidence and review status.
- Detailed review queues, draft corrections, reviewer notes, and private field observations live behind an authenticated private surface.
- Public exports remove private fields and sensitive location precision.
- `data/site-review.json` is either sanitized for public use or replaced by a private-only review artifact plus a public aggregate summary.

## P2-10 Audit Cross-Platform Typography

Priority: P2

Status: Not started

Why it matters:

The dashboard currently relies on OS fonts that may render differently across Windows, macOS, Linux, and mobile devices.

Acceptance criteria:

- Typography is reviewed on at least one non-Windows rendering path.
- Any web-font addition is lightweight, privacy-conscious, and consistent with the existing Clear Lake visual identity.
- The dashboard remains readable and performant if the preferred font fails to load.
