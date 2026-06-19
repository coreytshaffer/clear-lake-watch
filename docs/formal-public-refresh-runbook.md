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

Latest rehearsal evidence:

- `docs/refresh-rehearsals/2026-06-19-stale-source-rehearsal.md`

Inputs:

- `weather_context_mode`
  - `public-source`
  - `unavailable`
- `refresh_shoreline`
  - `true`
  - `false`
- `allow_stale_fhabs_rehearsal`
  - `true`
  - `false`
- `fhabs_max_resource_age_days`
  - default `14`
  - used only when stale-source rehearsal is deliberately enabled

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

## Stale-Source Rehearsal Mode

The default formal refresh remains publication-safe and fail-closed. If FHABS resources are older than the allowed threshold, the run should stop.

Use stale-source rehearsal only when all of these are true:

- the run is manual,
- the goal is to inspect generated outputs,
- the artifact is not being treated as a publication candidate,
- the logs clearly record that older FHABS resources were deliberately allowed.

Workflow inputs for this mode:

- `allow_stale_fhabs_rehearsal: true`
- `fhabs_max_resource_age_days: <explicit value>`

When this mode is enabled:

- the workflow sets `CLEAR_LAKE_FHABS_MAX_RESOURCE_AGE_DAYS`,
- the logs state that stale FHABS rehearsal was deliberately enabled,
- the uploaded artifact name becomes `formal-public-refresh-review-stale-source-rehearsal`.

This artifact is review-only. It is not a publication candidate and must not be used as evidence that the public mirror is fresh enough to publish.

## Acceptance Criteria

A formal refresh is ready for review only when all of these are true:

- refresh commands complete without source-fetch failures,
- `scripts/validate-public-mirror.ps1` passes,
- `python scripts/validate-public-mirror.py` passes,
- stale-source warnings, if any, are explicitly reviewed rather than ignored,
- generated files appear to come from the same refresh pass,
- public/private boundary files remain excluded,
- reviewer-facing snapshot language is updated if the refresh changes dates materially.

For stale-source rehearsal, the acceptance bar is narrower:

- the run completes,
- the logs explicitly show that stale FHABS was deliberately allowed,
- the artifact is clearly review-only,
- no one treats the artifact as publishable output.

## Failure Modes

Treat these as stop conditions:

- source fetch fails,
- a validator fails,
- generated output dates disagree across files,
- private/local artifacts appear in tracked scope,
- freshness wording is removed or misleading,
- the run would require bundling unrelated reviewer/GIS cleanup work.

If any stop condition occurs, keep the work local or in a scoped candidate branch. Do not publish from the failed run.

If stale-source rehearsal succeeds, do not publish from that run either. Use it only to inspect outputs, identify downstream issues, and decide whether a fresh reviewed snapshot is even possible.

## Follow-Up After A Passing Refresh

After a passing formal refresh:

1. Review changed JSON files separately from docs and code.
2. Update snapshot-age language in reviewer-facing docs if the public dates changed.
3. Capture a current screenshot if the refresh is part of a promotion pass.
4. Open a scoped PR for the refresh itself.
5. Keep refresh infrastructure changes separate from data-refresh content changes when practical.
