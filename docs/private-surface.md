# Private Review Surface

Status: first local implementation slice

Clear Lake Watch is keeping the public dashboard static for now. The first private surface is therefore not an authenticated web portal yet. It is a local review workspace made of ignored private JSON files plus scripts that create, validate, and export only public-safe records.

## Selected First Surface

Use local SQLite for records that need to be reused across more than one project. Keep local JSON files as import/export and inspection helpers.

Why this is the right first step:

- It matches the current no-build static dashboard while giving private review records a reusable local store.
- It keeps private reviewer notes out of the public mirror.
- It is easy to inspect before any database or login system exists.
- It lets the field/microscopy schema settle before UI work begins.

The SQLite-specific workflow is documented in `docs/private-sqlite-surface.md`.

Reusable schema rules are documented in `docs/reusable-schema-package.md` and live in the sibling repository `../environmental-monitoring-schemas/`.

## Private Workspace

Private working files live under:

```text
data/private/
```

This folder is ignored by Git. It can hold draft field observations, reviewer notes, raw photo references, custody notes, and correction comments.

Starter command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\new-field-microscopy-intake.ps1
```

The script creates:

```text
data/private/field-microscopy-intake.local.json
```

Validate the private intake file before importing:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-field-microscopy-intake.ps1
```

Import into SQLite:

```powershell
python .\scripts\field_microscopy_db.py import-json
```

## Public Export

The public dashboard should consume only reviewed exports.

Current public-safe placeholder:

```text
data/reviewed-field-observations.json
```

SQLite export command:

```powershell
python .\scripts\field_microscopy_db.py export-public
```

JSON-only export command, kept as a simple fallback:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\export-reviewed-field-observations.ps1
```

Synthetic review-cycle smoke check:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-field-microscopy-review-cycle.ps1
```

SQLite smoke check:

```powershell
python .\scripts\field_microscopy_db.py smoke-cycle
```

This check creates a temporary approved-public record under the ignored private workspace, runs validation, exports it, confirms private fields are absent from the public export, and removes the temporary files.

The exporter includes only records where:

- `qaStatus` is `approved-public`
- `permissionToPublish` is `true`

The exporter excludes private fields such as collector identity details, custody notes, QA notes, raw photo paths, and exact coordinates unless a later explicit policy allows them.

## Not Yet Implemented

This is not yet:

- an authenticated portal
- a multi-user review queue
- a public submission form
- a source of official public-health guidance
- a live field-data feed

## Next Decision Point

After using SQLite with one real or representative sample record in another project, revisit whether the sibling schema repository should be published for broader reuse. For now, it stays private.
