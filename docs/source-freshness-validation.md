# Source Freshness Validation

Status: public-safe validation note for the Clear Lake Watch public mirror.

Clear Lake Watch publishes a static public-data snapshot. The validation layer checks whether the snapshot files, source-status manifest, source observation dates, and output record counts still agree before publication.

This is not live monitoring, operational alerting, public-health guidance, recreation guidance, or emergency guidance.

## What The Validator Checks

- `data/manifest.json` has a parseable `generatedAt`.
- `data/live.json` and manifest `generatedAt` values are from the same refresh pass.
- Expected public sources are present:
  - USGS Lakeport lake level
  - USGS Cole Creek discharge
  - FHABS bloom reports
  - FHABS lab results
- Source `status`, `rowCount`, and `latestObservationDate` are present and internally consistent.
- FHABS source entries include positive Clear Lake row counts.
- Expected public outputs are listed in the manifest.
- Manifest output `recordCount` values match the generated public files where the count can be computed.
- Manifest notes preserve the distinction between dashboard refresh time and source observation dates.

## Warning Versus Failure

The validator fails when files are missing, JSON is invalid, expected sources or outputs are absent, record counts disagree, dates cannot be parsed, or an output appears to come from a different refresh pass.

The validator warns when a source observation date is older than the manifest freshness threshold. That warning is intentional: some public sources, especially lab-linked FHABS result records, may lag the dashboard generation date. A warning means the stale-source language must remain visible; it does not mean current conditions are known.

## Publication Boundary

Passing validation only means the public mirror is internally consistent enough to review. It does not prove current lake conditions, official advisory status, bloom severity, toxin risk, or sensor deployment.
