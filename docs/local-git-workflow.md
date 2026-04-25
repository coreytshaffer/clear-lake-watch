# Local Git Workflow

## Current Status

Git is available through GitHub Desktop's bundled Git, but the active Clear Lake Watch folder is not currently a Git repository.

That means:

- `git --version` may fail if `git.exe` is not on `PATH`.
- an explicit GitHub Desktop Git path can still run Git commands.
- `git --no-pager diff` cannot show project changes until the folder is inside a Git repository.

This is a tooling-state issue, not a dashboard-code issue.

## Find Git Locally

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\find-local-git.ps1
```

The script checks:

- `git` on `PATH`
- system Git under `C:\Program Files\Git`
- GitHub Desktop's bundled Git under `%LOCALAPPDATA%\GitHubDesktop`

Use the quiet mode when another script needs only the executable path:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\find-local-git.ps1 -Quiet
```

## Current Recommendation

Use the GitHub Desktop bundled Git path for local diagnostics until a normal repository workflow is chosen.

Do not install global tools from this project. Do not mutate system `PATH` from the dashboard scripts.

## Repository Decision Still Needed

Before using `git diff`, choose one of these paths:

- initialize this folder as a new repository
- move this folder's contents into a cloned GitHub repository
- open the project in GitHub Desktop and let it manage the repository setup

This should be an intentional decision because creating `.git` changes the project from a folder snapshot into a repository root.

## Fallback Review Workflow

If the folder is still not a repository, use the project validator and targeted file checks:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-dashboard.ps1 -SkipHttp
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\preview-site-review-decisions.ps1
```

For generated data changes, also check:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-site-review-report.ps1
```

## Decision Point

The next Git decision is whether Clear Lake Watch should become its own repository now or be folded into a broader environmental-monitoring repository later.
