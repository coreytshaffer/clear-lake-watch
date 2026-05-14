# Scheduled Public Refresh Design

Status: design proposal only. No unattended publication workflow is enabled.

Clear Lake Watch should keep the current public mirror as a reviewed static snapshot until refresh behavior has been proven. The first scheduled-refresh design should create a repeatable candidate branch, run validation, and require human review before any generated JSON reaches `main`.

This is a reviewed public snapshot workflow. It is not live monitoring, operational alerting, public-health guidance, recreation guidance, emergency guidance, or a real-time advisory system.

## Recommended Path

Use both local and GitHub Actions paths, with different responsibilities:

| Path | Role | Publish behavior |
|---|---|---|
| Local manual refresh | Development, source debugging, and reviewer inspection. | Never publish automatically. |
| GitHub Actions scheduled candidate | Repeatable public-data refresh on a schedule. | Open or update a candidate PR only. |
| Human review | Confirm validation warnings, source dates, maps, and public language. | Merge only after review. |

Do not let a scheduled run commit directly to `main`.

## Proposed Scheduled Workflow

1. Run on a conservative schedule, such as weekly, plus manual dispatch.
2. Check out the repository on a generated branch such as `refresh/public-snapshot-candidate`.
3. Run `scripts/refresh-live-data.ps1`.
4. Run `scripts/write-weather-context-public-source.ps1` for reviewed public-source weather context, or `scripts/write-weather-context-unavailable.ps1` if the weather source cannot be reviewed for that release.
5. Run `scripts/validate-public-mirror.ps1`.
6. Capture validation output, including stale-source warnings.
7. Fail closed if validation fails.
8. If generated public files changed, open or update a PR titled `Refresh public snapshot candidate`.
9. Require human review before merge.

## Required Validation Gates

The workflow must fail before publication when:

- required public files are missing,
- JSON files cannot be parsed,
- expected source IDs are missing from `data/manifest.json`,
- source `status`, `rowCount`, or `latestObservationDate` values are missing,
- generated outputs appear to come from different refresh passes,
- manifest output counts disagree with generated public files,
- private, local, or review-only files are staged,
- public-health, advisory, or emergency boundary language is removed.

Warnings are acceptable only when they are explicit and reviewed. For example, FHABS report or lab-linked sample dates may be older than the dashboard refresh time. Those warnings should preserve the distinction between source observation dates and dashboard generation dates.

## Rollback And Failure Behavior

- If source fetches fail, do not publish partial outputs.
- If validation fails, keep the last reviewed public snapshot on `main`.
- If a candidate PR is wrong, close it rather than merging and reverting public data.
- If a bad public snapshot is merged, revert the merge commit and rerun validation against the restored snapshot.
- Keep the public page language focused on source freshness and uncertainty; do not turn validation failures into public alerts.

## Private Boundary

The scheduled workflow must never publish:

- `data/*.local.json`,
- local SQLite stores,
- private review notes,
- trusted-review materials,
- unpublished field or microscopy records,
- local server logs,
- shortcut or desktop-helper files.

Generated public exports should remain limited to reviewed static files already listed in the public mirror validator.

## First Implementation Step

Do not enable the scheduled workflow yet. The first implementation slice should add a disabled or manual-only GitHub Actions workflow that runs refresh and validation, reports warnings, and opens no PR until the command has been reviewed in a test run.

Only after that test passes should the project consider a scheduled candidate-PR workflow.
