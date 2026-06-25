# Sensor Data Contract

**Status:** planning contract for future reviewed sensor exports  
**Audience:** operators, gateway builders, reviewers, and future ingest developers

This contract defines the minimum JSON shape for a future Clear Lake Watch sensor observation record.

It is a planning contract only. It does not authorize live ingestion, automatic publication, or public-health claims.

## Required Fields

Each observation record must include:

- `observation_id`
- `sensor_id`
- `station_id`
- `observed_at`
- `received_at`
- `parameter`
- `value`
- `unit`
- `latitude`
- `longitude`
- `source`
- `quality_flag`
- `review_status`
- `notes`

## Field Definitions

| Field | Meaning |
| --- | --- |
| `observation_id` | Stable unique identifier for one observation event. |
| `sensor_id` | Approved sensor identifier. |
| `station_id` | Approved station or deployment identifier. |
| `observed_at` | When the environmental reading was observed. |
| `received_at` | When the system received the record. |
| `parameter` | Observed variable such as `water_temperature_c` or `dissolved_oxygen_mg_l`. |
| `value` | Numeric value for the observation. |
| `unit` | Unit string approved for the parameter. |
| `latitude` | Public-safe latitude for the station or sample location. |
| `longitude` | Public-safe longitude for the station or sample location. |
| `source` | Source family such as `example`, `gateway`, or `reviewed_export`. |
| `quality_flag` | Deterministic or reviewed quality state. |
| `review_status` | Current review state in the publication path. |
| `notes` | Plain-language explanation, limitation, or quarantine reason. |

## Allowed `quality_flag` Values

- `raw`
- `valid`
- `suspect`
- `invalid`
- `quarantined`

## Allowed `review_status` Values

- `unreviewed`
- `auto_checked`
- `human_review_required`
- `approved_for_internal_use`
- `approved_for_publication`
- `rejected`

## Contract Rules

- `observation_id` must be unique.
- `received_at` must not be earlier than `observed_at`.
- `quality_flag` and `review_status` must use only allowed values.
- Records marked `quarantined` or `rejected` must not be exported to the public mirror.
- `notes` should explain anything unusual, including example-only status.
- `source` should identify the source family without exposing private broker URLs or internal credentials.

## Example: Valid Internal Record

```json
{
  "observation_id": "example-clw-temp-20260625t154500z-001",
  "sensor_id": "temp-probe-demo-01",
  "station_id": "lakeport-demo-station",
  "observed_at": "2026-06-25T15:45:00Z",
  "received_at": "2026-06-25T15:45:07Z",
  "parameter": "water_temperature",
  "value": 21.4,
  "unit": "C",
  "latitude": 39.0422,
  "longitude": -122.9158,
  "source": "example",
  "quality_flag": "valid",
  "review_status": "approved_for_internal_use",
  "notes": "Example data for contract documentation only. Not a real field reading."
}
```

## Example: Quarantined Record

```json
{
  "observation_id": "example-clw-ph-20260625t154500z-999",
  "sensor_id": "unknown-sensor-demo",
  "station_id": "lakeport-demo-station",
  "observed_at": "2026-06-20T08:00:00Z",
  "received_at": "2026-06-25T15:45:07Z",
  "parameter": "ph",
  "value": 21.7,
  "unit": "pH",
  "latitude": 39.0422,
  "longitude": -122.9158,
  "source": "example",
  "quality_flag": "quarantined",
  "review_status": "human_review_required",
  "notes": "Example quarantined record. Unknown sensor ID and impossible pH value triggered quarantine."
}
```

## Public Boundary

Even a valid contract record is not automatically ready for public display. Public release still requires:

- provenance review
- freshness review
- uncertainty language
- approved publication status
- a reviewed public-safe export path
