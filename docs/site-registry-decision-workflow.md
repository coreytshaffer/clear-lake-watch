# Site Registry Decision Workflow

Status: public-safe QA workflow for Clear Lake Watch site-registry review.

Clear Lake Watch uses a starter site registry to keep FHABS landmarks, USGS stations, map markers, and lake-arm labels consistent enough for a public-data dashboard. The registry is a review aid. It is not an official source of public-health, recreation, emergency, regulatory, or navigation guidance.

## Decision Levels

| Status | Meaning | Public use |
|---|---|---|
| `reviewed-starter` | A starter assignment has enough stable public source support to be used as dashboard context. | Context only; not official guidance. |
| `needs-local-review` | The assignment is plausible but still needs local review, better source confirmation, or reviewer signoff. | Display with caution language. |
| `unmatched-review-needed` | The source record could not be confidently matched to a maintained registry site. | Do not use as a stable site assignment. |

## Review Actions

| Action | Use when | Publication boundary |
|---|---|---|
| `keep-needs-review` | Public evidence is plausible but not enough to promote the assignment. | Safe to summarize publicly. |
| `add-alias` | A spelling, landmark phrase, or alternate name can be linked to an existing site without changing the site meaning. | Review before publishing. |
| `create-site` | A source record appears to represent a distinct site not already in the registry. | Requires careful public/private review. |
| `promote-reviewed-local` | Named local review confirms the maintained site assignment and publication is permitted. | Do not use without evidence and permission. |

## Minimum Evidence for Promotion

A site should not move from `needs-local-review` to a reviewed status unless the review packet includes:

- the FHABS or USGS source record being checked,
- the maintained registry site being changed or confirmed,
- the reason the site name, coordinate, and arm assignment are appropriate,
- the reviewer or evidence source,
- permission to publish the decision summary,
- a note explaining what the assignment does and does not prove.

## Public-Safe Handling

- Keep private reviewer notes, field details, draft corrections, and unpublished decisions out of the public mirror.
- Preserve rows and markers when evidence is incomplete; do not hide uncertainty by deleting unresolved items.
- Keep `needs-local-review` when the best evidence is plausibility rather than confirmation.
- Do not treat FHABS report counts, site assignments, or arm labels as bloom intensity, recreation safety, or official advisory status.

## Current Public Review Pass

The current public-safe review pass is documented in [site-registry-trust-review-pass-001.md](site-registry-trust-review-pass-001.md).

The current medium-priority unresolved decision is documented in [site-registry-unresolved-decision.md](site-registry-unresolved-decision.md).
