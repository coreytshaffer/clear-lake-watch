# Shared Backbone Integration

Clear Lake Watch should remain a distinct lake-focused publication product while sharing infrastructure with the broader local resilience environmental monitoring platform.

The shared backbone is responsible for local-first collection, validation, review workflow support, status reporting, storage boundaries, and export generation. Clear Lake Watch is responsible for public interpretation, lake-specific methodology, source attribution, and the static public dashboard.

## Architecture Rule

Use one shared environmental monitoring backbone, but keep domain products separate.

- The backbone may provide config loading, status publishing, storage adapters, review queues, export helpers, and shared operator tooling.
- The weather and soil modules may provide local telemetry, station health, and contextual environmental drivers.
- The lake module may provide source adapters, site registry matching, private observation review, lake-specific validation, and public export generation.
- The Clear Lake Watch dashboard should read only reviewed, publication-safe JSON files from `data/`.

## Public And Private Surfaces

Clear Lake Watch is expected to grow into two surfaces:

- Public surface: static dashboard, methodology, source links, reviewed exports, and public interpretation notes.
- Private surface: authenticated observation intake, microscopy notes, draft records, QA flags, review decisions, and publish controls.

Private records should never flow directly into the public dashboard. The intended path is:

```text
private observation -> review queue -> approved + permissioned record -> sanitized public export -> static dashboard
```

The public export step should remove private fields such as collector identity, unpublished notes, raw QA comments, and any sensitive location precision that is not meant for public release.

## Publication Contract

The static dashboard should keep consuming generated JSON products rather than connecting directly to live brokers, private databases, or internal review tools.

Current public inputs include:

- `data/live.json`
- `data/sources.json`
- `data/sites.json`
- `data/site-review.json` (current QA artifact; migration candidate for the future private portal)
- `data/reports.json`
- `data/observations.json`
- `data/sites-normalized.json`
- `data/analytics.json`
- `data/lake-shoreline.json`

Future backbone-generated exports may add files such as:

- `data/weather-context.json`
- `data/reviewed-field-observations.json`
- `data/source-status.json`
- `data/snapshot-manifest.json`

Those additions should preserve the existing interpretation guardrails: observed data, reported events, derived analytics, weather context, and experimental model outputs must remain visibly distinct.

## Weather Context Contract

The first shared-backbone export should be a schema-governed `data/weather-context.json` file. Clear Lake Watch should treat it like any other normalized source file, not as a live dependency on MQTT, InfluxDB, Grafana, or a private gateway.

The detailed schema and public/private guardrails live in
`docs/weather-context-contract.md`. The example export lives at
`data/weather-context.example.json`.

Minimum public fields:

- `schemaVersion`
- `generatedAt`
- `sourceName`
- `machineReadableStatus`
- `staleAfterHours`
- `stations`
- `summaryCards`
- `contextWindows`
- `qualityNotes`

Station records should include:

- stable `stationId`
- display name
- latitude and longitude only if safe for publication
- observation timestamp
- public/private visibility flag
- station health label
- latest reviewed weather metrics with units

Useful metric fields include:

- air temperature in degrees C
- relative humidity in percent
- wind speed and direction
- recent rainfall totals
- pressure
- station battery or power status when safe to publish

Context windows should be explicit and derived, for example:

- last 24 hours rainfall
- last 72 hours rainfall
- current wind context for surface-scum movement
- heat-spell indicator
- cooling or storm passage note

The export should avoid raw private telemetry, exact home-network identifiers, unpublished station diagnostics, and unreviewed sensor records. If a weather value is stale, provisional, or missing, the JSON should say so directly.

## Weather And Soil Context

Weather and soil sensing should share the backbone but remain a separate domain from lake-health interpretation.

Weather can support Clear Lake Watch as contextual driver data, for example:

- recent rainfall and runoff windows
- wind and surface-scum movement context
- heat-spell or cooling-period indicators
- station health and local climate notes

Weather should not be silently blended into lake-health claims. Any cross-domain analytics should be labeled as derived or experimental until reviewed and validated.

## Edge AI And LLM Boundary

LLM or edge-AI capabilities should be assistive, not required for core monitoring.

Appropriate uses include:

- operator support
- natural-language querying of local data
- draft summaries for reviewer approval
- controlled experimental analyses over reviewed inputs

Core functions should continue without an LLM:

- ingest
- storage
- validation
- review workflow
- public export generation
- dashboard refresh

Any LLM-assisted output should log the model, prompt or instruction set, input data window, timestamp, and reviewer decision before it contributes to public-facing material.

## Site Review Privacy Boundary

`data/site-review.json` is currently useful as a transparent QA artifact because it documents unresolved arm assignments and match methods. As the project grows a private review surface, this file should be reclassified.

Near-term public-safe use:

- aggregate counts
- reviewed versus needs-review status
- match method summaries
- non-sensitive site IDs and public landmark names

Future private-only use:

- reviewer notes
- draft corrections
- uncertain coordinates
- private field observations
- unpublished QA decisions

The public dashboard can keep showing aggregate confidence badges while the detailed queue moves behind a private portal.

## Near-Term Integration Steps

1. Keep the current static Clear Lake Watch UI stable.
2. Document the JSON publication contract as the boundary between the backbone and dashboard.
3. Build or maintain an `env_monitor_lake` module that generates Clear Lake Watch-compatible public exports.
4. Add a smoke workflow that regenerates lake JSON outputs and then runs `scripts/validate-dashboard.ps1 -SkipHttp`.
5. Add weather context later as a separate export, not as a direct rewrite of lake metrics.

This structure keeps the system resilient and reusable while protecting the public dashboard from ambiguous or unreviewed data.
