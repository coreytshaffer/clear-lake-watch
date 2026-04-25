# Site Registry Review

Generated: 2026-04-22T21:28:38.5652936-07:00

This file is a review queue for stable site IDs and arm assignments. It does not certify locations as authoritative; it identifies what still needs local review.

## Summary

- Registry sites: 10
- Reviewed registry sites: 2
- Registry sites needing review: 8
- Current mapped markers: 8
- Current mapped markers needing review: 8
- High-priority review items: 1
- Medium-priority review items: 3
- Low-priority review items: 4

## Current Marker Review Queue

| Priority | Site | Landmark | Arm | Status | Match | Distance | Report date | Evidence note | Review action |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| high | Jago Bay | Jones bay | Lower Arm | needs-local-review | proximity | 0.03 km | September 4, 2025 | Marker matched by coordinate proximity rather than a reviewed alias. | Confirm whether this landmark should be added as an alias for the matched site. |
| medium | Clear Lake Keys | Clear Lake Keys near Ketch Court | Oaks Arm | needs-local-review | alias | 1.12 km | June 26, 2025 | Alias matched, but the source coordinate is offset from the registry point. | Confirm the source coordinate, landmark, arm assignment, and match radius. |
| medium | Jago Bay | Jago Bay | Lower Arm | needs-local-review | alias | 0.7 km | July 31, 2025 | Alias matched, but the source coordinate is offset from the registry point. | Confirm the source coordinate, landmark, arm assignment, and match radius. |
| medium | Soda Bay | Soda Bay | Lower Arm | needs-local-review | alias | 1.14 km | September 7, 2025 | Alias matched, but the source coordinate is offset from the registry point. | Confirm the source coordinate, landmark, arm assignment, and match radius. |
| low | Clearlake Oaks | Clearlake Oaks west of Blue Heron Ct. | Oaks Arm | needs-local-review | alias | 0 km | June 15, 2025 | Alias and coordinates are close, but local review has not certified the assignment. | Confirm local landmark and arm assignment, then promote only if locally reviewed. |
| low | Henderson Point / Riviera Point Launch | Riveria Point Launch at Henderson Point in Soda Bay | Lower Arm | needs-local-review | alias | 0 km | June 10, 2025 | Alias and coordinates are close, but local review has not certified the assignment. | Confirm local landmark and arm assignment, then promote only if locally reviewed. |
| low | Konocti Shores | Konocti Shores | Lower Arm | needs-local-review | alias | 0 km | June 14, 2025 | Alias and coordinates are close, but local review has not certified the assignment. | Confirm local landmark and arm assignment, then promote only if locally reviewed. |
| low | Wheeler Point | Wheeler Point, Kelseyville | Lower Arm | needs-local-review | alias | 0 km | July 24, 2025 | Alias and coordinates are close, but local review has not certified the assignment. | Confirm local landmark and arm assignment, then promote only if locally reviewed. |

## Review Notes

- Keep stable `siteId` values once created.
- Use `reviewed-local` only after local landmark and arm assignment review.
- Preserve `needs-local-review` when the assignment is plausible but not verified.
- Preserve `unmatched-review-needed` when no stable site can be selected.
- Do not use unresolved sites as authoritative labels for public-health interpretation or model targets.