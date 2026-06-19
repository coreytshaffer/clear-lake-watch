# Formal Public Refresh Runbook

Status: manual-only reviewed refresh procedure

Date: 2026-06-18

This runbook defines the formal refresh path for Clear Lake Watch public data snapshots. It is a review-and-validation workflow, not unattended publication, not live monitoring, and not public-health guidance.

## Purpose

Use this runbook when the project is intentionally generating a new reviewed public snapshot for the dashboard.

The goal is to keep refresh work separate from:

- routine README or documentation edits,
- trusted-review-only packets,
- GIS candidate review artifacts,
- experimental field, sensor, or forecast work.

## Formal Refresh Surfaces

- Local Windows review path:
  - `scripts/refresh-live-data.ps1`
  - `scripts/refresh-osm-shoreline.ps1`
  - `scripts/write-weather-context-public-source.ps1`
  - `scripts/write-weather-context-unavailable.ps1`
  - `scripts/validate-public-mirror.ps1`
  - `scripts/validate-public-mirror.py`
- Manual GitHub Actions path:
  - `.github/workflows/formal-public-refresh.yml`

## Decision Rule

Use the formal refresh path only when one of these is true:

- the public snapshot is being intentionally updated,
- the README or release note should stop describing the live mirror as a dated static snapshot,
- reviewer-facing freshness dates need to match newly generated data files,
- a release candidate needs current refresh evidence before merge.

If the goal is only portfolio review of an older snapshot, do not run a formal refresh. Keep the static-snapshot language visible instead.

## Local Review Commands

Run the refresh intentionally and in this order:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\refresh-live-data.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-weather-context-public-source.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-public-mirror.ps1
python .\scripts\validate-public-mirror.py
```

Optional shoreline refresh:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\refresh-osm-shoreline.ps1
```

If public-source weather context cannot be reviewed for the release, write the explicit unavailable placeholder instead:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-weather-context-unavailable.ps1
```

## Manual GitHub Actions Path

Use the `Formal Public Refresh` workflow only by manual dispatch.

Workflow file:

- `.github/workflows/formal-public-refresh.yml`

Inputs:

- `weather_context_mode`
  - `public-source`
  - `unavailable`
- `refresh_shoreline`
  - `true`
  - `false`

What the workflow does:

1. Checks out the repository.
2. Runs the public-data refresh script.
3. Optionally refreshes OSM shoreline geometry.
4. Writes reviewed weather context or the unavailable placeholder.
5. Runs the PowerShell public mirror validator.
6. Runs the Python public mirror validator.
7. Uploads logs and generated public JSON files as a review artifact.

What the workflow does not do:

- push commits,
- open a pull request,
- merge to `main`,
- approve advisory wording,
- bypass stale-source warnings,
- publish private or review-only artifacts.

## Acceptance Criteria

A formal refresh is ready for review only when all of these are true:

- refresh commands complete without source-fetch failures,
- `scripts/validate-public-mirror.ps1` passes,
- `python scripts/validate-public-mirror.py` passes,
- stale-source warnings, if any, are explicitly reviewed rather than ignored,
- generated files appear to come from the same refresh pass,
- public/private boundary files remain excluded,
- reviewer-facing snapshot language is updated if the refresh changes dates materially.

## Failure Modes

Treat these as stop conditions:

- source fetch fails,
- a validator fails,
- generated output dates disagree across files,
- private/local artifacts appear in tracked scope,
- freshness wording is removed or misleading,
- the run would require bundling unrelated reviewer/GIS cleanup work.

If any stop condition occurs, keep the work local or in a scoped candidate branch. Do not publish from the failed run.

## Follow-Up After A Passing Refresh

After a passing formal refresh:

1. Review changed JSON files separately from docs and code.
2. Update snapshot-age language in reviewer-facing docs if the public dates changed.
3. Capture a current screenshot if the refresh is part of a promotion pass.
4. Open a scoped PR for the refresh itself.
5. Keep refresh infrastructure changes separate from data-refresh content changes when practical.
