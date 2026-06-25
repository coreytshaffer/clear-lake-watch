# MQTT Topic Conventions

**Status:** naming proposal only  
**Audience:** future gateway builders, local operators, and reviewers

This document proposes MQTT topic conventions for a future local-first sensor backbone. It does not implement a broker, client, gateway, or dashboard connection.

The point of these conventions is to keep identity, routing, and quarantine behavior understandable before any live ingestion exists.

## Proposed Topic Pattern

```text
clearlakewatch/sensors/{station_id}/{sensor_id}/observations
clearlakewatch/sensors/{station_id}/{sensor_id}/status
clearlakewatch/sensors/{station_id}/{sensor_id}/deadletter
```

## Naming Rules

### Station Naming

Use stable operator-readable station IDs.

Examples:

- `lakeport-demo-station`
- `oaks-arm-north-01`
- `lower-arm-shoreline-02`

Recommended rules:

- lowercase only
- hyphen-separated
- no spaces
- no private device serials in the station ID

### Sensor Naming

Use sensor IDs that describe the instrument role without exposing secrets.

Examples:

- `temp-probe-01`
- `do-sonde-01`
- `ph-probe-01`

Recommended rules:

- stable across normal restarts
- tied to inventory records
- changed if hardware identity changes materially

## Observation Messages

Topic:

```text
clearlakewatch/sensors/{station_id}/{sensor_id}/observations
```

Use this topic for structured observation payloads that match the planned sensor data contract.

Observation topics are still raw intake surfaces. Publishing to this topic does not imply:

- the value is valid
- the value is current enough for public interpretation
- the value is approved for publication

## Status Or Heartbeat Messages

Topic:

```text
clearlakewatch/sensors/{station_id}/{sensor_id}/status
```

Use this topic for:

- heartbeat signals
- battery or uptime state
- calibration-needed warnings
- offline or degraded health messages

Status messages help operators understand device state, but they should not become public lake-health signals.

## Dead-Letter Messages

Topic:

```text
clearlakewatch/sensors/{station_id}/{sensor_id}/deadletter
```

Use this topic for records that cannot safely enter normal validation or review flow.

Examples:

- broken payload
- missing required identifiers
- bad schema
- parse failure

Dead-letter topics are operational audit surfaces. They are not data products for the public mirror.

## Why Raw Readings Must Not Go Directly To Public Dashboards

Raw MQTT traffic is the wrong trust layer for public display because it can contain:

- stale messages
- duplicate observations
- impossible values
- unknown sensor IDs
- private infrastructure details
- temporary calibration failures

The public dashboard should consume only reviewed exports, not broker topics. MQTT is an internal transport layer, not a publication contract.

## Minimal Routing Model

Recommended routing path:

```text
observations -> intake validator -> internal review queue or quarantine
status -> operator diagnostics
deadletter -> audit and repair workflow
```

This keeps the backbone fail-closed. If validation or review fails, the data should stop before it reaches any public layer.
