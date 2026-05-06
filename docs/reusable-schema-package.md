# Reusable Schema Package

Status: first local package slice

Clear Lake Watch now consumes field/microscopy review rules from a small reusable Python package instead of burying them inside one project script.

Package path:

```text
../environmental-monitoring-schemas/
```

Current module:

```text
../environmental-monitoring-schemas/src/environmental_monitoring_schemas/field_microscopy.py
```

## Why This Exists

The field/microscopy review workflow is likely to become common across more than Clear Lake Watch. A reusable schema package keeps the rules in one place:

- required private intake fields
- allowed review statuses
- approved-public and permission-to-publish rules
- public export shape
- private-field exclusion checks

The SQLite tool, future command-line review tools, and future local UI can all import the same package.

## Current Public API

The package currently exposes:

- `validate_record(record)`
- `load_intake_records(path)`
- `make_public_record(record)`
- `build_public_export(records)`
- `assert_no_private_fields(payload)`
- `validate_database_review_state(rows)`

It also exposes constants for schema versions, required fields, allowed statuses, and forbidden public fields.

## Local Usage

From the repo root:

```powershell
python -c "import sys; sys.path.insert(0, '..\\environmental-monitoring-schemas\\src'); from environmental_monitoring_schemas.field_microscopy import ALLOWED_REVIEW_STATUSES; print(sorted(ALLOWED_REVIEW_STATUSES))"
```

When running ad hoc commands without installing the package, set `PYTHONPATH`:

```powershell
$env:PYTHONPATH = "..\environmental-monitoring-schemas\src"
```

The existing SQLite tool handles this path setup internally, so normal project commands can still be run directly:

```powershell
python .\scripts\field_microscopy_db.py validate
```

## Boundary

This is a schema and validation package, not a database, web app, or public dashboard component. It should stay dependency-free unless a future need clearly justifies adding a validation library.

## Next Decision Point

Current decision: the package now lives in its own local sibling repository at `../environmental-monitoring-schemas/`, has an initial local commit, and should stay private for now.

Next decision point:

After one representative consuming project beyond Clear Lake Watch, revisit whether to publish the package to GitHub as a standalone public repository. Until then, treat it as a private local dependency.
