# Portfolio Release Branch Handoff

Status: local branch handoff note

Date prepared: 2026-05-06

Last updated: 2026-05-07

This note summarizes the portfolio-safe release prep branch. It is for review and handoff before any pull request, public mirror update, merge to `main`, or broad promotion.

## Current Branch

Branch:

```text
codex/portfolio-safe-release-prep
```

Latest committed portfolio milestone:

```text
6da57f2 Add validation checks for portfolio review docs
```

The branch is pushed and aligned with `origin/codex/portfolio-safe-release-prep`. It has not been promoted to the public mirror or merged to `main`.

## Local Commit Stack

```text
6da57f2 Add validation checks for portfolio review docs
af284f9 Update publication review handoff state
b7de805 Refresh handoff after publication update
c7b73a7 Record published commentary portfolio update
73cb57b Add community writing to career packet
db903db Add portfolio-safe screenshot review packet
1851540 Refresh branch handoff summary
9ff94e3 Add portfolio release branch handoff
77f7bec Add career services follow-up tracker
d91e22c Add career services day-of checklist
be8a26f Add resume and LinkedIn snippets
7bbd193 Add career services packet index
e2af38f Add internship role fit map
b136fa2 Polish internship share materials
fea08a8 Prepare portfolio-safe release checkpoint
```

## What This Branch Adds

- portfolio-safe release framing
- publication review checklist
- public/private mirror boundary
- local-first operating model
- private SQLite review surfaces for site-review and field/microscopy workflows
- reusable schema package documentation
- weather-context unavailable export contract
- local mobile-width screenshot review
- portfolio case study draft
- internship share brief
- career-services packet index
- day-of checklist
- follow-up tracker
- resume, LinkedIn, Handshake, and email snippets
- internship role fit map
- expanded validation guardrails
- portfolio-safe screenshot packet
- research-readiness brief
- site-registry trust-review notes
- unresolved FHABS marker decision
- local Git scope review for the current uncommitted artifacts
- published commentary tracker for the Lake County News Robin Lane article
- publication-ready resume, LinkedIn, and internship share language
- validation checks for the portfolio review docs, screenshot packet, trust-review decisions, publication/push review, and published-commentary boundary language

## Latest Validation

Latest local checks passed on May 7, 2026 after `6da57f2`:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-dashboard.ps1 -SkipHttp`
- `python .\scripts\field_microscopy_db.py validate`
- `python .\scripts\site_review_db.py validate`

Expected dashboard validation warning:

```text
All current map markers still need local review; public map trust cues should remain conservative.
```

## Local Artifact Status

Current worktree status: clean.

Previous `.docx` and shortcut artifacts have been handled outside the current committed branch state. Do not reintroduce local binary or draft artifacts without a separate scope review.

## Before Pushing Or Publishing

Use `docs/publication-review-checklist.md`.

Minimum next review:

1. Re-run validation.
2. Review `git status --short`.
3. Confirm private local files remain ignored.
4. Decide whether to keep the pushed branch as review-only, open a draft pull request, squash/reorder commits, or use a clean-clone publish path.
5. Do not treat this branch as a public launch without a final publication decision.

## Suggested Next Decision

The reviewed screenshot/trust-review packet and validation-hardening slice are now committed and pushed to the shareable review branch.

Publication/push review started on 2026-05-07. The branch is pushed as a shareable review branch, but not promoted to the public mirror or `main`. See `docs/publication-push-review-2026-05-07.md`.

Next local decision: keep the pushed branch as the review surface, open a draft pull request, start public mirror/main-branch promotion review, or return to implementation work.
