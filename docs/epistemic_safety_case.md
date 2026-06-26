# Epistemic Safety Case

## Purpose
Clear Lake Watch is designed as an environmental-data trust pipeline. This prototype explicitly demonstrates **epistemic safety**: when source freshness, provenance, confidence, or publication context is weak, the system must preserve warnings, fail closed, or require local review rather than producing a clean-looking but misleading public output.

## Existing Safety-Relevant Mechanics
This repository natively embeds trust and provenance safeguards throughout its architecture:
*   `scripts/validate-public-mirror.py`: The build verification script ensures that public deployment bounds are strictly enforced.
*   `assert_manifest_freshness`: Ensures that any published data provides the necessary metadata context.
*   `sourceFreshnessMaxAgeDays` & `freshnessLegend`: Establishes the rules for how stale data can be displayed, ensuring users are never misinformed about the data's recency.
*   `docs/publication-review-checklist.md` & `docs/scheduled-public-refresh-design.md`: Document the rigorous publication gates preventing automated overrides of uncertain environmental data.
*   `docs/site-registry-trust-review-pass-001.md`: Tracks the review state of geographical source markers.
*   `needs-local-review`: A status preventing untrusted markers from being promoted to authoritative without explicit evidence.
*   `-AllowStaleSnapshot`: A CLI flag used to override freshness limits, but explicitly gated from standard unreviewed public publishing.

## Environmental Data Boundary Conditions & Pipeline Responses

The following table maps critical epistemic failures to their corresponding safe system behaviors:

| Boundary Condition | Safe Behavior |
| :--- | :--- |
| **Stale source** | Preserve stale-source warning |
| **Missing provenance** | Require local review (e.g. `needs-local-review`) |
| **Conflicting advisory metadata** | Fail closed |
| **Simulated data routed toward public output** | Block public promotion |
| **Publication confidence too weak** | Require explicit override (`-AllowStaleSnapshot`) with visible caveat |

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
