# Site Registry Unresolved Decision

Status: active decision

Decision date: 2026-05-07

## Decision

Keep all current FHABS map markers as `needs-local-review` for now.

Do not promote any FHABS marker to `reviewed-local` until a true local review pass provides named reviewer evidence, map/source checks, and permission to publish the reviewed decision.

## Why

The current site-registry trust review found that:

- high-priority current marker checks are empty,
- medium-priority offset checks are plausible but not locally certified,
- low-priority alias/coordinate matches are close but still not locally certified,
- public evidence is useful for triage but not enough to certify local landmark, coordinate, lake-arm, or match-radius assignments.

## Current Public Meaning

The dashboard warning that all current map markers still need local review is accurate and should remain visible.

The map can support source discovery, spatial context, and review planning. It should not be described as locally certified, public-health guidance, regulatory guidance, or a model-training truth set.

## References In This Repo

- `docs/site-registry-trust-review-pass-001.md`
- `docs/site-registry-trust-review-pass-002.md`
- `docs/site-registry-location-verification.md`
- `docs/site-registry-decision-workflow.md`
- `data/site-review-summary.json`
