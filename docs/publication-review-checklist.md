# Publication Review Checklist

Status: local checklist for a future publication pass

Date: 2026-05-05

This checklist is for deciding whether local Clear Lake Watch work is ready to stage, commit, push, or promote. It does not publish anything by itself.

## Decision Gate

Before publishing, choose the scope:

- local review only
- commit to private repository only
- request private trusted review on a review-only PR
- update public static mirror
- promote as flagship portfolio artifact

If the scope is only local review, stop before staging.

For the recommended portfolio-safe release scope, see `docs/portfolio-safe-release-scope.md`. That scope favors evidence, screenshots, case study polish, and conservative claims before any live weather telemetry or public field-intake expansion.

For the active public mirror review, see `docs/public-mirror-review-2026-05-08.md`.

For the recommended public mirror file set, see `docs/public-mirror-file-set-2026-05-08.md`.

## Draft PR Review Surface Gate

The current review surface is Draft PR #2:

- `https://github.com/coreytshaffer/clear-lake-watch/pull/2`
- head branch: `codex/portfolio-safe-release-prep`
- review-only base branch: `codex/portfolio-safe-release-base`
- target boundary: not `main`

This draft PR is for private/trusted review and does not publish, promote, or refresh the public mirror. Use `docs/trusted-review-request.md` for the review ask, `docs/trusted-review-feedback-log.md` for private feedback capture, and `portfolio-materials.html` as the local index for the current review packet.

Do not retarget Draft PR #2 to `main` or treat it as a public release without starting a separate public mirror/main-branch promotion review.

## Freshness Gate

For a fresh public publish:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\refresh-live-data.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-dashboard.ps1 -SkipHttp
```

Do not publish a stale snapshot as if it were fresh. Note: the validator warns on a stale snapshot but does not block publication, and no `-AllowStaleSnapshot`-style override flag exists — freshness is a manual reviewer decision.

For an intentional static portfolio snapshot, write a release note or README note that names the snapshot date and why it is being preserved.

## Private-File Gate

Confirm these files stay local:

- `data/private/`
- `data/site-review-decisions.local.json`
- `data/*.local.json`
- `*.local.sqlite`
- raw field/microscopy intake records
- reviewer identity or private reviewer notes
- prompt/model logs
- runtime files such as `server.pid`, `server.out.log`, and `server.err.log`

Confirm public pages and app code do not fetch private paths:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-dashboard.ps1 -SkipHttp
```

## Claim-Review Gate

Before broad promotion, check public wording against the flagship boundary:

- Say `late prototype / early MVP`.
- Say `watershed intelligence prototype` or `situational-awareness dashboard`.
- Do not say official advisory, official public-health guidance, complete monitoring platform, validated forecast, or deployed sensor network.
- Keep weather context labeled as driver/context data, not direct lake-health measurement.
- Keep field/microscopy records labeled private/reviewed until public export rules are satisfied.

## Site-Registry Gate

Do not promote `needs-local-review` FHABS markers to reviewed status without stronger evidence or local review.

For the current broad-place policy, medium-priority offset cases remain attached to broad place-based entries unless a future review supports a specific coordinate move or child site.

## Screenshot Gate

For private review, the current local mobile-width screenshot is:

- `docs/review-screenshots/clear-lake-watch-mobile-width-2026-05-05.png`

For broad promotion, capture a final current screenshot after validation and wording review. Prefer at least one non-Windows or physical mobile browser if available.

## Git Scope Gate

Use local Git only after deciding the publication scope:

```powershell
git status --short
git --no-pager diff
git ls-files --others --exclude-standard
```

Review generated data files separately from hand-authored docs and code.

Before staging, decide whether to:

- stage the current local work directly
- split the work into smaller commits
- use a clean-clone publish path

Git availability is not a publication decision.

For the current local portfolio-safe release prep branch, see `docs/portfolio-release-branch-handoff.md` before pushing or opening a pull request.

## Final Publish Gate

Only publish after all of these are true:

- validation passes with no unresolved failures, and either the snapshot is fresh or the release clearly explains a preserved static snapshot (the validator only warns on staleness; it does not enforce this)
- private local files are excluded
- public claims match the maturity plan
- a current screenshot exists for promotion use
- Git scope is reviewed
- the publish target is explicit

If any item is uncertain, keep the work local.

## Soft-Share Gate

Before broad promotion, consider a private review with an SNHU advisor, career services, or one trusted environmental/water-quality contact.

Ask whether the project is clear, professional, appropriately scoped, and careful enough around public-health wording.

Use the Draft PR Review Surface Gate above for the current trusted-review route. Keep reviewer feedback private unless the reviewer explicitly grants permission to quote or reference it.
