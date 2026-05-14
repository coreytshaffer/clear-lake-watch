# Field And Microscopy Review Workflow

Status: public-safe design note. No public submission form is enabled.

Clear Lake Watch may eventually include reviewed field observations and freshwater microscopy records, but those records need custody, QA, permission-to-publish, and privacy review before any public export exists.

This workflow is for private review leading to a sanitized public snapshot. It is not public-health guidance, a bloom-severity estimate, a diagnostic lab result, or an open public reporting surface.

## Intake Boundary

Private intake records may include details that should not publish by default:

- collector name or contact details,
- reviewer identity or private QA notes,
- custody IDs and custody notes,
- raw field notes,
- raw photo paths, voucher links, or storage locations,
- exact coordinates or sensitive access points,
- unreviewed taxon identifications,
- records without permission to publish.

These fields may be useful for review, but they belong in private storage only.

## Required Private Intake Fields

Each private intake record should include:

| Field group | Required fields |
|---|---|
| Record identity | `recordId`, `schemaVersion`, `recordType`, `createdAt`, `updatedAt`, `createdBy` |
| Sample event | `sampleDateTime`, `collectorName`, `collectorOrganization`, `collectionProgram`, `custodyId`, `custodyNotes` |
| Location | `siteId`, `siteName`, `latitude`, `longitude`, `gpsPrecisionMeters`, `coordinateSource`, `lakeArm`, `locationPrivacyClass` |
| Sample metadata | `sampleType`, `collectionMethod`, `preservationMethod`, `fieldNotes` |
| Microscopy metadata | `microscopeMethod`, `magnification`, `preparationMethod`, `taxonName`, `taxonRank`, `identificationConfidence`, `abundanceEstimate`, `photoOrVoucherReference` |
| Review and publication | `qaStatus`, `qaReviewer`, `qaReviewedAt`, `qaNotes`, `permissionToPublish`, `publicLocationPrecision`, `publicSummary` |

## QA Statuses

Use only these statuses:

- `draft`
- `submitted`
- `needs-correction`
- `approved-private`
- `approved-public`
- `rejected`

Only `approved-public` records with `permissionToPublish: true` may enter `data/reviewed-field-observations.json`.

## Permission Rules

Public export is allowed only when all of the following are true:

- `qaStatus` is `approved-public`,
- `permissionToPublish` is `true`,
- location precision has been reviewed,
- sensitive coordinates are generalized or removed,
- collector and reviewer private details are removed,
- raw photo paths, custody notes, and private QA notes are removed,
- the public summary explains limitations without implying official guidance.

`approved-private` means a record may be useful internally but is not cleared for publication.

## Allowed Public Export

`data/reviewed-field-observations.json` may include:

- stable public record ID,
- source family `field-microscopy`,
- generalized site label or public site ID,
- public lake arm when reviewed,
- sample date or date range,
- reviewed observation type,
- publishable taxon name and rank,
- identification confidence,
- abundance estimate or category,
- public QA status,
- public summary,
- limitation and separation notes.

It must not include:

- private collector contact details,
- private reviewer notes,
- custody notes,
- raw photo paths or private storage links,
- exact coordinates unless specifically approved for public release,
- unreviewed records,
- public-health, diagnostic, advisory, or forecast labels.

## Review Steps

1. Create or receive a private intake record.
2. Validate required fields and allowed QA status.
3. Review custody, location precision, and permission-to-publish.
4. Review microscopy identification confidence and public wording.
5. Decide one of: hold private, request correction, reject, or approve public.
6. Export only sanitized `approved-public` records with permission.
7. Run the public mirror validator before publication.

## Current Public Export State

The current public export is `not-connected` with no records. That is the correct state until a real or representative record completes private review and is explicitly cleared for public release.

## Future Implementation Boundary

Do not create an open public submission form in this project stage. If intake tooling is added later, it should be private, authenticated or local-first, and designed to fail closed.
