# Site Registry Location Verification

Verified: 2026-05-05

This note records public location evidence for the current medium-priority site-registry review items. It is not a local certification of lake-arm assignments, public-health status, or site suitability for model training.

## Sources Used

- USGS / The National Map Gazetteer / GNIS ArcGIS REST service for federally recognized geographic names and coordinates.
- OpenStreetMap Nominatim for road/place lookup where GNIS does not cover road names.
- Current Clear Lake Watch generated review queue in `data/site-review.json`.

## Summary

| FHABS landmark | Current registry site | Public evidence result | Recommendation |
| --- | --- | --- | --- |
| Clear Lake Keys near Ketch Court | `fhabs-clearlake-keys` | Ketch Court is publicly locatable inside Clear Lake Keys and is very close to the FHABS coordinate. | Keep unresolved until deciding whether to create a specific `Clear Lake Keys near Ketch Court` registry site or move the maintained Clear Lake Keys point closer to the source landmark. |
| Jago Bay | `fhabs-jago-bay` | Jago Bay is a GNIS bay in Lake County. The FHABS coordinate is closer to the GNIS bay point than the current registry point is. | Keep unresolved; consider updating the maintained Jago Bay coordinate toward the GNIS/source location after local review. |
| Soda Bay | `fhabs-soda-bay` | Soda Bay is a GNIS bay and also a populated/CDP area. The current registry point is close to the GNIS bay point, while the FHABS coordinate is farther west/northwest but still within the broad registry radius. | Keep unresolved; do not promote without local review because "Soda Bay" may refer to a broad area rather than one precise monitoring point. |

## Policy Decision

Decision recorded: 2026-05-05

Keep these medium-priority FHABS matches attached to broad place-based registry entries for now. Do not create more specific source-landmark sites, move maintained coordinates, or promote the records to `reviewed-local` without stronger verifiable location evidence or local review.

Reason:

- broad place entries are simpler to maintain at this maturity level
- they avoid implying a precise monitoring location when the public evidence does not fully support that claim
- `needs-local-review` keeps the uncertainty visible without breaking the public dashboard

## Distance Check

Distances are approximate great-circle distances in kilometers.

| FHABS landmark | Source to current registry | Source to public evidence point | Registry to public evidence point |
| --- | ---: | ---: | ---: |
| Clear Lake Keys near Ketch Court | 1.12 km | 0.07 km | 1.07 km |
| Jago Bay | 0.70 km | 0.40 km | 1.09 km |
| Soda Bay | 1.14 km | 1.29 km | 0.52 km |

## Item Notes

### Clear Lake Keys Near Ketch Court

Current FHABS source coordinate:

- `39.017986, -122.661230`

Current registry coordinate for `fhabs-clearlake-keys`:

- `39.0239133, -122.6717500`

Public evidence:

- GNIS / Gazetteer has `Clear Lake Keys` as a populated place in Lake County at approximately `39.0207337, -122.6624989`.
- OpenStreetMap Nominatim resolves `Ketch Court, Clearlake Oaks, CA` to a residential road in Clear Lake Keys at approximately `39.0179890, -122.6620025`.

Interpretation:

The FHABS coordinate is very close to the public Ketch Court road location, so the source landmark appears plausible. The current registry point appears to represent a broader Clear Lake Keys maintained point rather than the Ketch Court-specific landmark.

Conservative action:

Keep `fhabs-clearlake-keys` as `needs-local-review` until deciding whether to:

- keep one broad Clear Lake Keys registry entry,
- move the maintained point closer to the verified road/source coordinate, or
- create a more specific `Clear Lake Keys near Ketch Court` child/starter site.

### Jago Bay

Current FHABS source coordinate:

- `38.946382, -122.667660`

Current registry coordinate for `fhabs-jago-bay`:

- `38.948856, -122.660230`

Public evidence:

- GNIS / Gazetteer has `Jago Bay` as a bay in Lake County at approximately `38.9446255, -122.6716663`.

Interpretation:

The FHABS coordinate is closer to the GNIS Jago Bay point than the current registry coordinate is. This supports the landmark label as Jago Bay, but it also suggests the maintained registry coordinate may be too far east if it is meant to represent the bay rather than a broader or alternate local reference point.

Conservative action:

Keep `fhabs-jago-bay` as `needs-local-review`. A reasonable next review question is whether to update the maintained Jago Bay coordinate toward the GNIS/source location while preserving the current lake-arm assignment only after local review.

### Soda Bay

Current FHABS source coordinate:

- `39.010560, -122.806240`

Current registry coordinate for `fhabs-soda-bay`:

- `39.002800, -122.797700`

Public evidence:

- GNIS / Gazetteer has `Soda Bay` as a bay in Lake County at approximately `39.0054569, -122.7927823`.
- The Gazetteer also includes Soda Bay as a populated place / census-designated place, and OpenStreetMap shows a broader Soda Bay boundary and place record.

Interpretation:

The current registry point is reasonably close to the GNIS bay point. The FHABS coordinate is farther west/northwest but still within the broad `2.5 km` registry match radius. Because "Soda Bay" can refer to both the bay and the surrounding community/area, this should not be promoted as a precise locally reviewed site without human confirmation.

Conservative action:

Keep `fhabs-soda-bay` as `needs-local-review`. A reasonable next review question is whether this FHABS report should remain attached to a broad Soda Bay site, be split into a more specific local landmark, or keep the current broad assignment with a clearer public note.

## Next Decision Point

The next decision is operational rather than structural: keep using the broad unresolved registry entries until a local review pass can provide stronger evidence for any coordinate move, child/starter site, or `reviewed-local` promotion.
