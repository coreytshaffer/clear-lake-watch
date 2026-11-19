# Pinned public snapshot: May 5, 2026

Test fixture only. These files are not part of the published dashboard data.

`data/` holds byte-identical copies of `data/manifest.json` and its five outputs (`live.json`, `reports.json`, `observations.json`, `sites-normalized.json`, `analytics.json`) at commit `b6a8890`. The public-mirror validator tests replay them at a frozen clock, for example `2026-11-17T12:00:00Z`, which yields the three historical warnings: snapshot age of 196 Pacific calendar days and FHABS observation lags of 240 and 845 days.

`tests/public_mirror_fixtures.py` checks each file against its Git blob id before the tests run. Do not edit these files. A reviewed refresh of the live `data/` directory leaves them unchanged.

This is not live monitoring and not official public-health guidance.
