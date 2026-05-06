# Local Git Workflow

## Current Status

As of May 5, 2026, Git is available on `PATH` for this project shell:

```text
git version 2.54.0.windows.1
```

The active Clear Lake Watch folder is also a Git work tree:

```text
C:/Users/corey/Documents/Codex/Clear-Lake-Watch
```

That means local review commands such as `git status --short` and `git --no-pager diff` can be run from the project root.

This resolves the local Git availability backlog item. It does not mean the current local changes are ready to publish, stage, commit, or push.

## Recommended Local Review Commands

Check the working tree:

```powershell
git status --short
```

Review all unstaged changes:

```powershell
git --no-pager diff
```

Review one file:

```powershell
git --no-pager diff -- .\docs\backlog.md
```

List untracked files:

```powershell
git ls-files --others --exclude-standard
```

## Find Git Locally

If a future shell cannot find `git`, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\find-local-git.ps1
```

The script checks:

- `git` on `PATH`
- system Git under `C:\Program Files\Git`
- GitHub Desktop's bundled Git under `%LOCALAPPDATA%\GitHubDesktop`

Use quiet mode when another script needs only the executable path:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\find-local-git.ps1 -Quiet
```

## Publication Boundary

The current repository state is local-only prior to review.

Before staging or committing, do a scoped review of:

- public files intended for the static mirror
- ignored private files that must remain local
- generated JSON files that changed during refresh
- docs that describe implemented proof versus future vision
- shortcuts or local runtime conveniences that should not be part of a public release

Git availability is not a publication decision. Publication still needs a separate review pass.

## Fallback Review Workflow

If Git becomes unavailable in a future shell, use the project validator and targeted file checks:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-dashboard.ps1 -SkipHttp
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\preview-site-review-decisions.ps1
```

For generated data changes, also check:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-site-review-report.ps1
```

## Next Decision Point

The next Git-related decision is not tool availability. It is whether a future publication pass should stage the current local work directly, split it into smaller commits, or move through a clean-clone publish path.
