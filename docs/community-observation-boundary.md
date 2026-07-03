# Community Observation Boundary

Status: design position for the Clear Lake Watch public mirror. This is a boundary declaration, not implemented intake.

Clear Lake Watch is a late prototype / early MVP. It is not official public-health guidance, an official advisory, a validated forecast, or a deployed sensor network.

## What Exists Today

Nothing in this document is implemented. As of this note:

- There is no public submission form.
- There is no community photo or video intake pipeline.
- There is no camera, webcam, or social-media ingestion of any kind.
- There is no image-processing, feature-extraction, or computer-vision code in this repository.
- The only reviewed community-adjacent surface is the field/microscopy placeholder export (`data/reviewed-field-observations.json`), which is governed by its own contract and review workflow.

This document exists so that, if community visual observations are ever considered, the boundary is decided before any code is written — not retrofitted afterward.

## Boundary Statements

If community-submitted or publicly visible imagery is ever used, the following rules apply from the first prototype onward:

1. **Observations, not people.** Clear Lake Watch records environmental observations about lake and watershed conditions. It must not identify, track, profile, or publish information about people, vehicles, boats, homes, or private activity.
2. **Leads, not evidence.** A publicly visible social-media post is a lead, not an ingestible observation. It may prompt a request for permission or independent verification; it may not be scraped, stored, or republished.
3. **Publicly viewable is not reusable.** Visibility on a platform does not grant reuse rights. Ingestion requires direct submission, documented permission, or a compatible license, recorded per record.
4. **Visual signals are proxies.** A photo or camera frame can support wording like "possible surface scum" or "visual indicator." It cannot confirm toxin levels, species identification, water safety, or advisory status, and public wording must not imply that it can.
5. **Review before publication.** No community-derived record reaches the public mirror without human review, an explicit publication decision, and the same freshness, provenance, and non-advisory labeling the rest of the public snapshot uses.
6. **Fail closed on ambiguity.** Missing time, missing location, unclear permission, identifiable people or private property, or an unverifiable claim means the record stays private, is quarantined, or is rejected — not published with caveats.

## Requirements Before Any Future Intake

Before any community-observation intake is built, the following must exist first, in this order:

1. A written submission and permission model (who submits, what consent options exist, what license terms apply).
2. A privacy review step covering identifiable people, vehicles, private property, and sensitive locations, with masking or rejection as the default.
3. A claim-tier vocabulary so public wording is limited to what the evidence supports.
4. Validator coverage extending the existing public/private boundary checks to any new record types before they are tracked in the public mirror.
5. A retention decision for raw versus derived material.

Until all of these exist, community imagery stays out of scope entirely.

## Non-Claims

- This document does not announce, authorize, or schedule a community-submission feature.
- It does not make Clear Lake Watch a surveillance, incident-reporting, or enforcement system, and the project must never become one.
- It does not change the existing public/private boundary, the publication review checklist, or the non-advisory posture of the public mirror.
- Official agency and Tribal monitoring programs remain the authoritative sources for lake conditions and advisories.
