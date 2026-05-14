# Clear Lake Watch Research Readiness Brief

**Status:** mentor-review draft
**Project stage:** late prototype / early MVP
**Use case:** scholarship, REU, faculty-advisor, and technical mentor conversations
**Last refreshed:** 2026-05-14

## Working Research Identity

Clear Lake Watch is a watershed intelligence dashboard prototype for Clear Lake, California. It explores how public water-quality signals, hydrologic context, GIS data, source-status metadata, and review boundaries can be combined into a cautious public situational-awareness surface.

The project is not an official public-health tool, does not issue advisories, and should not be described as a deployed research-grade monitoring network. Its current research value is as a documented prototype for public environmental data integration, transparent uncertainty, and future field-validation workflows.

## Researchable Question

How can a local-first environmental dashboard help organize public water-quality and hydrologic information for Clear Lake while preserving uncertainty, source provenance, review status, and public-health boundaries?

## Why This Matters

Clear Lake environmental information is distributed across multiple public sources, including lake and tributary monitoring, harmful algal bloom reports, water-quality programs, and institutional research. That fragmentation can make it difficult for students, residents, researchers, and collaborators to tell what is observed, reported, derived, current, provisional, or still awaiting local review.

Clear Lake Watch addresses that problem as a cautious integration layer. It does not replace official monitoring. It makes public source boundaries more visible.

## Current Implemented Evidence

- Static public dashboard deployable through GitHub Pages.
- USGS hydrology context and lake-level display.
- FHABS-derived report context.
- OpenStreetMap shoreline context.
- Reviewed NOAA/National Weather Service public-source weather context marked as contextual and partial.
- Site-registry structure for stable site IDs, lake-arm grouping, and review status.
- Source-status manifest, source-freshness validation, and public data-product inventory.
- Visible signal labels for observed, reported, derived, planning, experimental, and needs-review content.
- Public methodology and disclaimer page.
- Validation script for required files, JSON shape, and public/private guardrails.
- Private-review design for future field and microscopy records, with public-safe placeholder export.
- Reviewer screenshots, demo notes, and a portfolio evidence index for scholarship, internship, mentor, and community review.

## Current Limitations

- Some site-registry assignments still require local review.
- Weather context is a reviewed public-source partial snapshot, not local live telemetry or lake-health interpretation.
- Field and microscopy records are not public submission features.
- Report counts should not be interpreted as bloom severity.
- The dashboard is not official public-health, regulatory, recreation, or emergency guidance.
- No live field-sensor validation is claimed.

## Candidate Research Contributions

| Area | Contribution | Evidence needed next |
| --- | --- | --- |
| Environmental data integration | Combine public lake, hydrologic, bloom-report, and GIS context in one reviewed dashboard surface. | Source audit, validation logs, reproducible refresh notes. |
| Data trust and provenance | Show source freshness, signal type, and review status near the point of interpretation. | User/mentor review of trust labels and methodology language. |
| Site-registry QA | Preserve unresolved or heuristic site assignments instead of hiding uncertainty. | Local review notes, decision log, and documented assignment rules. |
| Local-first monitoring architecture | Separate public-safe dashboard exports from private intake, QA, reviewed public-source context, and future telemetry. | Field/microscopy review cycle, private/public boundary checks, and future calibration plan. |
| Research communication | Translate complex environmental data into cautious public-facing summaries. | Accessibility review and mentor feedback. |

## Mentor Feedback Request

The most useful first review is narrow:

> Are the project’s source boundaries, review labels, and planned validation steps scientifically reasonable for a student-led environmental monitoring prototype, and what should be corrected before field testing or broader public promotion?

## Near-Term Work Plan

1. Keep the dashboard validator passing and preserve stale-source warnings as visible trust cues.
2. Refresh portfolio-facing documents so they match the current public mirror and trust-hardening pass.
3. Review the site-registry location-verification notes and leave unresolved items unresolved unless better evidence exists.
4. Draft a variable register for future field or sensor data, separate from the current public-source dashboard.
5. Ask one environmental science, water-quality, or GIS mentor for feedback on the review labels and validation pathway.

## Claim Boundary

Safe:

> Clear Lake Watch is a late-prototype / early-MVP watershed intelligence dashboard that integrates public environmental data, GIS context, source metadata, and review boundaries for Clear Lake.

Avoid:

> Clear Lake Watch is an official monitoring system, public-health advisory, validated forecast, or deployed sensor network.

## References

California State Water Resources Control Board. (n.d.). *SWAMP: Freshwater cyanoHABs program (blue-green algae)*. https://www.waterboards.ca.gov/water_issues/programs/swamp/freshwater_cyanobacteria.html

County of Lake. (n.d.). *Clear Lake water quality*. https://www.lakecountyca.gov/1504/Clear-Lake-Water-Quality

U.S. Geological Survey. (n.d.). *NWISWeb*. https://www.usgs.gov/data/nwisweb

University of California, Davis, Tahoe Environmental Research Center. (n.d.). *Clear Lake Rehabilitation: About*. https://clearlakerehabilitation.ucdavis.edu/about
