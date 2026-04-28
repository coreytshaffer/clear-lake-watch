# Clear Lake Watch

**Project brief**  
Corey Shaffer  
April 2026

## Summary

Clear Lake Watch is a public-facing environmental dashboard prototype for Clear Lake, California. It brings together lake level, tributary discharge, cyanobacterial bloom reports, shoreline context, and source-status metadata into a single reviewed publication surface.

The project is designed as a lake-focused public mirror on top of a broader local-first environmental monitoring backbone. Public-facing outputs stay static, transparent, and publication-safe, while private intake, QA, field observations, and future weather or soil telemetry remain behind explicit review boundaries.

## Problem

Important Clear Lake environmental data is spread across multiple public sources, each with different formats, cadences, and limitations. That fragmentation makes it harder for residents, researchers, and community partners to quickly understand what is being observed, what is being reported, and what still needs review.

Clear Lake Watch addresses that problem by combining:

- USGS lake-level and streamflow drivers
- California FHABS bloom reports and results
- OpenStreetMap shoreline geometry
- site-registry review status and source-freshness cues

## Current MVP

The current late-prototype / early-MVP dashboard includes:

- Lakeport lake level displayed in both feet Rumsey and approximate feet above sea level
- Cole Creek discharge as a hydrologic driver
- recent FHABS-derived bloom report context
- a shoreline map with registry-backed markers
- visible trust cues for reviewed versus needs-review site assignments
- source freshness and unavailable-state handling
- a public methodology page and interpretation disclaimers

Live public mirror:  
[https://coreytshaffer.github.io/clear-lake-watch/](https://coreytshaffer.github.io/clear-lake-watch/)

Repository:  
[https://github.com/coreytshaffer/clear-lake-watch](https://github.com/coreytshaffer/clear-lake-watch)

## Why this approach

This project intentionally uses a no-build, local-first architecture:

**edge collection -> local processing -> local storage -> optional public mirror**

That design supports resilience, lower operational complexity, and clearer publication boundaries. It also makes the public dashboard easier to validate, mirror, and share without exposing internal QA workflows or unpublished data.

## Current boundaries

Clear Lake Watch is for situational awareness, source discovery, and research planning. It is **not** official public-health guidance, does **not** issue advisories, and should **not** be used as an authoritative source for health or recreation decisions.

Current limitations include:

- some FHABS landmark assignments still require local review
- weather context is intentionally not live yet
- field and microscopy workflows are still planned as reviewed private intake
- report counts should not be interpreted as bloom severity

## Collaboration sought

I am interested in collaboration with:

- Clear Lake and watershed monitoring partners
- Tribal and community environmental programs
- resilience and public-interest technology collaborators
- environmental data, GIS, and civic dashboard mentors

The immediate goal is to strengthen reviewed public situational awareness around Clear Lake while building a modular backbone for future weather, field, and environmental intelligence workflows.
