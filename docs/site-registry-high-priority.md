# High-Priority Site Registry Review

Generated: 2026-04-22T21:28:38.5652936-07:00

This packet focuses only on high-priority current FHABS marker checks. It is designed for local review and should not be treated as certification by itself.

## Review Decision Rules

- Promote a site to `reviewed-local` only when the landmark, coordinates, lake arm, and match radius are locally reviewed.
- Add an alias only when the alternate landmark clearly refers to the same maintained site.
- Split a site when the source coordinate suggests a distinct landmark rather than a generic bay or community label.
- Preserve `needs-local-review` when the evidence is plausible but not locally certified.
- Do not use unresolved markers as public-health guidance or model training labels.

## High-Priority Items

### Jones bay

- Current site ID: `fhabs-jago-bay`
- Matched site name: Jago Bay
- Current arm: Lower Arm
- Assignment status: `needs-local-review`
- Match method: `proximity`
- Match distance: 0.03 km
- Report date: September 4, 2025
- Evidence note: Marker matched by coordinate proximity rather than a reviewed alias.
- Recommended action: Confirm whether this landmark should be added as an alias for the matched site.
- Source coordinate: [38.94865, -122.66005](https://www.openstreetmap.org/?mlat=38.94865&mlon=-122.66005#map=15/38.94865/-122.66005)
- Registry coordinate: [38.948856, -122.66023](https://www.openstreetmap.org/?mlat=38.948856&mlon=-122.66023#map=15/38.948856/-122.66023)

Review checklist:

- [ ] Confirm whether the FHABS landmark name is a known local landmark.
- [ ] Confirm whether the source coordinate falls in the expected lake arm.
- [ ] Decide whether to keep the existing site, add an alias, split into a new site, or leave unresolved.
- [ ] Record the evidence source or local-review note before changing `assignmentStatus`.

Decision:

- [ ] Keep `needs-local-review`
- [ ] Add alias to existing site
- [ ] Create separate registry site
- [ ] Promote to `reviewed-local` after evidence is recorded
