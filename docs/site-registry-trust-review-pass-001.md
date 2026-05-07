# Site Registry Trust Review Pass 001

Status: public-safe review note

Review date: 2026-05-07

Scope: medium-priority current FHABS marker checks from `data/site-review.json`

## Review Boundary

This pass records conservative trust decisions for the current site-registry review queue. It does not certify FHABS landmark locations, lake-arm assignments, public-health status, or site suitability for model training.

No registry coordinates were moved. No FHABS landmark was promoted to `reviewed-local`.

## Inputs Reviewed

- `data/site-review.json`
- `data/site-review-summary.json`
- `data/sites.json`
- `docs/site-registry-location-verification.md`
- `docs/site-registry-decision-workflow.md`

## Summary

| Item | Current site | Priority | Decision | Reason |
| --- | --- | --- | --- | --- |
| Clear Lake Keys near Ketch Court | `fhabs-clearlake-keys` | Medium | Keep `needs-local-review` | Public evidence suggests the source landmark is plausible and near Ketch Court, but the maintained registry point is broader and should not be moved or promoted without local review. |
| Jago Bay | `fhabs-jago-bay` | Medium | Keep `needs-local-review` | GNIS supports Jago Bay as a real bay, and the FHABS coordinate is plausible, but the maintained coordinate may represent a broader or alternate local reference. |
| Soda Bay | `fhabs-soda-bay` | Medium | Keep `needs-local-review` | Soda Bay can refer to both a bay and a broader populated/place area; the broad match remains plausible but not precise enough for local certification. |

## Decision Outcome

The appropriate action for all three medium-priority items is:

```text
keep-needs-review
```

This means:

- keep current stable `siteId` values,
- keep `assignmentStatus` as `needs-local-review`,
- keep public map trust cues visible,
- avoid coordinate moves until stronger public evidence or local review supports them,
- avoid using these unresolved assignments as public-health guidance or model-training labels.

## Next Review Targets

The next trust-review slice should address the low-priority markers that have close alias/coordinate matches but still lack local certification:

- `fhabs-clearlake-oaks`
- `fhabs-henderson-point`
- `fhabs-jones-bay`
- `fhabs-konocti-shores`
- `fhabs-wheeler-point`

These may be easier to review, but they should still stay `needs-local-review` unless a named reviewer confirms the landmark, coordinates, arm assignment, and match radius.

## Publication Note

This review pass is suitable as public-safe process evidence. It should not be described as official review, agency review, local certification, or public-health guidance.
