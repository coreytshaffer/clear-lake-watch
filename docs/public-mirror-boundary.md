# Public Mirror Boundary

Status: active boundary for static publishing

Date: 2026-05-05

Clear Lake Watch has two different surfaces:

- private operations surface: ignored local records, SQLite stores, reviewer notes, draft decisions, field/microscopy intake, and future sensor/operator data
- public mirror: static HTML, CSS, JavaScript, reviewed public JSON exports, source/method notes, and conservative dashboard context

The public mirror is a publication target. It is not the operational system of record.

## Public Mirror May Include

- `index.html`
- `project.html`
- `methodology.html`
- `styles.css`
- `app.js`
- `assets/`
- public JSON exports under `data/`
- public documentation under `docs/`
- example-only schemas and example-only decision files

Public JSON exports may include:

- `data/live.json`
- `data/manifest.json`
- `data/site-review-summary.json`
- `data/reviewed-field-observations.json`
- `data/weather-context.json`

## Keep Private

Do not publish:

- `data/private/`
- `data/site-review-decisions.local.json`
- `data/*.local.json`
- `*.local.sqlite`
- raw field/microscopy intake records
- reviewer identity or private reviewer notes
- unpublished QA decisions
- prompt/model logs
- raw or semi-processed local sensor feeds
- runtime files such as `server.pid`, `server.out.log`, or `server.err.log`

## Export Rule

Private records can affect the public mirror only through reviewed, sanitized exports.

```text
private local record -> review decision -> sanitized export -> static public mirror
```

If a record is not approved for public export, the public mirror should show either no record or an aggregate/non-sensitive status summary.

## Current Local Stores

The current ignored local stores are:

- `data/private/site-review.local.sqlite`
- `data/private/field-microscopy.local.sqlite`
- `data/site-review-decisions.local.json`
- `data/private/field-microscopy-intake.local.json`

These files are local working records and should remain outside the public mirror.

Git ignore rules keep these stores out of commits, but they do not keep files out of a web root. Public hosting must use a clean checkout of reviewed tracked files or an equivalent clean artifact, never the developer working tree that contains these stores.

## Before Public Publishing

Use `docs/publication-review-checklist.md` for the full publication decision gate.

Before any broad public publish:

1. Refresh public data or intentionally document a static snapshot.
2. Run `scripts/validate-public-mirror.ps1` and `python scripts/validate-public-mirror.py`.
3. Confirm the proposed publish source is a clean checkout of reviewed tracked files or an equivalent clean artifact, not a developer working tree.
4. Confirm `.gitignore` still excludes private local records and SQLite stores.
5. Confirm the public app does not fetch `data/private/`, `*.local.json`, or detailed private review artifacts.
6. Capture a current screenshot if the publish is meant for portfolio promotion.
