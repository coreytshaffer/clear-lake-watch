# Variable Register

**Status:** scientific credibility planning artifact  
**Audience:** faculty mentors, internship reviewers, technical reviewers, and future field collaborators  
**Prepared:** 2026-05-14  

This register separates variables that Clear Lake Watch already displays from variables that would require future field, lab, microscopy, sensor, calibration, or QA work before they could support stronger scientific claims.

Clear Lake Watch is a late prototype / early MVP. It is not official public-health guidance, an official advisory, recreation guidance, emergency guidance, a validated forecast, a deployed sensor network, or an active public submission system.

## Variable Readiness Labels

| Label | Meaning | Public use |
| --- | --- | --- |
| `public-source-context` | Already represented through public data or public-safe reviewed context. | May support dashboard context if source freshness and limitations remain visible. |
| `future-field-validation` | Needs direct field measurement or field QA before use as project evidence. | Planning only. Do not present as measured by Clear Lake Watch. |
| `future-lab-or-microscopy` | Needs sample handling, custody, microscopy, lab, or taxonomic review. | Planning only unless exported through the reviewed field/microscopy workflow. |
| `future-sensor-or-backbone` | Needs calibrated local sensor or backbone telemetry proof. | Planning only unless exported through a reviewed public-safe contract. |
| `do-not-use-as-label` | Too sensitive, ambiguous, or authority-dependent for project labeling. | Do not use as a public condition, forecast, or safety label. |

## Current Public-Source And Context Variables

| Variable | Current source family | Current role | Current readiness | Boundary |
| --- | --- | --- | --- | --- |
| Dashboard generation time | Public snapshot manifest | Shows when dashboard files were generated. | `public-source-context` | Not the same as a source observation date. |
| USGS lake level / gage height | USGS hydrology | Hydrologic context and lake-level reference. | `public-source-context` | Not a bloom, toxin, or safety indicator. |
| USGS tributary discharge | USGS hydrology | Watershed-driver context. | `public-source-context` | Context only; not a causal claim. |
| FHABS report date and location text | California FHABS public data | Bloom-report and incident-history context. | `public-source-context` | Report counts are not severity or current risk. |
| FHABS lab-linked sample date | California FHABS public data | Shows age of public lab-linked records. | `public-source-context` | Older records do not indicate current conditions. |
| Site registry arm assignment | Local site registry and map QA | Organizes public source records by reviewed or needs-review site context. | `public-source-context` / `needs-review` | Unresolved assignments must stay visible. |
| Shoreline geometry | OpenStreetMap-derived current layer | Map context for dashboard orientation. | `public-source-context` | Not a water-quality source. |
| Reviewed public-source weather context | NOAA/National Weather Service export | Air, wind, heat, rainfall, and station context. | `public-source-context` | Environmental-driver context only, not lake-health interpretation. |

## Priority Future Validation Variables

| Variable | Why it matters | Likely measurement path | Current readiness | Minimum evidence before public use |
| --- | --- | --- | --- | --- |
| Water temperature | Supports physical lake context and field comparability. | Field meter, calibrated sensor, or reviewed public source. | `future-field-validation` | Calibration notes, site/time metadata, and QA review. |
| Secchi depth / clarity | Simple field indicator for visibility and algal or sediment context. | Field Secchi disk protocol. | `future-field-validation` | Repeatable method, observer notes, and site precision review. |
| Turbidity | Supports clarity and sediment/runoff context. | Calibrated meter or lab result. | `future-field-validation` | Calibration record, units, method, and QA flag. |
| pH | Basic water-chemistry context. | Calibrated field meter or lab result. | `future-field-validation` | Calibration before/after, temperature context, and QA notes. |
| Dissolved oxygen | Supports lake condition context and method credibility. | Calibrated field meter. | `future-field-validation` | Calibration, depth/time/site metadata, and instrument notes. |
| Conductivity | Supports water-chemistry and inflow context. | Calibrated field meter. | `future-field-validation` | Calibration, unit consistency, and QA review. |
| Chlorophyll-a | Algal biomass proxy. | Lab method, fluorometer, or reviewed public dataset. | `future-lab-or-microscopy` | Method, detection limits, QA/QC, and source provenance. |
| Phycocyanin | Cyanobacteria pigment proxy. | Calibrated sensor or lab-supported method. | `future-sensor-or-backbone` | Calibration, interference notes, and comparison data. |
| Microcystin or cyanotoxin result | Public-health-sensitive toxin context. | Official or qualified lab result only. | `do-not-use-as-label` unless official/reviewed | Do not turn into project safety guidance; cite source and limits. |
| Cyanobacteria taxa | Biological composition context. | Light microscopy with reviewed identification. | `future-lab-or-microscopy` | Taxonomic confidence, reviewer, voucher/photo policy, and permission. |
| Visual bloom observation | Field context and review trigger. | Private reviewed field note or public source report. | `future-field-validation` | QA status, location precision review, and public summary. |
| Wind / rainfall event window | Driver context for interpreting source timing. | Reviewed public-source weather or local backbone export. | `public-source-context` / `future-sensor-or-backbone` | Must remain context-only and separated from lake-health claims. |

## Variables Not To Promote As Clear Lake Watch Claims

| Variable or label | Reason |
| --- | --- |
| Safe to swim / unsafe to swim | Official public-health and recreation guidance boundary. |
| Current toxin risk | Requires official or qualified sampling and public-health interpretation. |
| Bloom severity from report counts | FHABS reports are not a direct severity scale. |
| Forecasted advisory status | Forecasting is not live or validated. |
| Site assignment certainty for unresolved markers | Some registry matches still need local review. |
| Field observation approval without QA status | Private or draft observations are not public evidence. |

## Next Use

Use this register with [official-method-source-spine.md](official-method-source-spine.md) to plan a field-validation protocol and to decide which variables are suitable for future student-led measurement, mentor review, or public-source backfill. Do not use this register as proof that any future field measurement has already happened.
