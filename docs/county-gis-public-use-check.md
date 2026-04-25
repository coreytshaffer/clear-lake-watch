# Lake County GIS Public-Use Check

## Decision

Do not promote the Lake County GIS shoreline candidate into the public dashboard yet.

The county shoreline candidate is appropriate for internal visual review and source comparison, but the currently available evidence does not clearly establish publication rights for redistributing the derived coordinate data as public dashboard JSON.

This is a conservative project-trust decision, not a conclusion that the data cannot be used. It means the public-use status is unresolved.

## Source Being Reviewed

- Local dataset: `lake_county_public_gis_2026_04_21/extracted/waterfeatures/lakes.shp`
- Candidate feature: `Name = Clear Lake`
- Candidate generator: `scripts/refresh-county-shoreline-candidate.ps1`
- Candidate preview: `geometry-preview.html`
- Candidate outputs:
  - `data/lake-shoreline-county-candidate.json`
  - `data/lake-shoreline-county-simplified-25ft.json`
  - `data/lake-shoreline-county-simplified-50ft.json`

## Evidence Found

### Official county GIS page

Lake County's official GIS page links to the Lake County Map Viewer and GIS Portal. It describes the viewer as a way to check zoning, flood zone, soil type, natural hazards, and related mapped information.

Reference:
https://www.lakecountyca.gov/559/Maps-Geographic-Information-System-GIS

### Official WaterFeatures service

The public ArcGIS REST service for `WaterFeatures` describes the layer as creeks and lakes in Lake County, CA. The service states that it was originally derived from USGS 7.5 minute topo maps and later updated with 2016 LiDAR data. Its copyright text is `USGS; Lake County CA I.T. Dept`.

Reference:
https://gispublic.co.lake.ca.us/server/rest/services/WaterFeatures/MapServer

### Portal visibility

The Lake County ArcGIS portal is publicly visible, and the portal metadata reports public access. This supports using the service for inspection and public-reference context, but public visibility is not the same thing as an explicit reuse or redistribution license.

Reference:
https://gis.lakecountyca.gov/portal/sharing/portals/self

### Local shapefile metadata

The local `lakes.shp.xml` metadata says the dataset is for lakes and wider creeks and that it originated from USGS 7.5 minute quad maps with updates from 2016 LiDAR data.

However, the local metadata fields for access constraints and use constraints contain placeholder required text instead of actual legal terms. That means the local metadata does not provide a reliable publication clearance.

## Risk

Promoting the county candidate would put derived county coordinate data into `data/lake-shoreline.json`, which is part of the public static dashboard bundle. That would make the geometry easy to download and reuse.

Because the candidate generator creates dashboard JSON from the county source, this is more than simply linking to or viewing the county GIS service.

## Current Public Dashboard Position

Keep the existing OpenStreetMap-derived shoreline as the active public geometry because it has an explicit public attribution and license path already documented in the project.

Keep the Lake County GIS outputs as internal candidate-review artifacts until one of the following is true:

- Lake County publishes clear reuse terms for GIS data.
- Lake County GIS staff provide written permission or attribution requirements for public redistribution of derived shoreline JSON.
- A different public-domain or clearly licensed county/state/federal shoreline source is selected.

## Conditions For Promotion

Before promoting the county geometry, complete these checks:

1. Capture the authoritative public-use terms or written permission.
2. Update `scripts/refresh-county-shoreline-candidate.ps1` with the correct license and attribution fields.
3. Update `docs/source-audit.md` with the final public-use status.
4. Update dashboard attribution text so it no longer implies the shoreline is OpenStreetMap-derived.
5. Run `scripts/refresh-county-shoreline-candidate.ps1 -SimplifyToleranceFeet 25 -Promote`.
6. Run dashboard validation and browser smoke checks.

## Summary

The county shoreline candidate looks technically useful, but public-use verification is not strong enough yet.

Decision: keep reviewing, do not publish.
