# Source Freshness Validation

Status: public-safe validation note for the Clear Lake Watch public mirror.

Clear Lake Watch publishes a static public-data snapshot. The validation layer checks whether the snapshot files, source-status manifest, source observation dates, and output record counts still agree before publication.

This is not live monitoring, operational alerting, public-health guidance, recreation guidance, or emergency guidance.

## Shared Evaluator

Both public-mirror commands take snapshot age, source observation age, and manifest integrity from one offline evaluator, `scripts/public_mirror_common.py`:

- `python scripts/validate-public-mirror.py` imports it directly.
- `scripts/validate-public-mirror.ps1` runs it with the `python` on `PATH` and imports the JSON report it prints. If the evaluator cannot start, prints an invalid report, or reports a missing dependency, the PowerShell gate fails.

Each command prints shared findings as `[code] subject: message` in its existing warning or failure section.

## Setup

Both commands need Python 3.11 or newer with the pinned validation prerequisite:

```bash
python -m pip install -r requirements-public-mirror.txt
```

The requirement pins `tzdata==2026.6` with hashes. The evaluator reads `America/Los_Angeles` only from that package, so host time-zone data and the `TZ` variable cannot change a result. A missing or different `tzdata` version produces the `timezone_data_unavailable` failure.

On Windows, install the prerequisite into the same Python that `python` resolves to on `PATH`, because Windows PowerShell 5.1 calls that executable.

## What The Validator Checks

- `data/manifest.json` has a `generatedAt` timestamp with a UTC offset.
- `data/live.json` and every manifest output were generated within five minutes of the manifest, so they come from the same refresh pass. The comparison keeps all seven fractional digits written by PowerShell, so a gap one 100-nanosecond tick past five minutes fails. `data/live.json` is compared once.
- Expected public sources are present:
  - USGS Lakeport lake level
  - USGS Cole Creek discharge
  - FHABS bloom reports
  - FHABS lab results
- Source `status`, `rowCount`, and `latestObservationDate` are present and internally consistent. A manifest whose status is `ok` cannot list a source that is not `ok`.
- FHABS source entries include positive Clear Lake row counts, a real `resourceDate` no later than the snapshot generation day, and a non-negative whole-number `resourceAgeDays`.
- Expected public outputs are listed in the manifest. Each output path must name a JSON file directly inside `data/`; any other path fails and is never read.
- Every snapshot file the evaluator reads, including `data/manifest.json` and `data/live.json`, must resolve directly inside the checkout's own `data/` directory. A `data/` directory or file that is a symlink out of the checkout fails and is never read.
- `data/manifest.json` and each output file must contain a JSON object; JSON `null` or any other value fails.
- Manifest output `recordCount` values match the generated public files: live cards plus map markers, report records, observation records, normalized sites, and the three analytics arrays.
- Manifest notes preserve the distinction between dashboard refresh time and source observation dates. This text check stays in the PowerShell validator.

## Ages And Clocks

Ages are counted in Pacific calendar days (`America/Los_Angeles`):

- **Snapshot age** runs from the Pacific day of the manifest `generatedAt` to the Pacific day of the evaluation clock.
- **Source observation age** runs from each `latestObservationDate` to the snapshot generation day. The evaluation clock does not change it.

An age warns only when it is strictly greater than `sourceFreshnessMaxAgeDays`. That value defaults to 14 when absent and must otherwise be a positive JSON integer.

Without a clock argument, each command samples the system UTC clock once. To reproduce a review result, freeze the clock with a UTC instant ending in `Z` or `+00:00`:

```bash
python scripts/validate-public-mirror.py --as-of 2026-11-17T12:00:00Z
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-public-mirror.ps1 -AsOfUtc 2026-11-17T12:00:00Z
```

Any other clock form is rejected: the Python command exits 2, and the PowerShell command fails.

## Warning Versus Failure

The validator fails when files are missing, JSON is invalid, expected sources or outputs are absent, record counts disagree, dates cannot be parsed, or an output appears to come from a different refresh pass.

The validator warns when the dashboard snapshot or a source observation date is older than the manifest freshness threshold. That warning is intentional: a reviewed public mirror can be an old static snapshot, and some public sources, especially lab-linked FHABS result records, may lag the dashboard generation date. A warning means the stale-source language must remain visible; it does not mean current conditions are known.

| Code | Severity | Meaning |
|---|---|---|
| `snapshot_old` | warning | The snapshot is older than the freshness threshold at the evaluation clock. |
| `source_observation_old` | warning | A source's latest observation is older than the threshold, measured from the snapshot generation day. |
| `snapshot_after_as_of` | failure | The manifest was generated after the evaluation clock. |
| `observation_after_generation` | failure | A source observation date is after the snapshot generation day. |
| `invalid_timestamp` | failure | A manifest or output `generatedAt` is missing or lacks a UTC offset. |
| `invalid_observation_date` / `missing_observation_date` | failure | A `latestObservationDate` is not a real date or is absent. |
| `invalid_age_limit` | failure | `sourceFreshnessMaxAgeDays` is present but not a positive JSON integer. |
| `missing_source` / `missing_source_id` / `missing_source_status` | failure | An expected source, a source id, or a source status is absent. |
| `source_status_inconsistent` | failure | The manifest status is `ok` while a source is not. |
| `invalid_row_count` / `invalid_clear_lake_row_count` | failure | A source row count is not a positive number. |
| `invalid_fhabs_resource` | failure | An FHABS resource date or age is absent, invalid, after generation, or negative. |
| `missing_output` / `invalid_output_path` | failure | An expected output is not listed, or a listed path is unsafe or resolves outside the checkout's `data/`. |
| `unsafe_snapshot_path` | failure | `data/manifest.json`, or an unlisted `data/live.json`, resolves outside the checkout's `data/`; it was not read. |
| `invalid_record_count` / `output_count_mismatch` | failure | A declared output count is not positive or does not match the file. |
| `output_refresh_gap` | failure | An output was generated more than five minutes from the manifest. |
| `missing_file` / `invalid_json` / `invalid_manifest` / `invalid_output_data` | failure | A snapshot file is missing, unreadable, or is not a JSON object (including JSON `null`). |
| `timezone_data_unavailable` / `unsupported_python` | failure | The pinned `tzdata` or Python 3.11+ prerequisite is not met. |

## Scope Of Parity

For the same checkout and clock, both commands report the same shared findings, compared by severity, code, and subject, and the same exit status from those findings. Each command still runs its own native checks, so either may report more. The PowerShell validator remains the stronger Windows release gate: it adds internal-link checks, weather-context structure and wording, reviewed-record approval and permission, the manifest note guard, and the storage smoke check. The required-text guards remain separate in each command for now.

`tests/test_public_mirror_common.py` covers the evaluator, and `tests/test_public_mirror_entrypoints.py` compares both commands in scratch checkouts. CI runs both suites on Linux, and on Windows with Windows PowerShell 5.1. The historical replay cases use a pinned copy of the May 5, 2026 snapshot in `tests/fixtures/public-mirror-2026-05-05/`, so a reviewed refresh of `data/` needs no test edits.

## Publication Boundary

Passing validation only means the public mirror is internally consistent enough to review. It does not prove current lake conditions, official advisory status, bloom severity, toxin risk, or sensor deployment.
