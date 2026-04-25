# Lake County GIS Permission Request Draft

## Purpose

This is a draft message for requesting written clarification from Lake County GIS staff before using county-derived shoreline geometry in the public Clear Lake Watch dashboard.

The goal is to confirm whether derived geometry from the Lake County GIS `WaterFeatures` layer may be redistributed as public dashboard JSON, and what attribution or disclaimer language should be used if permission is granted.

## Suggested Subject

Request for public-use clarification: Lake County GIS WaterFeatures shoreline geometry

## Draft Message

Hello Lake County GIS team,

My name is Corey, and I am an Environmental Science student working on a public, noncommercial environmental information dashboard called Clear Lake Watch.

The project uses public environmental data sources to help communicate Clear Lake conditions with conservative methodology notes and clear disclaimers that it is not official public-health guidance.

I am reviewing whether the dashboard can use Lake County GIS shoreline geometry for Clear Lake instead of the current OpenStreetMap-derived shoreline. The candidate geometry comes from the Lake County GIS `WaterFeatures` / `Water Bodies` layer, specifically the `Clear Lake` polygon. The public ArcGIS REST service describes the layer as creeks and lakes in Lake County, CA, originally derived from USGS 7.5 minute topo maps and updated with 2016 LiDAR data.

Before publishing anything derived from the county layer, I wanted to ask for written clarification on the appropriate public-use terms.

Would Lake County permit a public, noncommercial environmental dashboard to redistribute a simplified derivative of the Clear Lake shoreline geometry as static JSON for map display?

If yes, could you please confirm:

- required attribution text
- any disclaimer language that should appear near the map or in the methodology/source notes
- whether linking to the Lake County GIS portal and/or ArcGIS REST service is sufficient
- whether there are any restrictions on publishing simplified derived coordinates in a static website bundle
- whether the county prefers that projects link to the live REST service instead of redistributing derived geometry

The intended use is limited to geographic context for public environmental information. It would not be used for parcel boundaries, legal determinations, survey purposes, official advisories, or emergency/public-health guidance.

If permission is not appropriate, or if the county prefers that third-party projects not redistribute derived GIS coordinates, I will keep the county geometry as an internal comparison artifact and continue using a separately licensed public geometry source for the public dashboard.

Thank you for your time and for maintaining these public GIS resources.

Best,

Corey

## Notes To Keep With The Request

- Keep any county response with the project records.
- Do not promote the county geometry until permission or terms are explicit.
- If permission is granted, update:
  - `docs/county-gis-public-use-check.md`
  - `docs/source-audit.md`
  - dashboard attribution text
  - `scripts/refresh-county-shoreline-candidate.ps1` license fields
- If permission is denied or unclear, keep OpenStreetMap as the public geometry source.

## Current Conservative Position

Until Lake County provides clear terms or permission, the county GIS shoreline files should remain candidate-review artifacts only.
