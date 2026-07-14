# County GIS Public-Use Check

Status: needs verification before public promotion.

This note is the publication gate for Lake County public GIS shoreline candidate files. It does not grant permission to redistribute county-derived coordinate JSON, replace the public dashboard shoreline, or describe the county candidates as approved public map geometry.

## Current Decision

- Keep the OpenStreetMap-derived `data/lake-shoreline.json` file as the public dashboard shoreline geometry.
- Keep the county-derived candidate JSON and geometry preview page in ignored local review storage under `data/private/county-gis/`.
- Treat `data/private/county-gis/lake-shoreline-county-candidate.json`, `data/private/county-gis/lake-shoreline-county-simplified-25ft.json`, and `data/private/county-gis/lake-shoreline-county-simplified-50ft.json` as local candidate-review artifacts only.
- Do not promote county-derived geometry into the public dashboard until reuse terms, required attribution, update cadence, and redistribution limits are confirmed.

## Verification Checklist

| Check | Current answer |
| --- | --- |
| Official dataset or service URL confirmed | needs verification |
| Terms allow redistribution of derived coordinate JSON | needs verification |
| Required attribution text confirmed | needs verification |
| Update cadence or source contact confirmed | needs verification |
| Public dashboard promotion decision | blocked |

## Publication Gate

Before any county-derived geometry replaces `data/lake-shoreline.json`, record:

- the official source URL used for the candidate export;
- the exact reuse or license language that allows publication of derived coordinate JSON;
- the attribution text that should appear in the dashboard, source audit, and data metadata;
- the refresh cadence or review schedule;
- the reason the county geometry improves reviewer trust enough to justify the change.

If those items cannot be verified, keep county-derived candidate JSON out of the public mirror and keep the OpenStreetMap shoreline as the public geometry source.

## Boundary

Public visibility of a GIS portal is not the same as permission to republish derived data. This check preserves the current public/private boundary: candidate geometry can support local visual review, but it should not become a public dashboard dependency until the source terms are clear.
