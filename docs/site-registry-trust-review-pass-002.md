# Site Registry Trust Review Pass 002

Status: public-safe review note

Review date: 2026-05-07

Scope: low-priority current FHABS marker checks from `data/site-review.json`

## Review Boundary

This pass records the conservative outcome for low-priority markers whose aliases and coordinates are close, but whose local landmark and lake-arm assignments have not been certified by a named local reviewer.

No registry coordinates were moved. No FHABS landmark was promoted to `reviewed-local`.

## Inputs Reviewed

- `data/site-review.json`
- `data/site-review-summary.json`
- `data/sites.json`
- `docs/site-registry-trust-review-pass-001.md`
- `data/private/site-review.local.sqlite`

## Summary

| Item | Current site | Priority | Decision | Reason |
| --- | --- | --- | --- | --- |
| Clearlake Oaks west of Blue Heron Ct. | `fhabs-clearlake-oaks` | Low | Keep `needs-local-review` | Alias and coordinates are close, but no local reviewer has certified the landmark, arm assignment, or match radius. |
| Riveria Point Launch at Henderson Point in Soda Bay | `fhabs-henderson-point` | Low | Keep `needs-local-review` | Existing alias coverage includes the likely `Riviera` spelling, but the specific maintained label and arm assignment still need local review. |
| Jones bay | `fhabs-jones-bay` | Low | Keep `needs-local-review` | The prior split from Jago Bay is conservative and useful, but local review is still needed before certification. |
| Konocti Shores | `fhabs-konocti-shores` | Low | Keep `needs-local-review` | Alias and coordinates are close, but no local reviewer has certified the assignment. |
| Wheeler Point, Kelseyville | `fhabs-wheeler-point` | Low | Keep `needs-local-review` | Alias and coordinates are close, but no local reviewer has certified the assignment. |

## Existing Private Decisions

The private SQLite review store already contains `needs-review` decisions for these five low-priority subjects. This pass does not add duplicate decision records.

Decision status checked:

| Subject | SQLite status | Publishable? |
| --- | --- | --- |
| `fhabs-clearlake-oaks::Clearlake Oaks west of Blue Heron Ct.` | `needs-review` | No |
| `fhabs-henderson-point::Riveria Point Launch at Henderson Point in Soda Bay` | `needs-review` | No |
| `fhabs-jones-bay::Jones bay` | `needs-review` | No |
| `fhabs-konocti-shores::Konocti Shores` | `needs-review` | No |
| `fhabs-wheeler-point::Wheeler Point, Kelseyville` | `needs-review` | No |

## Decision Outcome

The appropriate action for all five low-priority items is:

```text
keep-needs-review
```

This means:

- keep the current stable `siteId` values,
- keep `assignmentStatus` as `needs-local-review`,
- keep public map trust cues visible,
- do not treat close alias/coordinate matches as local certification,
- do not use unresolved markers as public-health guidance or model-training labels.

## Next Decision Point

The generated queue has now been reviewed conservatively at high, medium, and low priority:

- high-priority: no current items,
- medium-priority: public-safe keep-needs-review pass recorded,
- low-priority: keep-needs-review pass recorded from existing private decisions.

The next decision is whether to:

1. keep all FHABS markers unresolved for now, or
2. perform a true local review pass with named reviewer evidence, map/source checks, and permission to publish reviewed-local decisions.

Until that decision is made, the dashboard warning that all current map markers still need local review is accurate and should remain visible.
