# Clear Lake Watch

[![Status: Late Prototype / Early MVP](https://img.shields.io/badge/status-late%20prototype%20%2F%20early%20MVP-2f6f5f)](https://github.com/coreytshaffer/clear-lake-watch)
[![License: MIT](https://img.shields.io/badge/license-MIT-1f2937)](./LICENSE)
[![Live Dashboard](https://img.shields.io/badge/live%20dashboard-GitHub%20Pages-0b7285)](https://coreytshaffer.github.io/clear-lake-watch/)

Clear Lake Watch is a late-prototype / early-MVP public dashboard for organizing Clear Lake environmental context, source freshness, map review status, and cautious methodology notes.

It is not official public-health guidance, an official advisory, a validated forecast, or a deployed sensor network.

**Live public mirror:** [coreytshaffer.github.io/clear-lake-watch](https://coreytshaffer.github.io/clear-lake-watch/)

Current public status: static reviewed snapshot generated on May 5, 2026. Treat the live mirror as dated portfolio/review evidence, not live lake conditions. See the [public snapshot release note](docs/public-snapshot-release-note-2026-05-13.md).

![Clear Lake Watch dashboard preview](assets/clear-lake-watch-preview.png)

## Trust Model

- Uses public-source data and clearly labeled prototype outputs.
- Public mirror is a reviewed static publication surface, not the operational system of record.
- Private/local records, reviewer notes, raw field records, and trusted-review paths are excluded from the public mirror.
- Dashboard is not official guidance, a health advisory, a validated forecast, or a deployed sensor network.

## Reviewer Start Here

For a 5-minute review:

1. Open the [dashboard](https://coreytshaffer.github.io/clear-lake-watch/).
2. Read the [evidence summary](docs/clear-lake-watch-v0.1-evidence-summary.md).
3. Read [known limitations](#known-limitations).
4. Read [reviewer demo notes](docs/reviewer-demo-notes.md).
5. Review the [public mirror boundary](docs/public-mirror-boundary.md) if evaluating data governance.

## For Internship Reviewers

Open these first:

1. [Live dashboard](https://coreytshaffer.github.io/clear-lake-watch/)
2. [Clear Lake Watch v0.1 evidence summary](docs/clear-lake-watch-v0.1-evidence-summary.md)
3. [Reviewer demo notes](docs/reviewer-demo-notes.md)

For copy-paste outreach language, see [Internship review start here](docs/internship-review-start-here.md).

## What This Public Mirror Shows

- Public environmental data integration across FHABS, USGS, and OpenStreetMap.
- Static dashboard pages that can be served directly from GitHub Pages.
- Source-status metadata and visible uncertainty around generated outputs.
- Site-registry review cues for markers that still need local review.
- Conservative methodology language for a sensitive environmental topic.

## Known Limitations

- This dashboard does not issue public-health, recreation, regulatory, or emergency guidance.
- Some FHABS landmarks still require local review before arm assignments should be treated as authoritative.
- Weather context is a reviewed public-source snapshot and remains separate from lake-health interpretation.
- Field and microscopy workflows are represented as reviewed-public export placeholders, not public submission forms.

## Open First

- [Dashboard](index.html)
- [Project page](project.html)
- [Methodology](methodology.html)
- [Portfolio evidence index](docs/portfolio-evidence-index.md)
- [Internship review start here](docs/internship-review-start-here.md)
- [Clear Lake Watch v0.1 evidence summary](docs/clear-lake-watch-v0.1-evidence-summary.md)
- [Career Services handoff packet](docs/career-services-handoff-packet.md)
- [Project Delivery, EHS, and Environmental Systems Governance](docs/project-delivery-ehs.md)
- [Accessibility review](docs/accessibility-review.md)
- [Mobile reviewer path review](docs/mobile-reviewer-path-review.md)
- [Dashboard anatomy review guide](docs/dashboard-anatomy-review-guide.md)
- [Project brief](docs/project-brief.md)
- [Project brief PDF](docs/Clear-Lake-Watch-Project-Brief.pdf)
- [Portfolio case study](docs/clear_lake_watch_portfolio_case_study.md)
- [Public backlog](docs/public-backlog.md)
- [Public snapshot release note - 2026-05-13](docs/public-snapshot-release-note-2026-05-13.md)
- [Site registry trust review pass 001](docs/site-registry-trust-review-pass-001.md)
- [Reviewer demo notes](docs/reviewer-demo-notes.md)
- [Variable register](docs/variable-register.md)
- [Field validation plan](docs/field-validation-plan.md)
- [Official method source spine](docs/official-method-source-spine.md)
- [Secchi depth / clarity mentor-review protocol](docs/secchi-depth-clarity-mentor-review-protocol.md)
- [Secchi mentor-review handoff](docs/secchi-mentor-review-handoff.md)

## Public Documentation

- [Source audit](docs/source-audit.md)
- [Forecast boundary](docs/forecast-boundary.md)
- [Weather context contract](docs/weather-context-contract.md)
- [Field/microscopy intake contract](docs/field-microscopy-intake-contract.md)
- [Field/microscopy review workflow](docs/field-microscopy-review-workflow.md)
- [Variable register](docs/variable-register.md)
- [Field validation plan](docs/field-validation-plan.md)
- [Official method source spine](docs/official-method-source-spine.md)
- [Secchi depth / clarity mentor-review protocol](docs/secchi-depth-clarity-mentor-review-protocol.md)
- [Secchi mentor-review handoff](docs/secchi-mentor-review-handoff.md)
- [Local-first operating model](docs/local-first-operating-model.md)
- [Public mirror boundary](docs/public-mirror-boundary.md)
- [Publication review checklist](docs/publication-review-checklist.md)
- [Public backlog](docs/public-backlog.md)
- [Public snapshot release note - 2026-05-13](docs/public-snapshot-release-note-2026-05-13.md)
- [Portfolio evidence index](docs/portfolio-evidence-index.md)
- [Internship review start here](docs/internship-review-start-here.md)
- [Clear Lake Watch v0.1 evidence summary](docs/clear-lake-watch-v0.1-evidence-summary.md)
- [Career Services handoff packet](docs/career-services-handoff-packet.md)
- [Project Delivery, EHS, and Environmental Systems Governance](docs/project-delivery-ehs.md)
- [Accessibility review](docs/accessibility-review.md)
- [Mobile reviewer path review](docs/mobile-reviewer-path-review.md)
- [Dashboard anatomy review guide](docs/dashboard-anatomy-review-guide.md)
- [Reviewer demo notes](docs/reviewer-demo-notes.md)
- [Site registry decision workflow](docs/site-registry-decision-workflow.md)
- [Site registry trust review pass 001](docs/site-registry-trust-review-pass-001.md)
- [Source freshness validation](docs/source-freshness-validation.md)
- [Scheduled public refresh design](docs/scheduled-public-refresh-design.md)
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
- `data/weather-context.json`: reviewed public-source weather context, separate from lake-health interpretation
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

For a cross-platform baseline check that is suitable for CI, run:

```bash
python scripts/validate-public-mirror.py
```

The Python validator is intentionally lighter than the PowerShell validator. Use it as a portable floor for required files, JSON parsing, static-snapshot warnings, text guardrails, and public/private boundary checks. Keep the PowerShell validator as the stronger release gate for Windows review passes.

The broader private review packet and trusted-review materials are intentionally not part of this public mirror branch.
