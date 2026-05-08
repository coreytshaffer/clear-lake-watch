# Portfolio-Safe Release Validation Log

Status: local validation evidence for portfolio-safe release review

Local machine date recorded during this pass: 2026-05-06

This file records validation evidence for presenting Clear Lake Watch as a portfolio artifact. It does not authorize a public push, public mirror update, or broad promotion by itself.

## Latest Validation Pass

Commands run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-dashboard.ps1 -SkipHttp
python .\scripts\field_microscopy_db.py validate
python .\scripts\site_review_db.py validate
```

Results:

| Check | Result | Notes |
| --- | --- | --- |
| Dashboard validation | Passed | Expected warning: all current map markers still need local review. |
| Field/microscopy SQLite validation | Passed | 1 private record checked; 0 publishable records. |
| Site-review SQLite validation | Passed | Latest run 2; 8 detailed queue records; 8 marker-by-site records; 11 review decision records after the medium-priority trust-review import. |

## Validation-Hardening Pass

Validation hardening continued on 2026-05-07.

Artifact:

- `scripts/validate-dashboard.ps1`

Commit:

```text
6da57f2 Add validation checks for portfolio review docs
```

Result: the dashboard validator now checks that the portfolio-safe screenshot packet, site-registry trust-review notes, unresolved-marker decision, publication/push review, research-readiness brief, and published-commentary boundary language remain present and conservative.

## Site-Registry Trust Review Pass

Trust review started on 2026-05-07.

Artifacts:

- `docs/site-registry-trust-review-pass-001.md`
- `data/site-review-decisions.medium.local.json` local ignored decision file
- `data/private/site-review.local.sqlite` private SQLite review store

Commands run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\preview-site-review-decisions.ps1 -DecisionPath .\data\site-review-decisions.medium.local.json
python .\scripts\site_review_db.py import-decisions --input .\data\site-review-decisions.medium.local.json
python .\scripts\site_review_db.py validate
```

Results:

| Item | Decision | SQLite status |
| --- | --- | --- |
| Clear Lake Keys near Ketch Court | Keep `needs-local-review` | `needs-review`; not publishable |
| Jago Bay | Keep `needs-local-review` | `needs-review`; not publishable |
| Soda Bay | Keep `needs-local-review` | `needs-review`; not publishable |

No registry coordinates were moved and no FHABS site was promoted to `reviewed-local`.

## Low-Priority Trust Review Pass

Trust review continued on 2026-05-07.

Artifact:

- `docs/site-registry-trust-review-pass-002.md`

The low-priority pass reviewed the five remaining current FHABS marker checks:

- `fhabs-clearlake-oaks`
- `fhabs-henderson-point`
- `fhabs-jones-bay`
- `fhabs-konocti-shores`
- `fhabs-wheeler-point`

Result: all five remain `needs-local-review`. Existing private SQLite decisions already recorded them as `needs-review` and not publishable, so no duplicate decision records were added.

Decision recorded: keep all current FHABS markers unresolved for now. See `docs/site-registry-unresolved-decision.md`.

## Interpretation

The project currently passes local validation for a portfolio-safe review pass. The remaining public-trust warning is intentional and should stay visible: current map markers still require local review, so the dashboard should not promote those assignments as locally certified.

## Publication Boundary

Before any public push or broad promotion:

- review `docs/publication-review-checklist.md`,
- confirm private files remain ignored,
- decide whether to push the current branch, split commits, or use a clean-clone publish path,
- capture or confirm a current screenshot if using the project for broad portfolio promotion,
- keep the project framed as a late prototype / early MVP, not an official public-health or monitoring authority.
