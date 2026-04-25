# Forecast Boundary

## Purpose

This document defines how future bloom-risk or arm-level forecast outputs must be handled in Clear Lake Watch.

Forecasting is a research and decision-support layer. It must never be presented as observed conditions, official advisory status, or public-health guidance.

## Current Status

Forecasting is not live.

The public dashboard currently shows observed and reported public-source data, reviewed context, and project roadmap information. Any forecasting content belongs on the project page until a reviewed forecast export exists and has been validated.

## Required Boundary

Future forecasts must remain:

- experimental
- source-dated
- model-versioned
- uncertainty-labeled
- separated from current observed conditions
- clearly disclaimed as not official public-health guidance

## Public Placement Rule

Forecast roadmap content may appear on `project.html`.

Forecast outputs must not appear in the current-conditions flow on `index.html` unless they are:

- generated from a documented forecast export contract
- explicitly labeled `Experimental`
- accompanied by model date, training window, input summary, uncertainty, and public-health disclaimer
- visually separated from observed reports, lab results, advisories, and hydrology context

## Required Forecast Output Metadata

Any future forecast export must include:

- `schemaVersion`
- `generatedAt`
- `modelName`
- `modelVersion`
- `modelRunDate`
- `trainingWindow`
- `forecastWindow`
- `inputSummary`
- `uncertaintySummary`
- `publicHealthDisclaimer`
- `outputs`

Each output record must include:

- `arm`
- `forecastDate`
- `severityClass`
- `confidence`
- `uncertainty`
- `explanation`
- `experimental`

## Required Disclaimer

Every public forecast surface must communicate:

> Experimental forecast only. Not official public-health guidance.

This can be adapted for tone, but the meaning must remain intact.

## Data Separation

Forecasts should be generated as a separate export family, not mixed into:

- `data/live.json`
- `data/reports.json`
- `data/observations.json`
- FHABS advisory records
- official source-status records

If a future public forecast export is added, use a distinct file such as:

- `data/forecast-output.example.json` for the contract example
- `data/forecast-output.json` only after reviewed model outputs exist

## Training Data Guardrail

Unreviewed field observations, unresolved site-registry assignments, draft reviewer notes, and private microscopy records must not be used as model labels or public forecast inputs.

## Summary

Forecasting can be part of the long-term Clear Lake Watch roadmap, but it must remain quarantined behind an experimental boundary until the data contracts, model validation, uncertainty language, and public interpretation rules are ready.
