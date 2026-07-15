# Clear Lake Watch - Agent Instructions

Welcome, coding agents and contributors! Clear Lake Watch is a public environmental monitoring dashboard for Clear Lake, CA. It integrates public environmental data and uses cautious boundary language.

**Purpose:**
It organizes Clear Lake environmental context, source freshness, map review status, and cautious methodology notes.
It must not present itself as official public-health guidance, emergency guidance, a validated forecast, or a deployed sensor network.

**Safe to Edit:**
- UI components, HTML structure, and CSS styling (without changing the meaning of the data or boundary language).
- Documentation (clarifications, typo fixes).
- Validation scripts and helpers (e.g., `scripts/validate-public-mirror.py`).

**Do NOT Change Casually:**
- Environmental data values (e.g., files under `data/`).
- FHABS, USGS, OpenStreetMap, or source-status claims.
- Site arm assignments or local-review statuses.
- Map logic or dashboard behavior related to data interpretation.

**Public-Safety Boundary Language:**
You must preserve the following boundaries and wording:
- The dashboard is a "late prototype / early MVP".
- It is "not official public-health guidance", "not an official advisory", "not emergency guidance", "not a validated forecast", and "not a deployed sensor network".
- Weather context is a "reviewed public-source snapshot" and remains "separate from lake-health interpretation".

**Validation Commands:**
Before proposing any changes, you must run the validation checks:
- Existing PowerShell validation (if supported): `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-public-mirror.ps1`
- Python cross-platform validation: `python scripts/validate-public-mirror.py`

**Strict Warnings:**
- Do NOT invent data, advisory language, site-review status, weather telemetry, forecasts, or health guidance.
- Do NOT change environmental data values.
- Do NOT restyle the dashboard beyond tiny documentation links if needed.
- Do NOT add public-health, recreation, regulatory, emergency, or forecast guidance.
