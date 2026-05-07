# Local Git Scope Review

Status: local staging/publishing scope note

Date: 2026-05-07

This note records the current uncommitted worktree scope before any staging, commit, push, public mirror update, or broad promotion. It does not stage or publish anything.

## Recommended Scope Decision

Keep the current work local for now unless a publication review is explicitly started.

If staging later, split the work into at least three groups:

1. portfolio-safe release docs and screenshot packet,
2. site-registry trust-review docs,
3. separate career-services/commentary/local shortcut artifacts.

Do not stage shortcut binaries or `.docx` drafts automatically.

## Portfolio-Safe Release / Screenshot Packet

These files appear related to the current local portfolio-safe release and screenshot-only packet work:

| File | Status | Suggested handling |
| --- | --- | --- |
| `README.md` | Modified | Review with release docs before staging. |
| `docs/backlog.md` | Modified | Review with release docs before staging. |
| `docs/flagship-maturity-plan.md` | Modified | Review with release docs before staging. |
| `docs/portfolio-safe-release-scope.md` | Modified | Review with release docs before staging. |
| `docs/screenshot-review.md` | Modified | Review with screenshot packet before staging. |
| `docs/portfolio-safe-release-gate-summary.md` | New | Review before staging. |
| `docs/portfolio-safe-release-validation-log.md` | New | Review before staging. |
| `docs/research-readiness-brief.md` | New | Review before staging. |
| `docs/screenshot-only-portfolio-packet.md` | New | Review before staging. |
| `docs/review-screenshots/clear-lake-watch-homepage-current-2026-05-07.png` | New image | Review visually before staging. |
| `docs/review-screenshots/clear-lake-watch-map-trust-2026-05-07.png` | New image | Review visually before staging. |
| `docs/review-screenshots/clear-lake-watch-methodology-boundary-2026-05-07.png` | New image | Review visually before staging. |
| `docs/review-screenshots/clear-lake-watch-project-page-2026-05-07.png` | New image | Review visually before staging. |

## Site-Registry Trust Review

These files document the conservative trust-review decision to keep FHABS markers unresolved:

| File | Status | Suggested handling |
| --- | --- | --- |
| `docs/site-registry-trust-review-pass-001.md` | New | Review before staging. |
| `docs/site-registry-trust-review-pass-002.md` | New | Review before staging. |
| `docs/site-registry-unresolved-decision.md` | New | Review before staging. |

Private/ignored supporting files:

| File | Git status | Reason |
| --- | --- | --- |
| `data/site-review-decisions.medium.local.json` | Ignored | Local review decision file with reviewer/evidence details. |
| `data/private/site-review.local.sqlite` | Ignored | Private SQLite review store. |

## Separate Existing Local Artifacts

The publication-status portfolio docs were reviewed and committed in `c7b73a7 Record published commentary portfolio update`.

These files still require an explicit local/publication decision:

| File | Status | Suggested handling |
| --- | --- | --- |
| `docs/Project_Brief_DRAFT_1.docx` | New binary document | Do not stage automatically; decide whether repo should carry this draft. |
| `shortcuts/Clear Lake Watch.lnk` | Modified binary shortcut | Do not stage automatically. |
| `shortcuts/Clear Lake Watch test.lnk` | New binary shortcut | Do not stage automatically. |

## Current Validation Evidence

Latest local checks passed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-dashboard.ps1 -SkipHttp
python .\scripts\site_review_db.py validate
```

Expected dashboard warning remains:

```text
All current map markers still need local review; public map trust cues should remain conservative.
```

## Next Decision Point

Choose one:

1. Keep all current changes local.
2. Review and stage only portfolio-safe release docs and screenshots.
3. Review and stage site-registry trust-review docs separately.
4. Start a full publication/push review using `docs/publication-review-checklist.md`.
