# Manual Refresh Dry Run - 2026-05-28

Status: completed local dry-run rehearsal.

This note records a manual `-DryRun` rehearsal of the Clear Lake Watch public snapshot refresh path. It proves that the refresh script can fetch public sources, resolve FHABS resources, normalize the public data products, and reach the write stage without mutating public JSON files.

It does not publish a new snapshot, update GitHub Pages, enable scheduled refreshes, validate current lake conditions, or create public-health, recreation, emergency, or forecast guidance.

## Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\refresh-live-data.ps1 -DryRun
```

## Result

The command completed and reported these skipped writes:

- `data/reports.json`
- `data/observations.json`
- `data/sites-normalized.json`
- `data/analytics.json`
- `data/manifest.json`
- `data/live.json`

Because `-DryRun` was used, the files above were not written.

## Follow-Up Gate

Before a real refresh is published:

- rerun the dry run if source dates or network behavior may have changed;
- run the real refresh only when public JSON updates are intentional;
- run `scripts/validate-public-mirror.ps1`;
- review stale-source warnings and changed files before publishing.
