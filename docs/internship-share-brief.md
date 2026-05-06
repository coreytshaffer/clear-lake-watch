# Clear Lake Watch Internship Share Brief

Status: draft for SNHU career services and internship conversations

Date prepared: 2026-05-06

## Short Description

Clear Lake Watch is a late-prototype / early-MVP watershed intelligence dashboard for Clear Lake, California. It integrates public environmental data, GIS context, site-registry QA, source-status metadata, public methodology guardrails, and local-first monitoring architecture into a static situational-awareness prototype.

It is a portfolio artifact and systems-integration case study, not official public-health guidance or a completed monitoring authority.

## Best Links To Share

- Live dashboard: https://coreytshaffer.github.io/clear-lake-watch/
- Repository: https://github.com/coreytshaffer/clear-lake-watch
- Methodology page: https://coreytshaffer.github.io/clear-lake-watch/methodology.html
- Project page: https://coreytshaffer.github.io/clear-lake-watch/project.html
- Career services packet index: `docs/career-services-share-packet.md`
- Case study draft: `docs/clear_lake_watch_portfolio_case_study.md`
- Publication readiness checklist: `docs/publication-review-checklist.md`
- Internship role fit map: `docs/internship-role-fit-map.md`

## What It Demonstrates

- Environmental data communication for a sensitive water-quality topic
- Public data integration using static JSON exports
- GIS/spatial thinking through shoreline, map markers, lake arms, and site-registry review
- Source transparency through freshness/status metadata
- Conservative public-health wording and methodology guardrails
- Local-first architecture planning for future field, weather, and sensor workflows
- Review discipline: private records, SQLite review stores, and public-safe exports stay separated

## Internship-Relevant Skill Signals

- Environmental science framing: water quality, cyanobacteria, watershed context, and public interpretation
- GIS/data systems: site registry, spatial grouping, map trust cues, source attribution, and review status
- Software workflow: HTML/CSS/JavaScript, Python/PowerShell scripts, JSON data products, SQLite review stores, and validation checks
- Professional judgment: avoids overclaiming, separates prototype work from official guidance, and documents public/private boundaries
- Communication: methodology page, case study, release checklist, and stakeholder-facing project framing

## Safe Talking Points

- "This is my flagship environmental systems portfolio project."
- "It is a late prototype / early MVP, not an official monitoring platform."
- "The strongest part of the project is the trust model: source freshness, signal labels, map review status, and conservative public-health language."
- "The public dashboard is static and reviewed; private field, microscopy, and site-review workflows stay local until they pass review."
- "My next technical priority is trust-hardening through real site review before expanding into live weather telemetry."

## Claims To Avoid

- "This issues advisories."
- "This predicts blooms."
- "This is a complete monitoring platform."
- "This has deployed live sensors."
- "This has official agency, Tribal, or community endorsement."
- "This accepts public field submissions."

## Good Internship Fit

This project is relevant for internships or early-career roles involving:

- water resources
- environmental monitoring
- GIS or spatial analysis
- climate resilience
- watershed planning
- environmental data management
- public-sector or nonprofit environmental communication
- field-data QA/QC and data stewardship

Use `docs/internship-role-fit-map.md` to translate these broad fit areas into role families, evidence points, resume bullet variants, and search keywords.

## Suggested Ask For Career Services

"Can you help me identify internships where a project like Clear Lake Watch would be strong evidence of fit, especially roles involving environmental monitoring, GIS, watershed planning, water quality, climate resilience, or environmental data systems?"

## Current Validation Status

Latest local checks, run May 6, 2026:

- dashboard validation passed with the expected conservative site-review warning
- field/microscopy SQLite validation passed with one private draft record and zero publishable records
- site-review SQLite validation passed with 8 detailed queue records, 8 marker-by-site records, and 8 review decision records

Known boundary:

- Some current map markers still need local review, so public map trust cues remain conservative.
