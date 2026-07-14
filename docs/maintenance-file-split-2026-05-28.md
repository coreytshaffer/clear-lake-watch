# Maintenance File Split - 2026-05-28

**Status:** completed first maintenance split
**Scope:** `app.js`, `refresh-live-data.ps1`, and `validate-public-mirror.ps1`

This note records a small behavior-preserving split of the largest dashboard and maintenance files. The purpose is ownership and reviewability: smaller helpers make future changes easier to inspect without rewriting the public dashboard.

Clear Lake Watch remains a late prototype / early MVP. It is not official public-health guidance, recreation guidance, emergency guidance, or forecasting capability, and this maintenance split does not add monitoring authority, official review, or new public data.

## What Moved

| File | Extracted helper | Purpose |
| --- | --- | --- |
| `app.js` | `scripts/dashboard-utils.js` | Date formatting, age calculations, and localStorage helpers used by dashboard rendering and local Data QA notices. |
| `scripts/validate-public-mirror.ps1` | `scripts/public-mirror-link-validation.ps1` | Tracked-file internal link checks for Markdown, HTML, JavaScript, and manifest files. |
| `scripts/refresh-live-data.ps1` | `scripts/refresh-live-data.utilities.ps1` | Generic date, text, field, and number parsing helpers used by the public-source refresh workflow. |

## Verification

- `node --check .\app.js`
- `node --check .\scripts\dashboard-utils.js`
- PowerShell parser checks for the refresh and validation scripts plus both helper scripts.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-public-mirror.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\refresh-live-data.ps1 -DryRun`
- Local browser smoke check through a temporary static server confirmed the dashboard loaded rendered snapshot cards, data-product cards, and map marker cards after the ES module split.

The validator still reports the expected stale-source warnings for old FHABS report and result observations. Those warnings are trust cues, not failures.

## Follow-Up

Further splitting should be done only when a concrete change needs it. Good next candidates are map rendering, notification controls, manifest validation, and FHABS refresh logic. Avoid a large rewrite unless behavior can be checked in small browser and dry-run slices.
