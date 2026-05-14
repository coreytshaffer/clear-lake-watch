# Site Registry Trust Review Pass 001

Status: public-safe review record.

This review pass checks the current FHABS map markers against the starter site registry and records whether any assignment can be promoted from `needs-local-review`.

Decision for this pass: no current FHABS marker is promoted. All current FHABS markers remain `needs-local-review` until local evidence, reviewer signoff, and permission to publish are available.

This is QA for map context only. It is not public-health, recreation, emergency, regulatory, or forecasting guidance.

## Inputs Reviewed

- `data/live.json`: current public dashboard map markers.
- `data/sites.json`: maintained starter site registry.
- `data/sites-normalized.json`: normalized public site-registry export.
- `data/site-review-summary.json`: aggregate public review status.
- Private local decision files: used only as local working context and not published.

## Current Marker Review Summary

| Priority | Marker / landmark | Current registry match | Evidence reviewed | Decision | Public note |
|---|---|---|---|---|---|
| Medium | Clear Lake Keys near Ketch Court | `fhabs-clearlake-keys` | Public FHABS marker, starter registry alias, coordinate distance of about 1.12 km from the maintained registry point. | Keep `needs-local-review`. | Plausible broad Clear Lake Keys match, but not precise enough to promote without local review. |
| Medium | Jago Bay | `fhabs-jago-bay` | Public FHABS marker, starter registry alias, coordinate distance of about 0.70 km from the maintained registry point. | Keep `needs-local-review`. | Plausible Jago Bay match, but the maintained point should not be treated as confirmed without local review. |
| Medium | Soda Bay | `fhabs-soda-bay` | Public FHABS marker, starter registry alias, coordinate distance of about 1.14 km from the maintained registry point. | Keep `needs-local-review`. | Plausible broad Soda Bay match, but not precise enough to promote without local review. |
| Low | Clearlake Oaks west of Blue Heron Ct. | `fhabs-clearlake-oaks` | Public FHABS marker and starter registry alias. | Keep `needs-local-review`. | Alias match remains visible as context only. |
| Low | Riveria Point Launch at Henderson Point in Soda Bay | `fhabs-henderson-point` | Public FHABS marker and starter registry alias. | Keep `needs-local-review`. | Spelling and landmark specificity still need local review before promotion. |
| Low | Konocti Shores | `fhabs-konocti-shores` | Public FHABS marker and starter registry alias. | Keep `needs-local-review`. | Alias match remains visible as context only. |
| Low | Jones bay | `fhabs-jones-bay` | Public FHABS marker, starter registry alias, coordinate distance of about 0.14 km from the maintained registry point. | Keep `needs-local-review`. | Plausible match, but still not promoted without named local review. |
| Low | Wheeler Point, Kelseyville | `fhabs-wheeler-point` | Public FHABS marker and starter registry alias. | Keep `needs-local-review`. | Alias match remains visible as context only. |

## What This Proves

- The current public map has eight FHABS markers matched to starter registry sites.
- None of the current FHABS marker assignments has enough public-safe review evidence to promote from `needs-local-review`.
- Medium-priority checks are driven by broader place names or nonzero distance between the source marker and maintained registry point.
- The public mirror can document map uncertainty without exposing private reviewer notes.

## What This Does Not Prove

- It does not certify site coordinates, lake-arm assignments, shoreline access points, or local place boundaries.
- It does not establish official advisory status or recreation guidance.
- It does not validate bloom severity, toxin risk, or public-health conditions.
- It does not replace local review, source-agency records, or official public advisories.

## Next Review Step

The next useful step is to collect named local review for the three medium-priority items before changing any public assignment status:

- Clear Lake Keys near Ketch Court
- Jago Bay
- Soda Bay

Until that review exists and is approved for publication, the public dashboard should continue to show the current markers as `needs-local-review`.
