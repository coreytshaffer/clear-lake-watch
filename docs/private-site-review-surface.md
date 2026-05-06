# Private Site-Registry Review Surface

Status: public aggregate implemented; detailed records moved to local SQLite before review

Clear Lake Watch now separates the public site-registry trust cue from the detailed site-review queue.

## Public Surface

The public dashboard should consume:

```text
data/site-review-summary.json
```

This file contains aggregate counts and public boundary notes only. It does not include the detailed review queue, reviewer notes, draft corrections, unpublished decisions, or private observation records.

## Local SQLite Store

The local detailed review store is:

```text
data/private/site-review.local.sqlite
```

This file is ignored by Git. It stores detailed site-review queue records, marker-by-site records, and reusable review decisions for local review before anything enters the public dashboard.

The reusable decision table is named:

```text
review_decisions
```

It is intentionally generic. A decision points to a `subject_type` and `subject_id`, then records `decision_status`, reviewer fields, evidence notes, public notes, and `permission_to_publish`. That shape can later support site-registry QA, field/microscopy records, weather-station QA, or other reviewed-publication gates.

The first site-registry convention is:

```text
subject_type = site-registry-review
subject_id = siteId::landmark
```

Use the local tool to import generated detail records, validate the database, and export the public summary:

```powershell
python .\scripts\site_review_db.py import-json
python .\scripts\site_review_db.py import-decisions --input .\data\site-review-decisions.local.json
python .\scripts\site_review_db.py validate
python .\scripts\site_review_db.py export-summary
```

## Detailed Review Artifacts

The detailed generated review artifacts still exist for local review:

```text
data/site-review.json
docs/site-registry-review.md
docs/site-registry-high-priority.md
```

These files are useful while the project is still static and transparent, but the canonical local detailed store is now SQLite. Treat the JSON and Markdown detail files as generated import/review artifacts, not public dashboard inputs.

Current decision:

Detailed site-review records stay local-only prior to review. They are stored in `data/private/site-review.local.sqlite` and should not be treated as public dashboard inputs. The public-facing artifact is `data/site-review-summary.json`.

## Boundary Rule

Public pages may show:

- registry site counts
- reviewed versus needs-review counts
- high, medium, and low review priority counts
- public caveats that counts do not certify site locations or public-health status

Public pages should not show:

- reviewer identity
- private reviewer notes
- draft corrections
- unpublished site decisions
- private field observations
- sensitive exact coordinates not approved for publication

## Next Decision Point

Before adding a private UI, decide whether the existing JSON-to-SQLite import is enough for the first real review pass. Until then, keep review decisions in ignored JSON, import them into SQLite, and export only the sanitized public summary.
