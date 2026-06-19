# Stale-Source Rehearsal - 2026-06-19

Status: completed review-only rehearsal, not a publication candidate

This note records the first manual rehearsal of the formal public refresh workflow after the stale-source rehearsal policy layer was merged.

It does not refresh or publish the public mirror. It documents workflow behavior, validator output, and the distinction between resource freshness and observation freshness.

## Runs

Default fail-closed run:

- GitHub Actions run `27802296260`
- Result: failed at `Refresh live public data`

Review-only stale-source rehearsal run:

- GitHub Actions run `27802297609`
- Result: completed successfully and uploaded artifact `formal-public-refresh-review-stale-source-rehearsal`

## What Happened

The default run preserved the publication-safe gate:

- `allow_stale_fhabs_rehearsal=false`
- `CLEAR_LAKE_FHABS_MAX_RESOURCE_AGE_DAYS` was unset
- the workflow failed before downstream validation or artifact upload

The review-only stale-source rehearsal required explicit override:

- `allow_stale_fhabs_rehearsal=true`
- `fhabs_max_resource_age_days=30`
- the artifact included:
  - `review-only stale-source rehearsal enabled`
  - `CLEAR_LAKE_FHABS_MAX_RESOURCE_AGE_DAYS=30`

## Internal Coherence

The review-only artifact showed internally coherent generated timestamps:

- `manifest.json` generated at `2026-06-19T02:49:31Z`
- `live.json` generated at `2026-06-19T02:49:31Z`
- `weather-context.json` generated at `2026-06-19T02:49:32Z`

Both validators passed within the rehearsal lane:

- `scripts/validate-public-mirror.ps1`
- `python scripts/validate-public-mirror.py`

## Preserved Warnings

The rehearsal did not erase the important FHABS age warnings. The validators preserved these warnings:

- `Manifest source fhabs-bloom-reports latest observation is 285 days older than the dashboard snapshot.`
- `Manifest source fhabs-results latest observation is 890 days older than the dashboard snapshot.`

The copied `README.md` in the artifact also continued to state that the live mirror is a static reviewed snapshot generated on May 5, 2026.

## Policy Insight

This rehearsal confirmed two different freshness concepts:

1. FHABS resource file age
   The upstream dated FHABS resource was 17 days old on the run date, which exceeded the default 14-day gate and caused the fail-closed run to stop.

2. FHABS observation age
   Even when the resource file is accepted for review-only rehearsal, the latest Clear Lake FHABS observations remain much older than the dashboard generation time.

That distinction matters. A newer upstream CSV file does not automatically mean newer Clear Lake conditions.

## Decision

Do not open a real snapshot-refresh PR from this rehearsal artifact.

Use this rehearsal only as governance evidence that:

- the default lane fails closed,
- the stale-source override is explicit and logged,
- review-only artifacts can be generated without weakening the publication gate.
