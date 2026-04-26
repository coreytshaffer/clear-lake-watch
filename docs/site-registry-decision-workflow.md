# Site Registry Decision Workflow

This workflow defines how local review decisions should move from investigation into the maintained site registry.

The goal is to preserve a clear review trail before changing `data/sites.json`.

## Inputs

- `data/site-review.json`: generated QA queue for current map markers
- `docs/site-registry-review.md`: full generated review table
- `docs/site-registry-high-priority.md`: focused high-priority review packet
- `data/site-review-decisions.example.json`: example decision file shape
- `data/site-review-decisions.local.json`: suggested ignored working file for private review decisions
- `scripts/new-site-review-decisions.ps1`: starter generator for private review decision files
- `scripts/preview-site-review-decisions.ps1`: dry-run decision checker

## Decision Principle

Review decisions should be recorded before registry edits are made.

That means:

- inspect the high-priority packet
- review the source and registry coordinates
- record the evidence note
- choose a decision action
- only then update `data/sites.json`

Preview proposed decisions before editing registry data:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\preview-site-review-decisions.ps1 -DecisionPath .\data\site-review-decisions.local.json
```

To create a starter private decision file from the current high-priority queue:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\new-site-review-decisions.ps1
```

The generated starter file deliberately keeps each item as `keep-needs-review`. Edit the file only after reviewing the coordinates, landmark evidence, and local arm assignment.

The preview command should validate decision shape, confirm each decision still matches the current review queue, and print the intended action without modifying files.

`data/site-review-decisions.local.json` is ignored by Git so reviewer notes can stay private while the public example schema remains available.

## Allowed Actions

### `keep-needs-review`

Use when the current match is plausible but not locally certified.

Expected result:

- keep the current `siteId`
- keep `assignmentStatus` as `needs-local-review`
- preserve the reason in review notes

### `add-alias`

Use when the landmark clearly refers to an existing maintained site.

Expected result:

- add the landmark to the existing site's `aliases`
- keep `assignmentStatus` as `needs-local-review` unless evidence is strong enough for local certification
- document the evidence note

### `create-site`

Use when the landmark appears to represent a distinct site rather than a generic bay/community label.

Expected result:

- create a new stable `siteId`
- set coordinates from reviewed evidence
- assign the correct lake arm
- set `assignmentStatus` conservatively unless locally certified

### `promote-reviewed-local`

Use only after local review has confirmed the landmark, coordinates, lake arm, and match radius.

Expected result:

- update `assignmentStatus` to `reviewed-local`
- record the evidence source or local-review note
- keep public language conservative

## Required Decision Fields

Each decision should include:

- `decisionId`
- `siteId`
- `landmark`
- `action`
- `proposedAssignmentStatus`
- `reviewer`
- `reviewedAt`
- `evidenceNote`
- `publicNote`
- `permissionToPublish`

## Guardrails

- Do not use unresolved markers as authoritative labels.
- Do not use unresolved markers as model training labels.
- Do not publish private reviewer notes or sensitive field details.
- Do not promote FHABS registry entries to `reviewed-local` without evidence.
- Keep lake-health interpretation separate from site-registry maintenance.

## Current First Review Targets

The previous `Jones bay` proximity issue should now be handled as its own unresolved `fhabs-jones-bay` starter site rather than folded into `fhabs-jago-bay`.

That split is intentionally conservative:

- `fhabs-jones-bay` remains `needs-local-review`
- `fhabs-jago-bay` remains `needs-local-review`
- local review is still required before either site is promoted to `reviewed-local`

After the split is regenerated through the public snapshot pipeline, continue the next manual pass with:

1. `Riveria Point Launch at Henderson Point in Soda Bay`
2. medium-priority offset checks such as `Jago Bay` and `Clear Lake Keys near Ketch Court`
