# Field Sensor Readiness Packet

**Status:** planning and governance artifact  
**Audience:** operators, reviewers, collaborators, and future field-monitoring contributors  
**Prepared:** 2026-06-25

Clear Lake Watch is a late prototype / early MVP. It is not official public-health guidance, an official advisory, recreation guidance, emergency guidance, a validated forecast, a deployed sensor network, or a live ingestion platform.

This packet defines what future field sensor data would need before it could support Clear Lake Watch or any related public environmental reporting. It is documentation-first on purpose. The goal is to make future sensor work governable before it becomes functional.

## Purpose

- Define the minimum trust boundaries for future sensor observations.
- Separate raw telemetry from validated and publishable environmental records.
- Preserve provenance, freshness, uncertainty, and reviewability.
- Keep the public dashboard fail-closed unless reviewed exports are ready.

## Relationship To Clear Lake Watch

Clear Lake Watch is the reviewed publication mirror, not the operational sensor backbone.

The intended operating path remains:

```text
sensor or field device -> local gateway -> intake validation -> review or quarantine -> reviewed export -> static public mirror
```

This packet does not authorize direct sensor-to-dashboard publishing. A sensor reading is not automatically environmental truth. It must pass validation, provenance, freshness, and review checks before public display.

## Data Lifecycle

### 1. Raw Observation

A raw observation is the first structured record received from a device or gateway.

Properties:

- may contain transport errors or stale timestamps
- may have bad units or impossible values
- may come from an unknown or misconfigured sensor
- is not publishable

### 2. Auto-Checked Observation

An auto-checked observation passed deterministic checks such as:

- required fields present
- timestamp parseable
- sensor and station IDs known
- coordinates within expected bounds
- parameter and unit pair allowed
- value inside instrument or domain sanity ranges

Auto-checked is still not public approval.

### 3. Human-Review Observation

Some records require a reviewer before any downstream use.

Examples:

- borderline but not impossible value
- stale reading that may still matter for internal diagnostics
- duplicate event with inconsistent metadata
- changed sensor calibration status
- station relocation or coordinate drift

### 4. Reviewed Internal Observation

A reviewed internal observation may support local analysis, QA checks, or operator dashboards, but it still does not automatically belong on the public mirror.

### 5. Approved Public Observation

A public observation must:

- have clear provenance
- have valid or explicitly reviewed quality status
- have acceptable freshness for its intended use
- avoid private fields
- avoid overstating scientific certainty
- fit a reviewed public-safe export contract

## Raw Vs Validated Vs Publishable

| State | Meaning | Public use |
| --- | --- | --- |
| Raw | Received but not trusted yet | Never publish |
| Validated | Deterministic checks passed | Internal only unless reviewed |
| Publishable | Reviewed, bounded, provenance-clear, and contract-compliant | May enter a reviewed public export |

## Freshness Boundaries

Future sensor work must keep the same distinction already used in Clear Lake Watch:

- resource freshness: whether the export or message bundle is recent enough to trust as an intake artifact
- observation freshness: when the environmental reading was actually observed

A recent file or recent MQTT delivery does not make an old reading current. A fresh observation in a delayed export is also not the same thing as live public monitoring. Both timestamps must remain visible to operators.

## QA/QC Gates

Minimum deterministic gates before internal use:

- observation ID is unique
- sensor ID is known
- station ID is known
- `observed_at` and `received_at` are parseable
- `received_at` is not earlier than `observed_at`
- parameter is from an approved list
- unit matches the parameter contract
- coordinates are present and plausible for the intended station
- value is within parameter sanity limits
- review status starts in a non-public state

Recommended parameter sanity examples:

- water temperature should not be below freezing for an unfrozen lake sample without explanation
- dissolved oxygen should not be negative
- pH should stay within physically plausible freshwater bounds
- conductivity should use an expected unit family such as `uS/cm`

## Quarantine Rules

A record should be quarantined when any of these occur:

- impossible value
- stale reading beyond the allowed observation window
- missing required timestamp
- invalid unit
- unknown sensor or station
- coordinates outside the approved region
- duplicate observation ID
- broken JSON or missing required field

Quarantined records stay out of reviewed exports and should move to a quarantine queue or dead-letter path with a machine-readable reason plus an operator-facing note.

## Dead-Letter Handling

Dead-letter handling is for records that cannot be trusted enough even for normal review flow.

Use dead-letter handling when:

- parsing fails
- schema is broken
- required identity fields are missing
- the message cannot be associated with a known source

Dead-letter storage should preserve:

- raw payload or a safe copy
- receipt timestamp
- parser or validation error
- gateway or intake identifier

Dead-letter handling is an operations and audit surface, not a public data surface.

## Human Review Requirements

Human review should be required when:

- values are suspect but not clearly invalid
- a sensor recently changed calibration or firmware
- publication wording could imply public-health authority
- a record would become the newest public observation for a station or parameter
- a station location or label changed
- a bulk replay or outage-recovery import occurred

Review questions:

1. Does the record look physically plausible?
2. Is the provenance clear enough to trust the source path?
3. Is the freshness acceptable for the claimed use?
4. Does the export remove private or sensitive fields?
5. Would public display risk overstating certainty or recency?

## Minimal Viable Deployment Path

Keep the first deployment path small:

1. one station naming convention
2. one or two low-risk parameters such as water temperature or air temperature
3. deterministic intake validator
4. quarantine and dead-letter outputs
5. reviewed JSON export for internal use
6. only later, a reviewed public-safe export if the trust contract holds

This packet does not authorize direct dashboard integration. The first credible milestone is a reviewed internal export path that proves fail-closed behavior.

## Known Limitations

- This packet does not implement MQTT, ingestion, storage, or review tools.
- It does not prove any deployed sensor exists.
- It does not define calibration SOPs in full detail.
- It does not authorize public-health, recreation, or toxin-risk claims.
- It does not replace mentor, lab, or agency review for sensitive variables.

## Practical Boundary

If future sensor work becomes convenient before it becomes reviewable, the project will mislead people. Clear Lake Watch should accept that some data stays private, stale, or quarantined rather than pretending raw telemetry is trustworthy enough for public interpretation.
