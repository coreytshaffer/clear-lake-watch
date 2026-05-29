# Source Audit

This note captures the first pass on public data sources for the Clear Lake dashboard.

## Verified source families

### Lake County CLAMP

- Public landing page: `https://lakecountyca.gov/1504/Clear-Lake-Water-Quality`
- Role: Core arm-level water quality trends
- Notes:
  - Lake County describes CLAMP as monthly physical, chemical, and biological monitoring across the three lake arms.
  - The same page points users to the county ArcGIS hub and to CEDEN.
  - Best first ingestion path is probably through CEDEN or downloadable extracts instead of scraping the public page.

### Big Valley Band of Pomo Indians Cyanotoxin Monitoring

- Public landing page: `https://www.bvrancheria.com/clearlakecyanotoxins`
- Historical page: `https://www.bvrancheria.com/historical-cyanotoxin-data`
- Role: High-value cyanotoxin and shoreline risk signal
- Notes:
  - The site states summer sampling occurs every two weeks and covers more than 20 sites.
  - Historical material from 2014-2024 is publicly visible.
  - Expect custom extraction or a direct data-sharing conversation to make this robust.

### California FHABS

- Public landing page: `https://mywaterquality.ca.gov/habs/resources/reports-map/`
- Open data dataset: `https://lab.data.ca.gov/dataset/surface-water-freshwater-harmful-algal-blooms`
- Role: Advisory and incident history
- Notes:
  - The map page points users to California Open Data for full downloads.
  - This looks like the best statewide advisory-history source.
  - `scripts/refresh-live-data.ps1` resolves FHABS resources dynamically from California Open Data package metadata instead of pinning dated CSV download URLs.
  - The refresh writes normalized `reports.json`, `observations.json`, `analytics.json`, and `manifest.json` outputs.
  - Resource freshness checks should remain in place so a successful refresh cannot silently publish stale dated FHABS inputs.

### California Satellite HAB Map

- Public page: `https://mywaterquality.ca.gov/habs/resources/satellite-map.html`
- Role: Spatial context between in-water measurements
- Notes:
  - The state describes the layer as estimated cyanobacteria and chlorophyll-a based on satellite imagery.
  - The same page warns against using the map alone for regulatory or advisory decisions.
  - This should remain a clearly labeled supplemental layer.

### USGS Clear Lake Tributaries And Lake Monitoring

- Public viewer: `https://www.usgs.gov/tools/watershed-monitoring-clear-lake-tributaries`
- Role: Lake-level and watershed-driver context
- Notes:
  - This is the most promising early automation target because USGS services are designed for machine access.
  - The new USGS pages are not especially helpful as HTML scrape targets, so we should work from raw services.
  - The Lakeport lake-level card displays USGS gage height as feet Rumsey and includes approximate water-surface elevation using Zero Rumsey = 1318.256 ft above mean sea level.

### CEDEN Chemistry Data

- Open data landing page: `https://lab.data.ca.gov/dataset/surface-water-chemistry-results`
- Role: Historical chemistry backfill and QA
- Notes:
  - Good long-run storage format for the dashboard warehouse.
  - We will need a clean parameter mapping layer because the schema is broad.

### OpenStreetMap Shoreline Geometry

- Public relation: `https://www.openstreetmap.org/relation/4046481`
- Role: Public geographic context for the Clear Lake shoreline overlay
- Notes:
  - Used only for map geometry and geographic context, not as a water-quality or advisory source.
  - The dashboard caches the relation into `data/lake-shoreline.json` using `scripts/refresh-osm-shoreline.ps1`.
  - Attribution and ODbL license links should remain visible wherever the OSM-derived shoreline is displayed.

### Public Gazetteer / Topo Cross-Checks For Site Registry Review

- Example references used during review:
  - `https://california.hometownlocator.com/maps/feature-map,ftc,1,fid,226330,n,jones%20bay.cfm`
  - `https://california.hometownlocator.com/maps/feature-map,ftc,1,fid,226113,n,jago%20bay.cfm`
- Role: Public geographic naming context for site-registry review only
- Notes:
  - Public gazetteer/topo references can help distinguish whether two FHABS landmark names appear to refer to separate named bays.
  - These references are useful for conservative registry maintenance, not for water-quality interpretation or public-health messaging.
  - The Jones Bay / Jago Bay split should remain `needs-local-review` until local evidence confirms the maintained registry coordinates and match radii.

### Lake County Public GIS Shoreline Candidate

- Local source: Lake County public GIS `waterfeatures/lakes` layer
- Role: Candidate replacement geometry for the Clear Lake shoreline overlay
- Public-use check: [County GIS Public-Use Check](county-gis-public-use-check.md)
- Local private review files:
  - `data/private/county-gis/lake-shoreline-county-candidate.json`
  - `data/private/county-gis/lake-shoreline-county-simplified-25ft.json`
  - `data/private/county-gis/lake-shoreline-county-simplified-50ft.json`
  - `data/private/county-gis/geometry-preview.html`
- Current status: Candidate review only; moved out of the public mirror until source terms are verified.
- Notes:
  - The county layer contains a `Clear Lake` polygon feature and appears to provide a more locally authoritative geometry source than OSM.
  - The raw county export is too large for the public dashboard without simplification.
  - The 25 ft simplified candidate is close to the current OSM payload size while preserving county geometry.
  - Public promotion should wait until attribution and publication terms are confirmed; public visibility of the GIS portal is not enough by itself to justify redistributing derived coordinate JSON.
  - Use the local private geometry preview for visual comparison before replacing `data/lake-shoreline.json`.

### Future Field And Microscopy Intake

- Contract: `docs/field-microscopy-intake-contract.md`
- Private surface boundary: `docs/private-surface.md`
- SQLite private surface: `docs/private-sqlite-surface.md`
- Reusable schema package: `docs/reusable-schema-package.md`
- Example private intake shape: `data/field-microscopy-intake.example.json`
- Public-safe reviewed export: `data/reviewed-field-observations.json`
- Role: Reviewed local observations, sample metadata, and phytoplankton identifications
- Status: SQLite-backed local private surface started; not a public feed yet
- Notes:
  - Intended for lakeside observations and freshwater phytoplankton sampling/identification by light microscope, including work collected on behalf of NOAA when appropriate.
  - The first implementation is an ignored local SQLite review store with a sanitized public export, not an open public submission form.
  - Shared field/microscopy review rules live in `../environmental-monitoring-schemas/src/environmental_monitoring_schemas/field_microscopy.py`.
  - The review-cycle smoke check creates a temporary synthetic approved-public record and confirms private fields are excluded from the export.
  - Records need explicit metadata for sample custody, site precision, microscope method, taxonomic confidence, reviewer, and permission to publish.
  - Approved records should be tagged as a separate field/microscopy source family so they are not confused with FHABS, CLAMP, Tribal, USGS, CEDEN, or official advisory data.
  - Private intake files should exclude unreviewed records from public exports and model training until QA status and publication permission are explicit.

### Shared Backbone Weather Context Export

- Public contract: `docs/weather-context-contract.md`
- Public status file: `data/weather-context.json`
- Example export: `data/weather-context.example.json`
- Role: Driver/context information from the separate environmental monitoring backbone
- Current status: Public-safe unavailable status export is implemented; live weather export is pending field telemetry proof
- Notes:
  - Weather context should remain separate from lake-health interpretation.
  - The public dashboard should consume a reviewed JSON export, not private MQTT, Grafana, InfluxDB, or gateway internals.
  - Quality notes must preserve the boundary that weather context is not public-health guidance.

## Suggested first ETL order

1. USGS hydrology and lake-level drivers already power the current public snapshot path.
2. FHABS open-data extracts already power the current public snapshot path and should continue to use dynamic resource resolution.
3. CEDEN chemistry backfill for selected parameters
4. CLAMP arm-level extracts
5. Tribal cyanotoxin integration
6. Satellite layers
7. Reviewed field and microscopy intake
8. Shared backbone weather context after live weather telemetry is proven
9. OSM shoreline refresh when the map geometry needs updating

## Definition work before forecasting

Before building a bloom model, define:

- the arm mapping for each site
- the severity label
- the prediction cadence
- the distinction between observed conditions and predicted outlooks
