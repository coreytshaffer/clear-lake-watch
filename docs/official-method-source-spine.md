# Official Method Source Spine

**Status:** scientific credibility planning artifact  
**Audience:** faculty mentors, internship reviewers, technical reviewers, and future field collaborators  
**Prepared:** 2026-05-17  

This source spine defines the official and semi-official literature that future Clear Lake Watch field, lab, microscopy, and sensor protocols should draw from before any student-led measurement is treated as public evidence.

Clear Lake Watch remains a late prototype / early MVP. It is not official public-health guidance, an official advisory, recreation guidance, emergency guidance, a validated forecast, a deployed sensor network, or an active public submission system.

## Source Hierarchy

Use this order when drafting future protocols:

1. **Lake County Clear Lake QAPP and CLAMP materials** for local monitoring context, analytes, site structure, QA/QC expectations, data-use boundaries, and chain-of-custody concepts.
2. **EPA quality assurance guidance** for QAPP structure, data quality objectives, project organization, documentation, calibration, data review, validation, and corrective action.
3. **EPA lake and volunteer monitoring methods** for field methods such as Secchi depth, water temperature, dissolved oxygen, pH, turbidity, chlorophyll-a, sample handling, and field forms.
4. **California Water Boards / CEDEN / SWAMP documentation** when the goal is compatibility with California water-quality data systems or official assessment context.
5. **Instrument manufacturer manuals and mentor/lab instructions** only after the official method family has been identified.

If two sources conflict, future protocols should preserve the conflict as a mentor-review question rather than silently choosing the easier method.

## Core Anchors

| Anchor | Use in Clear Lake Watch | Boundary |
| --- | --- | --- |
| Lake County Water Resources, *Quality Assurance Project Plan for Clear Lake Limnological Ambient Monitoring Program* | Local Clear Lake QA/QC model: program organization, objectives, analytes, site locations, collection containers, holding times, quality objectives, chain of custody, training, safety, and reporting. | This is a County QAPP, not automatic approval for Clear Lake Watch field work. |
| Lake County Clear Lake Water Quality / CLAMP page | Local program context for monthly physical, chemical, and biological water-quality data from the three Clear Lake arms and public data access through CEDEN. | Public-source context only unless data are formally ingested, documented, and validated. |
| EPA, *Volunteer Monitor's Guide to Quality Assurance Project Plans* | Student/volunteer QAPP structure: project organization, problem definition, task description, data quality objectives, sample handling, analytical methods, QC checks, calibration, data management, validation, and reporting. | Planning guidance; not a field method by itself. |
| EPA, *Quality Assurance Project Plan Guidance* | Current EPA QA framing for environmental information operations and QAPP specifications. | Use for structure and QA expectations, not as a shortcut around local review. |
| EPA, *Volunteer Lake Monitoring: A Methods Manual* | Lake-monitoring method context for volunteer programs, including conditions such as Secchi transparency, chlorophyll-a, and dissolved oxygen. | Older but directly lake-focused; confirm against current mentor/lab expectations before field use. |
| EPA, *Field Operations Manual for Lakes* | Lake-specific field operations reference for temperature, dissolved oxygen, Secchi transparency, water sample collection, chlorophyll-a, field checklists, and data forms. | Federal assessment/manual context, not a local authorization. |
| EPA, *Field Measurement of Dissolved Oxygen* | Current technical procedure for dissolved oxygen field measurement considerations. | Procedure scope must be checked before adapting it to student field work. |
| EPA, *Volunteer Estuary Monitoring: A Methods Manual* | Secondary cross-check for QA planning, field practices, data management, pH, temperature, turbidity, dissolved oxygen, and sample handling concepts. | Estuary-specific; use only for general method structure when lake-specific sources are not enough. |

## Variable-To-Source Map

| Future variable | Primary source family | Protocol implication |
| --- | --- | --- |
| Water temperature | Lake County QAPP/CLAMP, EPA lake field operations, EPA volunteer methods | Record instrument, depth, time, site, calibration/status check, and weather/driver context. |
| Secchi depth / clarity | EPA lake field operations, EPA volunteer lake monitoring, Lake County QAPP/CLAMP context | Use a repeatable Secchi method, site metadata, observer notes, cloud/glare/wind conditions, and public-location precision review. |
| pH | Lake County QAPP/CLAMP, EPA volunteer methods, EPA QAPP guidance | Require meter/probe method, calibration buffers, calibration timing, temperature context, units/status, and QA review. |
| Dissolved oxygen | EPA field measurement procedure, EPA lake field operations, Lake County QAPP/CLAMP | Require instrument method, calibration or verification, depth/time metadata, temperature context, and instrument notes. |
| Conductivity | Lake County QAPP/CLAMP, EPA/USGS-style field measurement practice, instrument manual | Require unit consistency, calibration standard, temperature compensation notes, and QA status. |
| Turbidity | Lake County QAPP/CLAMP, EPA volunteer methods, lab or instrument method | Require instrument/lab method, units, calibration/standard, holding-time considerations if sampled, and QA flag. |
| Chlorophyll-a | Lake County QAPP/CLAMP, EPA lake field operations, lab method | Treat as lab/sampling work, not a casual field reading; document containers, preservation, holding time, lab method, detection/reporting limits, and chain of custody. |
| Cyanotoxin or microcystin result | Official/lab source only | Do not turn into Clear Lake Watch safety labels; cite official source, lab status, date, limits, and public-health boundary. |
| Visual bloom observation | EPA volunteer methods, field/microscopy review workflow, mentor guidance | Keep as reviewed field context only; record photo/observation status privately and publish only a sanitized summary after review. |
| Microscopy / taxa | Mentor/lab method, microscopy workflow, future taxonomic review source | Requires taxonomic confidence, reviewer, voucher/photo policy, custody, and permission-to-publish decision. |

## Minimum Protocol Requirements

Every future written protocol should include:

- official source anchors and version/date checked;
- purpose and decision boundary;
- variable, unit, method, and instrument or lab pathway;
- site selection and public/private location precision;
- safety and permission notes;
- calibration or verification steps;
- sample container, preservation, and holding time when applicable;
- field metadata and chain-of-custody expectations;
- QA/QC checks, including blanks, duplicates, standards, or review checks where relevant;
- data review, validation, and rejection rules;
- public export gate and wording limits;
- mentor/lab review questions.

## Protocol Readiness Labels

Use these labels before writing or publishing future protocols:

| Label | Meaning |
| --- | --- |
| `source-spined` | Official source anchors have been identified, but no local protocol has been drafted. |
| `draft-protocol` | A student-facing protocol exists, but it has not been reviewed by a mentor, lab, or qualified technical reviewer. |
| `mentor-review-needed` | The protocol is ready for feedback but must not be treated as approved. |
| `reviewed-for-pilot` | A mentor or qualified reviewer has reviewed the protocol for a bounded pilot. |
| `public-export-ready` | A reviewed pilot record has passed QA, privacy, permission, and public wording gates. |

## First Protocol Candidate

The best first official-source protocol candidate is **Secchi depth / clarity** because it is low-cost, lake-relevant, and method-discipline focused. It can teach site metadata, repeatability, observation conditions, and public wording limits without implying toxin risk, recreation safety, or forecast authority.

The current draft is [secchi-depth-clarity-mentor-review-protocol.md](secchi-depth-clarity-mentor-review-protocol.md). Its readiness label is `mentor-review-needed`, so it should be treated as a review packet rather than an approved field protocol.

Current decision:

- keep the Secchi protocol mentor-review-only for now;
- do not advance it to a private pilot field note until mentor feedback is available;
- do not treat it as a public-export candidate.

## References

County of Lake Water Resources Department. (2022). *Quality assurance project plan for Clear Lake Limnological Ambient Monitoring Program*. https://www.lakecountyca.gov/DocumentCenter/View/4184/Quality-Assurance-Project-Plan-for-Clear-Lake-Limnological-Monitoring-Plan-PDF

Lake County, California. (n.d.). *Clear Lake water quality*. https://www.lakecountyca.gov/1504/Clear-Lake-Water-Quality

U.S. Environmental Protection Agency. (1991). *Volunteer lake monitoring: A methods manual* (EPA 440/4-91-002). https://www.epa.gov/sites/default/files/2015-06/documents/lakevolman.pdf

U.S. Environmental Protection Agency. (1997). *Environmental Monitoring and Assessment Program surface waters: Field operations manual for lakes*. https://archive.epa.gov/emap/archive-emap/web/html/97fopsman.html

U.S. Environmental Protection Agency. (2025). *Quality assurance project plan guidance*. https://www.epa.gov/quality/quality-assurance-project-plan-qapp-guidance

U.S. Environmental Protection Agency. (2025). *Field measurement of dissolved oxygen* (LSASDPROC-106-R6). https://www.epa.gov/quality/field-measurement-dissolved-oxygen

U.S. Environmental Protection Agency. (2025). *Volunteer estuary monitoring: A methods manual*. https://www.epa.gov/nep/volunteer-estuary-monitoring-methods-manual

U.S. Environmental Protection Agency. (1996). *The volunteer monitor's guide to quality assurance project plans*. https://www.epa.gov/quality/volunteer-monitors-guide-quality-assurance-project-plans

## Next Decision Point

Use the **Secchi depth / clarity mentor-review protocol** as a feedback packet for a mentor, faculty reviewer, or qualified technical reviewer. The next decision should come after review comments are received, not from project momentum alone.
