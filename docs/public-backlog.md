# Public Backlog

Status: completed trust-hardening, reviewer-readiness, and first maintenance-split passes.

Clear Lake Watch remains a late prototype / early MVP. It is not official public-health guidance, an official advisory, a validated forecast, or a deployed sensor network.

## Current Checkpoint

The first public-backlog pass is complete. The project now has a public mirror, source freshness cues, map-review transparency, public-safe weather context, private field/microscopy review boundaries, reviewer demo notes, a portfolio evidence index, a Career Services evidence summary, a Career Services handoff packet, a dashboard anatomy review guide, an accessibility review note, a browser accessibility interaction pass, refreshed reviewer screenshots for the current homepage, a mobile reviewer path review, an above-the-fold internship reviewer path, print-friendly public review output, an official method source spine for future protocols, a Secchi depth / clarity mentor-review protocol draft, and a Secchi mentor-review handoff packet.

The current follow-up posture is steady maintenance: keep the reviewer packet inspectable while avoiding unnecessary complexity and preserving the public-health, recreation, emergency, forecasting, and official-advisory boundaries.

## Latest Stabilization Note

The homepage now exposes the three-link internship reviewer path near the top of the public mirror, while the supporting reviewer section is framed as deeper review links. The stylesheet also includes print-friendly rules so a reviewer can print or save the public page without navigation, buttons, or map controls dominating the artifact.

This is a review-path improvement only. It does not add new monitoring data, public submission intake, field validation, advisory authority, or forecasting capability.

## Scientific Credibility Note

The official method source spine now identifies the Lake County Clear Lake QAPP, Lake County CLAMP/CEDEN context, EPA quality assurance guidance, EPA volunteer lake monitoring methods, EPA lake field operations manual, and related EPA field-method references as the first source anchors for future written protocols.

This is a source-selection improvement only. It does not approve field work, create a QAPP for Clear Lake Watch, validate measurements, or authorize public field data publication.

## Protocol Draft Note

The first source-anchored protocol draft is [Secchi depth / clarity mentor-review protocol](secchi-depth-clarity-mentor-review-protocol.md). It is marked `mentor-review-needed` and is only a review packet for future feedback.

This is a protocol-drafting improvement only. It does not authorize field work, create public field data, validate Secchi measurements, diagnose bloom conditions, estimate toxin risk, or support recreation-safety decisions.

Decision recorded: keep the Secchi protocol mentor-review-only for now. Do not advance it to a private pilot field-note protocol until mentor, faculty, or qualified technical feedback is available.

The Secchi mentor-review handoff packet now gives reviewers a short review path, exact feedback questions, a feedback capture template, and a suggested short message.

## Completed Public Trust-Hardening Issues

| Issue | Focus | Result |
| --- | --- | --- |
| [#5 Add current screenshot and static snapshot release note](https://github.com/coreytshaffer/clear-lake-watch/issues/5) | Portfolio/public review | Added a release note and public screenshot proof packet. |
| [#6 Review high-priority site-registry assignments](https://github.com/coreytshaffer/clear-lake-watch/issues/6) | Map trust | Documented a site-registry review pass and kept all current FHABS markers as `needs-local-review`. |
| [#7 Strengthen stale-source and partial-refresh validation](https://github.com/coreytshaffer/clear-lake-watch/issues/7) | Validation | Added manifest/source/output freshness checks and stale-source warnings. |
| [#8 Add scheduled public refresh workflow design](https://github.com/coreytshaffer/clear-lake-watch/issues/8) | Release process | Documented candidate-PR refresh design without enabling unattended publication. |
| [#9 Build reviewed weather-context export from proven telemetry](https://github.com/coreytshaffer/clear-lake-watch/issues/9) | Weather context | Added reviewed NOAA/National Weather Service public-source context marked `partial`, not `live`. |
| [#10 Design private field and microscopy intake review workflow](https://github.com/coreytshaffer/clear-lake-watch/issues/10) | Private QA | Documented private intake, QA, permission, and sanitized export gates. |
| [#11 Prepare reviewer-friendly portfolio screenshots and demo notes](https://github.com/coreytshaffer/clear-lake-watch/issues/11) | Portfolio review | Added reviewer screenshots, captions, and demo notes. |
| [#24 Career Services handoff review packet](https://github.com/coreytshaffer/clear-lake-watch/issues/24) | Career Services | Added an appointment-ready handoff packet with outreach text, resume-placement guidance, review questions, and conservative link path. |

## Completed Reviewer-Readiness Issues

| Issue | Focus | Result |
| --- | --- | --- |
| [#21 Accessibility pass for reviewer-facing docs and screenshots](https://github.com/coreytshaffer/clear-lake-watch/issues/21) | Accessibility | Added a narrow accessibility review note and linked it into the reviewer path. |
| [#22 Refresh reviewer screenshots after homepage portfolio update](https://github.com/coreytshaffer/clear-lake-watch/issues/22) | Screenshots | Refreshed homepage, portfolio signal, Data QA notice, and dashboard overview screenshots for the current reviewer packet. |
| [#23 Mobile reviewer path and sticky navigation review](https://github.com/coreytshaffer/clear-lake-watch/issues/23) | Mobile review | Documented the narrow-screen reviewer path and decided no mobile disclosure menu is needed for the current link set. |

## Completed Scientific Credibility Issues

| Issue | Focus | Result |
| --- | --- | --- |
| [#25 Draft variable register and field-validation plan](https://github.com/coreytshaffer/clear-lake-watch/issues/25) | Field validation planning | Added a variable register and field-validation plan that separate public-source context from future field, lab, microscopy, and sensor measurements. |
| Source-anchor spine | Official methods | Added an official method source spine so future protocols start from Lake County QAPP, EPA QA, EPA lake-monitoring, and California data-system anchors before field use. |
| Secchi mentor-review protocol | Field method planning | Added a source-anchored Secchi depth / clarity protocol draft with mentor-review questions, QA/QC checks, and a private-to-public gate. |
| Secchi mentor-review handoff | Mentor review | Added a short handoff packet with review links, reviewer questions, a feedback capture template, and a no-field-pilot decision gate. |

## Next Optional Candidates

These remain candidates for later work:

- Manual-only refresh workflow dry run, with no scheduled automation.
- Public page refresh after the next reviewed data snapshot.
- Site-registry local review for Clear Lake Keys near Ketch Court, Jago Bay, and Soda Bay.
- Community visual observations: decide whether any community photo or camera intake is ever pursued. The [community observation boundary](community-observation-boundary.md) is a design position only and must be satisfied before any intake implementation; no submission form, camera ingestion, or social-media processing exists or is scheduled.

## Completed Maintenance / Trust Issues

| Issue | Focus | Result |
| --- | --- | --- |
| Internal link validation | Validator | Added tracked-file local link checks to `validate-public-mirror.ps1` so broken public-review links fail validation. |
| Static snapshot age cue | Data trust | Added dated snapshot-age language to the release note and reviewer demo notes before broader sharing. |
| County GIS geometry publication boundary | Source/licensing | Moved county-derived candidate JSON and the geometry preview page to ignored `data/private/county-gis/` storage; the public mirror keeps OpenStreetMap geometry until reuse terms are verified. |
| Manual-only refresh dry-run support | Release process | Added `refresh-live-data.ps1 -DryRun` and recorded a successful May 28, 2026 dry-run rehearsal that skipped all public JSON writes. |
| Site-registry local review pass | Map trust | Added a medium-priority unresolved-decision note for Clear Lake Keys near Ketch Court, Jago Bay, and Soda Bay; all remain visibly `needs-local-review`. |
| Browser accessibility interaction pass | Reviewer readiness | Recorded a May 28, 2026 local browser pass for skip-link focus, notification controls, generated links, map keyboard interaction, chart rendering, and local request errors. |
| Maintenance file split | Maintainability | Split dashboard utilities, refresh parsing helpers, and validator link checks into small helper files without changing public behavior. |

## Open Maintenance / Trust Issues

Freshness and publication-safety alignment follow-ups, opened after a claim-hygiene pass on how the public mirror describes stale-data behavior:

| Follow-up | Focus | Intent |
| --- | --- | --- |
| Publication-time stale-snapshot gate | Publication safety | The refresh pipeline already fails closed on stale FHABS resources, but the public mirror validator only *warns* when the committed snapshot or source observations are past the freshness threshold. Decide whether to add an enforced publication-time gate (or reviewed override) so a stale snapshot cannot be published as fresh. |
| Stale-source policy: fail vs warn | Publication safety | Make an explicit, documented decision on whether an over-threshold source observation should fail the mirror validator or remain a visible warning, and align the docs to that decision. |
| Unify Python and PowerShell validators | Reproducibility | Reduce drift between `validate-public-mirror.py` and `validate-public-mirror.ps1` by sharing one source of truth for required-text guards and freshness logic. |
| Compute source and weather stale status | Data trust | Derive `status` / `machineReadableStatus` from observation age at build or render time instead of trusting static fields that can misrepresent freshness. |

These are documented as design/implementation follow-ups; none are enabled yet, and none change the current manual, reviewed publication posture.

## Open Reviewer-Readiness Issues

No reviewer-readiness issues are currently open in the public backlog snapshot.

## Next Active Candidate

- Wait for mentor, faculty, or qualified technical feedback on the Secchi review packet; after feedback, decide whether to revise, add official sources, or create a separate future private pilot design.

## Boundary

Completed backlog items do not make this an operational system. Future work should preserve the public/private boundary and avoid claims of official monitoring authority, recreation safety, emergency guidance, or public-health advice.
