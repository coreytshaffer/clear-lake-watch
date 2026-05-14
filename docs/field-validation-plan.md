# Field Validation Plan

**Status:** scientific credibility planning artifact  
**Audience:** faculty mentors, internship reviewers, technical reviewers, and future field collaborators  
**Prepared:** 2026-05-14  

This plan defines what Clear Lake Watch would need before field, microscopy, lab, or sensor measurements could become credible public evidence. It is a planning document, not a deployed field program.

Clear Lake Watch is a late prototype / early MVP. It is not official public-health guidance, an official advisory, recreation guidance, emergency guidance, a validated forecast, a deployed sensor network, or an active public submission system.

## Validation Goals

- Separate public-source context from future field, lab, microscopy, and sensor measurements.
- Define the minimum QA evidence needed before any local observation becomes public.
- Preserve location, custody, calibration, permission, and uncertainty boundaries.
- Create a mentor-reviewable path for future field work without implying current monitoring authority.

## Phase 1: Desk Review Before Field Work

| Task | Output | Boundary |
| --- | --- | --- |
| Select 3-5 priority variables from the variable register. | Short candidate list for mentor review. | Planning only. No measurement claim. |
| Match each variable to a method, unit, and likely instrument or source. | Methods table. | Do not mix field methods with public-source data silently. |
| Identify candidate sites and privacy level. | Site list with review status. | Keep unresolved site-registry assignments unresolved. |
| Draft QA/QC questions for a mentor or lab reviewer. | Question list. | Ask for feedback, not endorsement. |

Recommended first variables:

- water temperature,
- Secchi depth / clarity,
- pH,
- dissolved oxygen,
- visual bloom observation notes.

These are useful starter variables because they can teach method discipline without claiming toxin risk, public safety, or forecast authority.

## Phase 2: Field And Sample Metadata Minimums

Each future field event should record:

- date and time,
- collector and review status in private records,
- public site ID or generalized site label,
- lake arm,
- coordinate precision and coordinate source,
- variable, unit, method, and instrument,
- calibration status when an instrument is used,
- weather or driver context source,
- QA status,
- permission-to-publish decision,
- public summary and limitations.

Private details, exact sensitive coordinates, custody notes, raw photo paths, collector contact details, and reviewer notes must stay out of public exports unless explicitly reviewed and cleared.

## Phase 3: Calibration And QA/QC Questions

| Topic | Minimum question before public use |
| --- | --- |
| Instrument calibration | Was the instrument calibrated before use, after use, or against a known standard? |
| Units and method | Are units, depth, time, and method documented consistently? |
| Site precision | Is the public location precise enough for review but not more precise than permission allows? |
| Replicates | Were repeated measurements or duplicate observations collected when practical? |
| Sample handling | Was holding time, preservation, storage, and chain-of-custody documented when samples were collected? |
| Microscopy confidence | Is taxonomic identification confidence recorded and reviewed? |
| Public wording | Does the public summary avoid public-health, recreation, emergency, regulatory, advisory, and forecast claims? |

## Phase 4: Public Export Gate

A field, lab, microscopy, or sensor record may become public only when:

- QA status is reviewed;
- permission to publish is explicit;
- private fields are removed;
- location precision is reviewed;
- method, units, and date are documented;
- uncertainty and limitations are visible;
- the record is clearly tagged as a separate source family;
- the public mirror validator passes.

For microscopy and field observations, use the existing private-to-public pathway documented in [field-microscopy-review-workflow.md](field-microscopy-review-workflow.md).

For weather or sensor telemetry, use a reviewed public-safe export contract like [weather-context-contract.md](weather-context-contract.md), not raw MQTT, Grafana, InfluxDB, or private gateway data.

## What This Plan Does Not Authorize

- It does not authorize public field submissions.
- It does not claim field validation has occurred.
- It does not create a deployed sensor network.
- It does not validate forecasts.
- It does not create official public-health, recreation, emergency, regulatory, or advisory guidance.
- It does not allow private or unreviewed records into model labels or public forecast inputs.

## Mentor Review Questions

Use these questions before field testing:

1. Are the first variables appropriate for a student-led validation pass?
2. Which method or instrument would be credible enough for each variable?
3. What calibration records would a reviewer expect?
4. Which variables should remain lab-only or official-source-only?
5. What location precision is appropriate for public review?
6. Which wording could accidentally imply public-health or advisory authority?

## Next Decision Point

After mentor or lab-method feedback, choose one bounded pilot protocol. The first pilot should prove method discipline and review boundaries, not public safety, forecasting, or operational monitoring.
