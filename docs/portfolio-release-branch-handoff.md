# Portfolio Release Branch Handoff

Status: local branch handoff note

Date prepared: 2026-05-06

Last updated: 2026-05-07

This note summarizes the local portfolio-safe release prep branch. It is for review and handoff before any push, pull request, public mirror update, or broad promotion.

## Current Branch

Branch:

```text
codex/portfolio-safe-release-prep
```

Latest local commit:

```text
db903db Add portfolio-safe screenshot review packet
```

The branch has not been pushed.

## Local Commit Stack

```text
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

## Latest Validation

Latest local checks passed on May 7, 2026:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-dashboard.ps1 -SkipHttp`
- `python .\scripts\site_review_db.py validate`

Expected dashboard validation warning:

```text
All current map markers still need local review; public map trust cues should remain conservative.
```

## Intentionally Uncommitted

These files remain outside the branch commits:

- `docs/career-services-share-packet.md`
- `docs/clear_lake_watch_portfolio_case_study.md`
- `docs/internship-share-brief.md`
- `docs/resume-linkedin-snippets.md`
- `docs/published-commentary.md`
- `docs/submitted-commentary.md` deletion, replaced by `docs/published-commentary.md`
- `docs/Project_Brief_DRAFT_1.docx`
- `shortcuts/Clear Lake Watch.lnk`
- `shortcuts/Clear Lake Watch test.lnk`

Reason:

- career-services, case-study, resume/LinkedIn, and commentary edits should be reviewed as a separate publication-status slice
- `docs/published-commentary.md` replaces the earlier submitted-commentary tracker after Lake County News publication
- shortcut binaries are local convenience artifacts
- the `.docx` is a separate draft artifact and should be reviewed before deciding whether it belongs in the repo

## Before Pushing Or Publishing

Use `docs/publication-review-checklist.md`.

Minimum next review:

1. Re-run validation.
2. Review `git status --short`.
3. Confirm private local files remain ignored.
4. Decide whether to push this branch as-is, squash/reorder commits, or use a clean-clone publish path.
5. Do not treat this branch as a public launch without a final publication decision.

## Suggested Next Decision

The reviewed screenshot/trust-review packet is now committed locally. Keep the branch local unless there is a clear reason to push it.

If a shareable GitHub branch or pull request becomes useful, push the branch after reviewing the publication checklist and open it as a draft.

Publication/push review started on 2026-05-07 and is not approved for push yet. See `docs/publication-push-review-2026-05-07.md`.

Next local decision: commit the publication-status portfolio docs, leave them local, or use a clean-clone publication path.
