# Deployment Notes

Clear Lake Watch is currently a static, no-build dashboard. A public deployment can serve the project folder directly as static files after the data refresh scripts have generated the JSON files under `data/`.

## Preflight Checklist

Run these checks before publishing:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\refresh-live-data.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\refresh-osm-shoreline.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-weather-context-public-source.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-public-mirror.ps1
python .\scripts\validate-public-mirror.py
```

If a local server is already running on port `4173`, run the full endpoint check:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-public-mirror.ps1 -CheckHttp
```

If you are intentionally reviewing an older static snapshot for portfolio or archival work, make that choice explicit:

```powershell
python .\scripts\validate-public-mirror.py
```

Do not treat a passing validator as permission to hide stale dates. If the snapshot is intentionally old, keep the release note or README static-snapshot language visible.

Use `docs/publication-review-checklist.md` before staging, committing, pushing, or promoting the dashboard. That checklist separates local review, private repository work, public mirror updates, and flagship portfolio promotion.

Current working posture as of May 5, 2026:

- The public snapshot was refreshed locally on May 5, 2026.
- Keep publication as a separate decision from local refresh.
- Use the formal refresh runbook or manual workflow for reviewed refresh rehearsal, not unattended publication.
- Capture a current screenshot before broad portfolio promotion.

## GitHub Pages

The project includes `.nojekyll` so GitHub Pages will serve files exactly as written.

Recommended first setup:

- Put the contents of this project folder at the root of a GitHub repository.
- In repository settings, enable GitHub Pages from the main branch root.
- Confirm that these paths work after deployment:

```text
/
/project.html
/methodology.html
/data/live.json
/data/manifest.json
/data/lake-shoreline.json
/data/weather-context.json
/data/weather-context.example.json
/assets/clear-lake-watch.ico
```

## Netlify Or Similar Static Hosting

This project does not require a build command.

Recommended settings:

- Build command: leave blank
- Publish directory: project root
- Node version: not required

## Local Windows Launcher

For local use, create a Desktop shortcut with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\create-windows-shortcut.ps1
```

The shortcut targets `scripts\launch-dashboard.ps1`, starts a local static server on `http://127.0.0.1:4173/`, and opens the dashboard in the default browser.

Pinning note: Windows generally requires pinning from the user interface. After the shortcut appears on the Desktop, right-click it and choose **Pin to taskbar**.

The launcher writes runtime PID and log files under `%LOCALAPPDATA%\ClearLakeWatch\runtime` when possible. Those files are local diagnostics only and should not be copied into the static web root.

## Local Portfolio Materials Shortcut

For portfolio review, `portfolio-materials.html` is the local one-file index for the README, dashboard, project brief, case study, Draft PR #2, trusted-review docs, screenshots, career materials, and boundary evidence.

A desktop shortcut named `Clear Lake Watch Portfolio Materials` may point directly to this local index. A taskbar pinned-copy can be placed under the Windows pinned-items folder as a convenience, but Windows may still require an Explorer refresh, sign-out/sign-in, or manual pinning before it appears. These shortcuts are local navigation aids only; they do not publish the project, update the public mirror, retarget Draft PR #2, or approve a public release.

## Local Git Diagnostics

Git is currently available on `PATH` in this project shell, and this folder is a Git work tree. For local review, run:

```powershell
git status --short
git --no-pager diff
```

If `git` is not available on `PATH` in a future shell, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\find-local-git.ps1
```

On this machine, Git may also be available through GitHub Desktop's bundled Git if a future shell cannot find system Git.

Important: Git availability only supports local review. It does not mean local changes are ready to stage, commit, push, or publish. See `docs/local-git-workflow.md` before any publication pass.

## Data Refresh Model

The current prototype uses manual refresh scripts. Public hosting will serve the latest committed JSON files until a future scheduled workflow updates them.

`scripts/refresh-live-data.ps1` resolves FHABS CSV URLs from CA Open Data package metadata at refresh time. This avoids pinning the dashboard to dated CSV download filenames while still allowing manual override environment variables if the catalog changes unexpectedly.

The same refresh writes `data/manifest.json`, which records source status, latest observation dates, source row counts, generated output counts, and FHABS resource file ages. Treat the manifest as the first pre-publication health summary for the static dashboard snapshot.

Near-term options:

- Refresh locally and commit generated JSON updates.
- Use the manual `Formal Public Refresh` workflow for reviewed refresh rehearsal.
- Keep OSM shoreline refresh less frequent than live data refreshes because shoreline geometry changes slowly.

## Recommended Deployment Posture

While the combined lake, weather, field-data, and experimental-AI roadmap is still maturing, the safest operating model is:

- private operations layer
- public documentation and demo layer

See `docs/public-mirror-boundary.md` for the current public/private file boundary.

That means the real operational system can stay private or invite-only while the public-facing layer focuses on the methodology, screenshots, reviewed exports, roadmap, and a clearly labeled dashboard mirror.

Keep private until the trust model is tighter:

- `data/private/`
- `data/site-review-decisions.local.json`
- `data/*.local.json`
- `*.local.sqlite`
- combined live operational dashboards
- raw or semi-processed local sensor feeds
- experimental analytics or forecast outputs
- edge-agent or LLM-assisted features
- unreviewed field or community-science submissions
- internal QA dashboards and prompt/model logs

Safe public targets include:

- project overview and architecture notes
- project roadmap and source inventory on `project.html`
- methodology and interpretation guidance
- reviewed static exports and screenshots
- aggregate exports such as `data/site-review-summary.json`
- public-safe reviewed exports such as `data/reviewed-field-observations.json`
- a clearly labeled demo or public mirror
- roadmap and stretch-goal documentation

Move from private operations toward a broader public beta only after freshness semantics, visible signal types, site-registry QA, weather-context interpretation, and experimental-feature boundaries are all stable.

## Public Interpretation Requirements

Keep these pieces visible after deployment:

- Methodology page
- Public-health disclaimer
- Observation dates
- Dashboard refresh date
- OSM attribution and ODbL license link
- Source links for FHABS, USGS, Lake County, Big Valley, CEDEN, and OSM

## Known Deployment Caveats

- The dashboard is static and does not issue official advisories.
- The weather-context panel should remain marked `unavailable` until `data/weather-context.json` is generated from reviewed, public-safe backbone telemetry.
- Detailed site-review records, local decision JSON, and SQLite review stores are private operational artifacts; publish only `data/site-review-summary.json`.
- Field/microscopy intake records remain private unless exported through `data/reviewed-field-observations.json`.
- The local Windows shortcut and launcher are convenience tools only; they are not needed for public hosting.
- The launcher writes runtime PID and log files under `%LOCALAPPDATA%\ClearLakeWatch\runtime` when possible. Do not publish root-level `server.pid`, `server.out.log`, or `server.err.log` files if they are recreated manually.
- The current refresh scripts run in PowerShell and are intended for local or Windows-based automation.
- Future scheduled deployment should avoid live client-side calls to Overpass or other public APIs on every page view.
- Git is currently available on `PATH`; use `docs/local-git-workflow.md` for local review commands and keep publication as a separate scoped decision.
