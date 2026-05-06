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

Status: Broad-place policy selected; medium-priority offset checks remain unresolved and should not be promoted or split without stronger verifiable location evidence

Why it matters:

Arm-level summaries, map grouping, and future ML labels depend on trustworthy site-to-arm assignment.

Acceptance criteria:

- Every high-visibility FHABS landmark has reviewed arm membership or explicit unresolved status.
- `needs-local-review` entries are either resolved or documented with a review reason.
- Distinct public bay names such as `Jones Bay` and `Jago Bay` are not collapsed into one registry site without review evidence.
- Registry records preserve stable IDs, aliases, coordinates, arm, assignment status, and match radius.
- Map/list UI clearly surfaces unresolved or heuristic assignments.
- The review queue now includes `reviewPriority`, `reviewReason`, and targeted review actions for current mapped FHABS markers.
- A focused high-priority review packet exists for the first manual review pass.
- A review-before-write decision template exists before any registry mutation workflow is automated.
- Current generated high-priority packet reports no high-priority current marker checks.
- Policy decision: keep medium-priority offset cases attached to broad place-based registry entries for simplicity and to avoid overclaiming precise location certainty.
- Public verification notes are recorded in `docs/site-registry-location-verification.md`; future coordinate moves, child/starter sites, or `reviewed-local` promotions require stronger verifiable evidence or local review.

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

Status: Done for current prominent dashboard/project summary cards

Why it matters:

The dashboard becomes more useful as prominent cards move from roadmap framing to source-backed values.

Acceptance criteria:

- USGS-backed cards remain automated and source-dated.
- New source cards only appear when their data contract is stable.
- Lagged or sparse feeds are explicitly labeled.
- The project summary no longer presents the aspirational forecast horizon as a prominent status card; it now reports the implemented automated public feed count instead.

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

Status: Done for current UI

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
- Selected marker details include FHABS source-dataset context, a coordinate map link, and the generated site-review queue link, with a note that these links support provenance and do not certify public-health status or local arm assignment.

## P1-05 Formalize Flagship Portfolio Maturity

Priority: P1

Status: At decision point for portfolio-safe release scope; static portfolio maturity plan is drafted, linked, public snapshot was refreshed on 2026-05-05, local mobile-width screenshot review was captured, publication checklist exists, case-study release framing is documented, and internship share materials are drafted

Why it matters:

Clear Lake Watch can be the portfolio front door only if its public language separates implemented proof from future vision. The project should read as a credible systems-integration artifact without implying official monitoring authority, validated forecasting, or complete field deployment.

Acceptance criteria:

- A flagship maturity plan defines current status, safe public claims, avoided claims, and staged maturity checkpoints.
- README links the maturity plan near the project brief so reviewers can understand the portfolio boundary quickly.
- Resume, portfolio, and technical README wording all preserve the late-prototype / early-MVP status.
- The maturity plan names supporting satellite projects without merging their code or claims into Clear Lake Watch.
- Before broad public promotion, the dashboard validator is run without stale-snapshot allowance, or a static-snapshot release note is written, and at least one current screenshot is captured.
- A local first-viewport mobile-width screenshot review is recorded in `docs/screenshot-review.md`.
- `docs/publication-review-checklist.md` defines freshness, private-file, claim-review, site-registry, screenshot, Git scope, and final publish gates.
- `docs/portfolio-safe-release-scope.md` defines the recommended next release fork: portfolio presentation, validation evidence, screenshots, case study polish, and conservative claims before live weather telemetry or public field intake.
- `docs/clear_lake_watch_portfolio_case_study.md` now includes publication-readiness and validation framing.
- `docs/internship-share-brief.md` and `docs/career-services-call-notes.md` provide a shareable internship packet for SNHU career services and similar conversations.
- Current decision point: choose whether to proceed with the portfolio-safe release pass. Do not promote a fresh public screenshot until that pass confirms the full UI and wording.

## P2-01 Expand Validation From Structure To Trust Checks

Priority: P2

Status: Trust checks expanded; stale snapshot validation added and the public snapshot was refreshed on 2026-05-05

Why it matters:

The validator should catch partial or misleading refresh states before publication.

Acceptance criteria:

- Validation fails on stale snapshot age beyond threshold unless explicitly allowed.
- Validation checks required dates, empty series, unresolved assignment thresholds, and missing base files.
- Validation output is understandable to collaborators.
- Current validation checks required public files, JSON shape, source/output manifest data, OSM attribution, weather-context guardrails, stale FHABS URL pinning, and runtime-file placement.
- Current validation checks that site-review outputs include high-priority review counts and per-marker review reasons.
- `scripts/validate-dashboard.ps1` now fails when `data/live.json` is older than `-MaxSnapshotAgeDays` unless `-AllowStaleSnapshot` is passed for intentional archival or portfolio review.
- Current decision: refreshed public snapshot data on 2026-05-05, but keep publication as a separate decision from local refresh.
- Next decision point: before any fresh public publish, run validation without stale-snapshot allowance and capture a current screenshot.

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

Status: SQLite private surface exercised with one representative local draft; local JSON retained as import/export fallback

Why it matters:

Community science can strengthen the dashboard only if reviewed records stay distinct from agency/public feeds.

Acceptance criteria:

- Intake schema covers custody, site precision, microscope method, taxonomic confidence, reviewer, and permission-to-publish status.
- Unreviewed submissions are excluded from public summaries and ML training data.
- Field/microscopy records remain a separate source family.
- `docs/field-microscopy-intake-contract.md` defines the review-first workflow, required private fields, allowed QA statuses, and public export rules.
- `data/field-microscopy-intake.example.json` provides an example private intake shape and remains example-only.
- `docs/private-surface.md` documents the first local private surface and its public export boundary.
- `scripts/new-field-microscopy-intake.ps1` creates an ignored local intake file under `data/private/`.
- `scripts/validate-field-microscopy-intake.ps1` validates required private intake fields and reviewed-public permission rules.
- `scripts/export-reviewed-field-observations.ps1` writes only approved-public, permissioned records to `data/reviewed-field-observations.json`.
- `scripts/check-field-microscopy-review-cycle.ps1` proves a synthetic approved-public record can export without leaking private fields.
- `scripts/field_microscopy_db.py` initializes, imports, validates, smoke-tests, and exports from a local SQLite review store.
- The current ignored local draft intake record has been imported into `data/private/field-microscopy.local.sqlite`.
- The SQLite review store validates one private-only draft record and exports zero public records until approval and permission are present.
- `docs/private-sqlite-surface.md` documents the SQLite-backed private surface.
- `../environmental-monitoring-schemas/src/environmental_monitoring_schemas/field_microscopy.py` contains reusable schema and validation rules for field/microscopy records.
- `docs/reusable-schema-package.md` documents the local package boundary and current public API.
- The sibling `../environmental-monitoring-schemas/` repository has an initial local commit.
- `data/reviewed-field-observations.json` exists as a public-safe placeholder and excludes private fields.
- Current decision: keep the sibling schema repository private for now.
- Current default: keep using the command-line SQLite workflow plus ignored JSON files until editing private review records becomes too cumbersome.
- Next decision point: after one representative consuming project beyond Clear Lake Watch, revisit whether to publish the schema repository.

## P2-04 Troubleshoot Local Git Availability

Priority: P2

Status: Done for local availability; publication staging remains a separate review decision

Why it matters:

Local Git should be available so dashboard changes can be reviewed with `git --no-pager diff`, staged intentionally, committed, and eventually published through a normal branch/PR workflow.

Acceptance criteria:

- `git --version` works from the project PowerShell session.
- `git --no-pager diff` can be run from the project root without access-denied errors.
- The project has a clear recommendation for using system Git, bundled Git, or GitHub Desktop Git without global package installs.
- The README or deployment notes document the chosen local Git path and a fallback review workflow if Git is unavailable.
- `scripts/find-local-git.ps1` can locate GitHub Desktop's bundled Git without changing system `PATH`.
- Current verification: `git version 2.54.0.windows.1` is available from `C:\Program Files\Git\cmd\git.exe`.
- Current verification: `C:/Users/corey/Documents/Codex/Clear-Lake-Watch` is a Git work tree.
- `docs/local-git-workflow.md` now separates local diff/review commands from staging, committing, pushing, or publishing.
- `docs/publication-review-checklist.md` defines the Git scope gate for staging, commit splitting, and clean-clone publication choices.
- Remaining decision: before publication, choose whether to stage the current local work directly, split it into smaller commits, or move through a clean-clone publish path.

## P2-05 Formalize Local-First Architecture And Edge-AI Guardrails

Priority: P2

Status: Operating model documented and validation-guarded; edge/live implementation ongoing

Why it matters:

If resilience, community control, and carbon reduction are real project values, the architecture should make local collection, storage, QA/QC, and dashboard generation the default rather than an afterthought.

Acceptance criteria:

- The README documents a local-first operating model with edge, local hub, and public mirror tiers.
- Experimental LLM or edge-AI use is clearly labeled assistive rather than core infrastructure.
- Core monitoring functions are documented as working without an LLM dependency.
- Compute guidance favors thresholds and lightweight analytics before heavyweight inference.
- `docs/local-first-operating-model.md` documents the path `edge collection -> local processing -> local storage -> reviewed public export -> static public mirror`.
- Current local stores are named as `data/private/site-review.local.sqlite` and `data/private/field-microscopy.local.sqlite`.
- Current public-safe exports are named as `data/site-review-summary.json`, `data/reviewed-field-observations.json`, and `data/weather-context.json`.
- Validation checks that the public dashboard remains separate from MQTT, private SQLite stores, Grafana, InfluxDB, private gateways, and unreviewed local intake files.

## P2-06 Define Shared Backbone For Weather And Lake Monitoring

Priority: P2

Status: Backbone boundaries documented and tied to local-first operating model; live/domain implementation ongoing

Why it matters:

Weather is a real driver of lake conditions, but weather sensing and lake-health interpretation should not be collapsed into one ambiguous public product.

Acceptance criteria:

- A shared backbone is defined for device management, messaging, storage, and local APIs.
- Weather and lake modules retain separate schemas, QA rules, public interpretation language, and alert logic.
- Weather context can be shown as driver data without being mistaken for direct lake-health measurement.
- The project documents a phased integration path instead of a premature full merge.
- `docs/backbone-integration.md` points to `docs/local-first-operating-model.md` for the public/private operating path.
- Lake, weather/soil, field/microscopy, and review-decision modules are documented as separate domains that can share backbone infrastructure without merging public claims.
- Current implementation uses reviewed JSON export boundaries rather than direct live-service connections from the public dashboard.
- Current recommendation: finish the portfolio-safe release pass and real site-registry trust review before expanding into live weather telemetry.

## P2-07 Formalize Private Operations And Public Mirror Posture

Priority: P2

Status: Public/private file boundary documented; validation guardrails added

Why it matters:

As more live sensors, reviewed field data, weather context, and experimental AI layers are added, a premature full-public deployment increases the risk of false authority and interpretation drift.

Acceptance criteria:

- Deployment notes distinguish private operational layers from public documentation and demo layers.
- Internal-only artifacts such as raw sensor feeds, unreviewed submissions, and prompt/model logs are excluded from public deployment.
- Conditions for moving from private operation to public beta are documented.
- Public-facing mirrors remain explicit about not being official public-health guidance.
- `docs/public-mirror-boundary.md` documents which local files can enter the static public mirror.
- `.gitignore` excludes private local JSON and local SQLite stores.
- Validation checks that public app code does not fetch private local paths or local decision files.

## P2-08 Define Weather Context Export Contract

Priority: P2

Status: Contract, reproducible unavailable status export, example, UI, and validation implemented; live export pending

Why it matters:

Clear Lake Watch should consume weather from the shared backbone through a stable, reviewed JSON contract rather than depending directly on MQTT, Grafana, InfluxDB, or private gateway services.

Acceptance criteria:

- `weather-context.json` schema is documented with version, generated time, source status, staleness threshold, stations, summary cards, context windows, and quality notes.
- Weather context is labeled as driver/context data, not a direct lake-health measurement.
- Public fields exclude private telemetry, exact sensitive station details, and unpublished diagnostics.
- The environmental monitoring backbone can generate a sample export that Clear Lake Watch can validate.
- `data/weather-context.json` currently provides a public-safe unavailable status until the weather backbone has live telemetry proof.
- `scripts/write-weather-context-unavailable.ps1` regenerates the public-safe unavailable placeholder without implying live telemetry.
- Next decision point: connect a reviewed public-safe backbone export only after weather telemetry has a validated source, station privacy review, and quality notes.

## P2-09 Move Detailed QA Review Artifacts Behind Private Portal

Priority: P2

Status: Public aggregate summary implemented; detailed records moved to local SQLite prior to review

Why it matters:

The public dashboard should show confidence and transparency without exposing detailed draft review workflows once private observations, reviewer notes, and unpublished QA decisions exist.

Acceptance criteria:

- Public pages show aggregate site-registry confidence and review status.
- Detailed review queues, draft corrections, reviewer notes, and private field observations live behind an authenticated private surface.
- Public exports remove private fields and sensitive location precision.
- `data/site-review.json` is either sanitized for public use or replaced by a private-only review artifact plus a public aggregate summary.
- `data/site-review-summary.json` now provides the public aggregate site-registry review surface.
- The public dashboard now consumes `data/site-review-summary.json` instead of the detailed `data/site-review.json` queue.
- `scripts/site_review_db.py` imports detailed site-review records into `data/private/site-review.local.sqlite`, validates local records, and exports the public aggregate summary.
- `data/private/site-review.local.sqlite` now includes a reusable `review_decisions` table for subject-based review decisions across future QA workflows.
- Existing site-review decision JSON can now be imported into SQLite with `scripts/site_review_db.py import-decisions`.
- A generated local decision file was imported into SQLite for the first JSON-to-SQLite review pass.
- `docs/private-site-review-surface.md` documents the public/private boundary for site-registry QA artifacts.
- Current decision: detailed site-review records stay local-only prior to review.
- Current first step uses an ignored SQLite database under `data/private/` plus sanitized public exports; this does not yet provide authentication or multi-user access control.
- Current smoke check verifies the field/microscopy exporter excludes private fields from a synthetic approved-public record.
- Current SQLite tool imports shared schema rules from sibling repository `../environmental-monitoring-schemas/` instead of owning a separate copy.
- The sibling schema repository is committed locally but not published.
- Current decision: the sibling schema repository should remain private until there is a second consuming project or a clear publication reason.
- Next decision point: continue with JSON-to-SQLite for the next real review pass unless editing the private JSON becomes too cumbersome.

## P2-10 Audit Cross-Platform Typography

Priority: P2

Status: Static CSS audit complete; local mobile-width screenshot review complete; non-Windows/device screenshot review pending

Why it matters:

The dashboard currently relies on OS fonts that may render differently across Windows, macOS, Linux, and mobile devices.

Acceptance criteria:

- Typography is reviewed on at least one non-Windows rendering path.
- Any web-font addition is lightweight, privacy-conscious, and consistent with the existing Clear Lake visual identity.
- The dashboard remains readable and performant if the preferred font fails to load.
- `docs/cross-platform-typography-audit.md` records the current no-web-font strategy, font fallback risks, and remaining screenshot checks.
- `styles.css` uses explicit Windows, Apple, common local, and generic fallback fonts.
- Explicit `letter-spacing` values are normalized to `0` for more predictable fallback rendering.
- `docs/screenshot-review.md` records a 486 x 719 px local in-app browser screenshot review with no immediate first-viewport wrapping issue found.
- Current decision: do not add web fonts unless screenshot review shows a real readability or identity problem.
