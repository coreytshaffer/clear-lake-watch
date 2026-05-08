# Public Mirror Review - 2026-05-08

Status: public mirror review started; no public promotion performed

## Scope

This review evaluates whether the current portfolio-safe release prep branch is ready to become the public GitHub Pages mirror for Clear Lake Watch.

Current review branch:

- `codex/portfolio-safe-release-prep`
- Draft PR #2: `https://github.com/coreytshaffer/clear-lake-watch/pull/2`
- Review-only base branch: `codex/portfolio-safe-release-base`

Current public mirror target:

- GitHub Pages URL: `https://coreytshaffer.github.io/clear-lake-watch/`
- GitHub Pages source reported by GitHub: `main` branch, repository root
- Remote `main` head: `34cb915 Add project brief PDF`

## Immediate Finding

Do not merge the current review branch directly into `main`.

The current review branch and `origin/main` do not share a merge base. A normal PR retarget or direct merge would mix unrelated histories and is not the right public-release path.

The safer public mirror route is a curated publish step:

1. decide the exact public file set,
2. exclude private/review-only/local convenience artifacts,
3. copy or reconstruct only the approved public mirror files onto a clean branch based on `origin/main`,
4. run validation and screenshot checks,
5. then review the final diff before updating `main`.

## Current Public State

`origin/main` currently contains a small public portfolio set:

- `LICENSE`
- `README.md`
- `docs/Clear-Lake-Watch-Project-Brief.pdf`
- `docs/project-brief.md`
- `methodology.html`

The live GitHub Pages URL returned HTTP 200 during review, but `https://coreytshaffer.github.io/clear-lake-watch/data/manifest.json` returned HTTP 404. The live site appears to include dashboard-era content that is not represented by the current `origin/main` file tree.

Treat the live Pages state as potentially stale until a deliberate Pages rebuild or public mirror update confirms the source tree and deployed site match.

## Candidate Public Mirror Files

These are reasonable candidates for a curated public mirror update, pending final review:

- `index.html`
- `project.html`
- `methodology.html`
- `styles.css`
- `app.js`
- `manifest.webmanifest`
- `sw.js`
- `.nojekyll`
- `README.md`
- `assets/`
- reviewed public JSON exports under `data/`
- reviewed public docs such as:
  - `docs/project-brief.md`
  - `docs/Clear-Lake-Watch-Project-Brief.pdf`
  - `docs/public-mirror-boundary.md`
  - `docs/publication-review-checklist.md`
  - `docs/source-audit.md`
  - `docs/forecast-boundary.md`
  - `docs/weather-context-contract.md`
  - `docs/field-microscopy-intake-contract.md`
  - `docs/clear_lake_watch_portfolio_case_study.md`
  - `docs/published-commentary.md`
  - `docs/resume-linkedin-snippets.md`

## Do Not Broadly Publish Without Extra Review

These files are useful in the private review branch but should not be included in a broad public mirror update without a specific reason:

- `portfolio-materials.html`
- `docs/trusted-review-request.md`
- `docs/trusted-review-feedback-log.md`
- `docs/conversation-log.md`
- `docs/local-git-scope-review-2026-05-07.md`
- `docs/local-git-workflow.md`
- `docs/review-screenshots/`
- `docs/screenshot-only-portfolio-packet.md`
- `shortcuts/Clear Lake Watch.lnk`
- `data/site-review.json`
- any `data/*.local.json`
- any `data/private/`
- any `*.local.sqlite`
- runtime files such as `server.pid`, `server.out.log`, and `server.err.log`

Reason: these artifacts are local review aids, private/trusted-review workflow documents, detailed QA records, screenshots, shortcut binaries, or private working files. They are not required for the public mirror and may confuse the public/private boundary.

## Public Claim Boundary

Any public mirror update must preserve these claims:

- Clear Lake Watch is a `late prototype / early MVP`.
- It is not official public-health guidance.
- It does not issue official advisories.
- It is not a validated forecast.
- It is not a deployed sensor network.
- Unresolved site-registry markers must remain visibly marked as `needs-local-review`.
- Weather context remains driver/context information, not direct lake-health measurement.
- Field/microscopy records remain private unless exported through reviewed public-safe records with permission to publish.

## Required Checks Before Public Mirror Update

Before updating `main`, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\refresh-live-data.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-dashboard.ps1 -SkipHttp
python .\scripts\site_review_db.py validate
python .\scripts\field_microscopy_db.py validate
git diff --check
git ls-files --others --exclude-standard
```

For a fresh public publish, do not use `-AllowStaleSnapshot`.

Before final promotion, capture a current screenshot after the final public file set is staged on the clean public branch. If possible, include one non-Windows or physical mobile browser check.

## Recommendation

Use a clean-clone or clean-branch public mirror path.

Do not retarget Draft PR #2 to `main`. Keep it as the complete review packet. Create a separate public mirror candidate branch from `origin/main` with only the approved public file set, then review that smaller diff before any main-branch update.

## Decision Needed

Choose the public mirror file set:

1. dashboard-only public mirror,
2. dashboard plus selected portfolio docs,
3. full review packet, not recommended for broad public mirror.

Recommended choice: dashboard plus selected portfolio docs.

## Selected File Set

The recommended file set is now drafted in `docs/public-mirror-file-set-2026-05-08.md`.

Key implementation note: `README.md` and `scripts/validate-dashboard.ps1` should be trimmed or replaced for the clean public mirror candidate branch so they do not require private/review-only docs that are intentionally excluded from broad public publishing.
