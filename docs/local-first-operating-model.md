# Local-First Operating Model

Clear Lake Watch should treat the public dashboard as a reviewed publication mirror, not as the operational center of the monitoring system.

The operating path is:

```text
edge collection -> local processing -> local storage -> reviewed public export -> static public mirror
```

This keeps the project useful during outages, protects private review records, and keeps public claims tied to reviewed exports instead of raw feeds.

## Operating Tiers

### Edge Collection

Field-adjacent devices such as Raspberry Pi or ESP32 nodes may collect sensor readings, timestamp records, buffer data during outages, and run simple health checks.

Edge devices should favor rules, thresholds, and buffering before larger inference. Any edge-AI output is experimental until reviewed.

### Local Processing

A local hub should normalize records, run validation, manage review queues, and generate dashboard-ready JSON files.

Core functions must work without an LLM:

- ingest
- storage
- validation
- review workflow
- public export generation
- dashboard refresh
- basic alert checks

LLM or edge-AI tools may help draft summaries, support operators, or query reviewed local data, but they should not be required for core monitoring.

### Local Storage

Private and draft records live locally before review. Current local stores include:

- `data/private/site-review.local.sqlite`
- `data/private/field-microscopy.local.sqlite`

These stores can contain generated queues, draft records, reviewer notes, custody details, QA decisions, and publication permission fields. They are ignored local working files, not public dashboard inputs.

### Reviewed Public Export

The public mirror should consume only sanitized exports under `data/`.

Current reviewed or public-safe exports include:

- `data/site-review-summary.json`
- `data/reviewed-field-observations.json`
- `data/weather-context.json`

Private records may affect the public mirror only after review, publication permission, and private-field removal.

### Static Public Mirror

The static public mirror is the public communication layer. It should show current reviewed public data, source status, methodology, and conservative interpretation notes.

Do not connect the public dashboard directly to MQTT, local SQLite databases, Grafana, InfluxDB, local gateway APIs, private intake files, or unreviewed sensor streams.

## Domain Separation

The shared backbone can provide common infrastructure, but domain products should remain separate.

- Lake module: site registry, FHABS/USGS normalization, lake-specific validation, arm summaries, and public lake exports.
- Weather and soil module: station health, weather context, rainfall windows, wind context, and public-safe driver exports.
- Field/microscopy module: private intake, QA review, permission-to-publish decisions, and sanitized public field exports.
- Review-decision module: reusable subject-based review decisions for site registry, field records, and future QA workflows.

Weather context can help explain environmental drivers, but it should not be silently blended into lake-health measurements or public-health claims.

## Compute Guardrail

Use the smallest sufficient compute path:

1. thresholds and direct validation first
2. lightweight local summaries second
3. larger models only when they clearly improve review, querying, or interpretation

Any model-assisted output needs traceability: model name, version, input data window, timestamp, instruction or prompt set, and reviewer decision before it contributes to public material.
