# Public Mirror File Set - 2026-05-08

Status: recommended file set for clean public mirror candidate branch

Decision: use dashboard plus selected portfolio docs.

This file set is for a clean branch based on `origin/main`. It should not be created by merging `codex/portfolio-safe-release-prep` into `main`, because the review branch and `origin/main` do not share a merge base.

## Include

### Static Site

- `.nojekyll`
- `index.html`
- `project.html`
- `methodology.html`
- `styles.css`
- `app.js`
- `manifest.webmanifest`
- `sw.js`
- `geometry-preview.html`, only if the county/OSM comparison remains clearly labeled as review context

### Assets

- `assets/apple-touch-icon.png`
- `assets/clear-lake-watch-icon-192.png`
- `assets/clear-lake-watch-icon-512.png`
- `assets/clear-lake-watch-preview.png`
- `assets/clear-lake-watch.ico`

### Public Data

- `data/analytics.json`
- `data/forecast-output.example.json`
- `data/lake-shoreline.json`
- `data/live.json`
- `data/manifest.json`
- `data/observations.json`
- `data/reports.json`
- `data/reviewed-field-observations.json`
- `data/site-review-summary.json`
- `data/sites-normalized.json`
- `data/sites.json`
- `data/sources.json`
- `data/weather-context.example.json`
- `data/weather-context.json`

### Public Data With Extra Review

These may be included if their labels remain conservative and source/provenance language is clear:

- `data/lake-shoreline-county-candidate.json`
- `data/lake-shoreline-county-simplified-25ft.json`
- `data/lake-shoreline-county-simplified-50ft.json`
- `data/site-review-decisions.example.json`
- `data/field-microscopy-intake.example.json`

### Public Documentation

- `README.md`, after public-mirror trimming
- `docs/project-brief.md`
- `docs/Clear-Lake-Watch-Project-Brief.pdf`
- `docs/clear_lake_watch_portfolio_case_study.md`
- `docs/deployment.md`
- `docs/field-microscopy-intake-contract.md`
- `docs/flagship-maturity-plan.md`
- `docs/forecast-boundary.md`
- `docs/local-first-operating-model.md`
- `docs/public-mirror-boundary.md`
- `docs/publication-review-checklist.md`
- `docs/published-commentary.md`
- `docs/research-readiness-brief.md`
- `docs/resume-linkedin-snippets.md`
- `docs/source-audit.md`
- `docs/weather-context-contract.md`

### Public Scripts

- `scripts/refresh-live-data.ps1`
- `scripts/refresh-osm-shoreline.ps1`
- `scripts/write-weather-context-unavailable.ps1`
- `scripts/validate-dashboard.ps1`, after public-mirror trimming or replacement with a public-mirror validator

## Exclude

Do not include these in a broad public mirror candidate branch:

- `portfolio-materials.html`
- `docs/backlog.md`
- `docs/career-services-call-notes.md`
- `docs/career-services-day-of-checklist.md`
- `docs/career-services-follow-up-tracker.md`
- `docs/career-services-share-packet.md`
- `docs/conversation-log.md`
- `docs/cross-platform-typography-audit.md`
- `docs/internship-role-fit-map.md`
- `docs/internship-share-brief.md`
- `docs/local-git-scope-review-2026-05-07.md`
- `docs/local-git-workflow.md`
- `docs/portfolio-release-branch-handoff.md`
- `docs/portfolio-safe-release-gate-summary.md`
- `docs/portfolio-safe-release-scope.md`
- `docs/portfolio-safe-release-validation-log.md`
- `docs/public-mirror-review-2026-05-08.md`
- `docs/public-mirror-file-set-2026-05-08.md`
- `docs/publication-push-review-2026-05-07.md`
- `docs/private-site-review-surface.md`
- `docs/private-sqlite-surface.md`
- `docs/private-surface.md`
- `docs/reusable-schema-package.md`
- `docs/review-screenshots/`
- `docs/screenshot-only-portfolio-packet.md`
- `docs/site-registry-decision-workflow.md`
- `docs/site-registry-high-priority.md`
- `docs/site-registry-location-verification.md`
- `docs/site-registry-review.md`
- `docs/site-registry-trust-review-pass-001.md`
- `docs/site-registry-trust-review-pass-002.md`
- `docs/site-registry-unresolved-decision.md`
- `docs/trusted-review-feedback-log.md`
- `docs/trusted-review-request.md`
- `knowledge-base/`
- `shortcuts/`
- `data/site-review.json`
- `data/*.local.json`
- `data/private/`
- `*.local.sqlite`
- `server.pid`
- `server.out.log`
- `server.err.log`

## Required Public-Mirror Edits

Before creating the public mirror candidate branch:

- Trim `README.md` so it links only to files included in this public mirror file set.
- Keep `README.md` language conservative: `late prototype / early MVP`, not official public-health guidance, not a validated forecast, not a deployed sensor network.
- If `scripts/validate-dashboard.ps1` is included, either trim it to the public file set or create a separate public-mirror validator so it does not require private/review-only docs.
- Keep `index.html`, `project.html`, and `methodology.html` links resolvable inside the public mirror branch.
- Remove or avoid links to Draft PR #2, trusted feedback docs, local shortcuts, or private review logs.

## Candidate Branch Rule

Create the public mirror candidate from `origin/main`, then copy only the approved public file set from `codex/portfolio-safe-release-prep`.

Do not retarget Draft PR #2 to `main`.

Do not include ignored local files, shortcut binaries, private SQLite stores, trusted-review logs, or local review packets.

## Decision Point

Next slice: create a clean public mirror candidate branch from `origin/main` and apply this file set with public-mirror README and validator trims.
