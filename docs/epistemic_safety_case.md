# Epistemic Safety Case

## Purpose
Clear Lake Watch is designed as an environmental-data trust pipeline. This prototype explicitly demonstrates **epistemic safety**: when source freshness, provenance, confidence, or publication context is weak, the validator surfaces stale-data warnings and requires manual review before any republish rather than producing a clean-looking but misleading public output. Automated stale-data blocking (a hard publication gate) is a design goal, not yet an implemented control.

## Existing Safety-Relevant Mechanics
This repository natively embeds trust and provenance safeguards throughout its architecture:
*   `scripts/validate-public-mirror.py`: The build verification script ensures that public deployment bounds are strictly enforced.
*   `assert_manifest_freshness`: Ensures that any published data provides the necessary metadata context.
*   `sourceFreshnessMaxAgeDays` & `freshnessLegend`: Establishes the rules for how stale data can be displayed, ensuring users are never misinformed about the data's recency.
*   `docs/publication-review-checklist.md` & `docs/scheduled-public-refresh-design.md`: Document the rigorous publication gates preventing automated overrides of uncertain environmental data.
*   `docs/site-registry-trust-review-pass-001.md`: Tracks the review state of geographical source markers.
*   `needs-local-review`: A status preventing untrusted markers from being promoted to authoritative without explicit evidence.
*   Stale-data handling today: the validator emits warnings when a snapshot or source observation is older than the freshness threshold, and publication remains a manual, reviewed step. (A `-AllowStaleSnapshot`-style override gate is **proposed / not implemented**; no CLI flag currently blocks or force-overrides stale publication.)

## Environmental Data Boundary Conditions & Pipeline Responses

The following table maps critical epistemic failures to their intended safe system behaviors. The status column distinguishes what the validator enforces today from what is a documented design goal:

| Boundary Condition | Intended Safe Behavior | Status Today |
| :--- | :--- | :--- |
| **Stale source** | Preserve stale-source warning | Implemented: validator warns and keeps stale-source language visible |
| **Missing provenance** | Require local review (e.g. `needs-local-review`) | Implemented: markers stay `needs-local-review` |
| **Conflicting advisory metadata** | Fail closed | Proposed / not implemented |
| **Simulated data routed toward public output** | Block public promotion | Partially implemented: reviewed-export field guards + private/local exclusion checks |
| **Publication confidence too weak** | Surface warnings and require manual review before republish | Implemented as a manual review step; automated stale-data blocking (a `-AllowStaleSnapshot`-style gate) is **proposed / not implemented** |

The validator surfaces stale-data warnings and requires manual review before any republish; automated stale-data blocking is not yet implemented.

## Why Sabotage by Omission Matters
In environmental and public-interest systems, overt malicious action is rare. The most significant threat is **sabotage by omission**—failing to expose uncertainty, hiding the true age of data, removing caveats, or promoting unreviewed simulated results to look like field evidence. By embedding freshness validation and review gating directly into the pipeline, this prototype guards against silently deceiving the public. 

## Non-Claims
To remain strictly within its prototype boundaries, this project makes the following explicit non-claims:
*   Clear Lake Watch is **not** official public health guidance.
*   It is **not** regulatory monitoring.
*   It is **not** a replacement for California FHABS, Lake County Water Resources, or other agency advisories.
*   It does **not** claim comprehensive water-quality coverage.
*   It is purely a prototype demonstrating reviewable environmental-data trust boundaries.

## Future Work
Future iterations may explore expanding the `freshnessLegend` to handle varying levels of automated confidence, explicitly testing simulation-bounds for future modeling tasks, and further integrating with the `agent-control-evals` framework to formally score pipeline decisions.
