# Field And Microscopy Intake Contract

Status: local private surface started

This contract defines the minimum shape for future field observations and freshwater phytoplankton microscopy records. It is intentionally review-first: records should start in a private intake layer and only reach public Clear Lake Watch exports after review and permission checks.

## Boundary

Field and microscopy records are a separate source family.

They must not be blended into:

- FHABS report records
- CLAMP / CEDEN chemistry records
- Tribal monitoring records
- USGS hydrology records
- public-health advisory language
- forecast training labels while unresolved or unreviewed

## Workflow

```text
private intake -> QA review -> publish decision -> sanitized public export -> static dashboard
```

The public-safe review workflow is documented in
[field-microscopy-review-workflow.md](field-microscopy-review-workflow.md).

The public dashboard should consume only a sanitized export such as `data/reviewed-field-observations.json`. The private intake file, reviewer notes, raw photo paths, collector identity details, and unpublished QA comments should stay outside the public static site.

The first private surface is documented in `docs/private-surface.md`. It uses ignored local JSON files under `data/private/` plus an export script that writes only reviewed public-safe records.

## Required Private Intake Fields

Record identity:

- `recordId`
- `schemaVersion`
- `recordType`
- `createdAt`
- `updatedAt`
- `createdBy`

Sample event:

- `sampleDateTime`
- `collectorName`
- `collectorOrganization`
- `collectionProgram`
- `custodyId`
- `custodyNotes`

Location:

- `siteId`
- `siteName`
- `latitude`
- `longitude`
- `gpsPrecisionMeters`
- `coordinateSource`
- `lakeArm`
- `locationPrivacyClass`

Sample metadata:

- `sampleType`
- `collectionMethod`
- `preservationMethod`
- `fieldNotes`

Microscopy metadata:

- `microscopeMethod`
- `magnification`
- `preparationMethod`
- `taxonName`
- `taxonRank`
- `identificationConfidence`
- `abundanceEstimate`
- `photoOrVoucherReference`

Review and publication:

- `qaStatus`
- `qaReviewer`
- `qaReviewedAt`
- `qaNotes`
- `permissionToPublish`
- `publicLocationPrecision`
- `publicSummary`

## Allowed Review Statuses

- `draft`
- `submitted`
- `needs-correction`
- `approved-private`
- `approved-public`
- `rejected`

Only `approved-public` records with `permissionToPublish: true` may be included in a public export.

## Public Export Rules

Public records should include:

- stable record ID
- source family: `field-microscopy`
- public site ID or generalized site label
- public lake arm
- sample date
- reviewed observation type
- taxon name when publishable
- identification confidence
- abundance estimate or category
- public QA status
- public summary

Public records should exclude:

- collector personal contact details
- private reviewer notes
- raw QA comments
- exact coordinates when precision is sensitive or unpublished
- raw photo paths or private storage links
- records without permission to publish

## Example Files

- `data/field-microscopy-intake.example.json`: private intake example shape
- `data/reviewed-field-observations.json`: public-safe reviewed export placeholder
- `scripts/new-field-microscopy-intake.ps1`: creates an ignored local intake file
- `scripts/validate-field-microscopy-intake.ps1`: validates private intake records before export
- `scripts/export-reviewed-field-observations.ps1`: exports only approved-public, permissioned records
- `scripts/check-field-microscopy-review-cycle.ps1`: runs a synthetic review-cycle smoke check without leaving test files behind
- `scripts/field_microscopy_db.py`: manages the local SQLite review store and sanitized public export
- `docs/private-sqlite-surface.md`: documents the SQLite private surface
- `../environmental-monitoring-schemas/src/environmental_monitoring_schemas/field_microscopy.py`: reusable schema and validation package module
- `docs/reusable-schema-package.md`: documents the package boundary and current public API

## Current Implementation Choice

The first implementation now uses a local SQLite review store, with local JSON files kept as import/export and inspection helpers. Shared review rules live in a reusable local Python package so related monitoring projects can eventually use the same schema boundary.

Other possible surfaces remain future choices:

- SQLite-backed local review tool
- authenticated private web surface

## Next Decision Point

After one real or representative SQLite review cycle in another project, revisit whether the sibling schema repository should be published for broader reuse. For now, it stays private.
