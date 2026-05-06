# Private SQLite Review Surface

Status: representative local draft imported; command-line SQLite workflow is current default

Clear Lake Watch is moving the private field/microscopy review surface from loose local JSON files toward a reusable local SQLite store. The public dashboard remains static and should still consume only sanitized JSON exports.

The SQLite tool now imports shared review rules from the reusable schema package documented in `docs/reusable-schema-package.md` and located in the sibling repository `../environmental-monitoring-schemas/`.

## Why SQLite

SQLite is a good next step because it is:

- local-first and file-based
- included with Python's standard library
- easy to back up as one ignored file
- reusable across Clear Lake Watch and related monitoring projects
- better than raw JSON once records need filtering, review states, and repeatable exports

## Local Database

Default private database:

```text
data/private/field-microscopy.local.sqlite
```

This file is ignored by Git because `data/private/` is ignored.

## Commands

Initialize the database:

```powershell
python .\scripts\field_microscopy_db.py init
```

Import the current private JSON intake file:

```powershell
python .\scripts\field_microscopy_db.py import-json
```

The current ignored local draft file has been imported once into SQLite. Because that record is still `draft` and `permissionToPublish` is false, it validates as private-only and exports zero public records.

Validate review rules in the database:

```powershell
python .\scripts\field_microscopy_db.py validate
```

Export reviewed public-safe records:

```powershell
python .\scripts\field_microscopy_db.py export-public
```

Run the SQLite smoke cycle:

```powershell
python .\scripts\field_microscopy_db.py smoke-cycle
```

The smoke cycle creates a temporary private database and temporary export, imports a synthetic approved-public record, validates the database, exports the public JSON, checks that private fields are absent, and removes the temporary files.

## Public Boundary

The SQLite database can contain private review fields. The public export must not.

Private fields excluded from public exports include:

- collector name and organization
- custody ID and custody notes
- private field notes
- reviewer identity and QA notes
- raw photo or voucher references
- exact latitude and longitude

Only records where `qa_status` is `approved-public` and `permission_to_publish` is true can enter `data/reviewed-field-observations.json`.

## Next Decision Point

After the first real or representative review pass, decide whether the next common layer should be:

- a small command-line review workflow around SQLite
- a lightweight local desktop/browser review UI
- keeping the sibling schema repository private until another project is ready to consume it directly

Current default:

Keep using the command-line SQLite workflow plus ignored JSON files until editing private review records becomes too cumbersome.
