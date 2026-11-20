# Public Backlog

Status: completed trust-hardening, reviewer-readiness, and first maintenance-split passes.

Clear Lake Watch remains a late prototype / early MVP. It is not official public-health guidance, an official advisory, a validated forecast, or a deployed sensor network.

## Current Checkpoint

Last reconciled against `main` at `bef53a2`.

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

## Completed Freshness and Validator Follow-Ups

Freshness and publication-safety alignment follow-ups are recorded below.

| Follow-up | Result | Evidence |
| --- | --- | --- |
| Stale-data publication policy (CHE-20) | Reviewed historical snapshots retain visible dates and age warnings. New snapshot candidates require an explicit disposition for each stale source and a separate human publication decision. | [Warning versus failure](source-freshness-validation.md#warning-versus-failure) · [Refresh review criteria](formal-public-refresh-runbook.md#acceptance-criteria) |
| Observation-age freshness (CHE-22) | The dashboard calculates weather observation age at page load and labels lake-source records as historical observations. | [PR #41](https://github.com/coreytshaffer/clear-lake-watch/pull/41) · [Post-merge CI #25](https://github.com/coreytshaffer/clear-lake-watch/actions/runs/44247140791) |
| Shared snapshot evaluator (CHE-21) | The Python and PowerShell entry points share freshness and manifest-integrity findings. | [PR #42](https://github.com/coreytshaffer/clear-lake-watch/pull/42) · [Post-merge CI #27](https://github.com/coreytshaffer/clear-lake-watch/actions/runs/44447952557) |
| Shared required-text guards (CHE-21) | Both validators use one catalog and require selected guard files to be tracked public files inside the checkout. | [PR #43](https://github.com/coreytshaffer/clear-lake-watch/pull/43) · [Post-merge CI #29](https://github.com/coreytshaffer/clear-lake-watch/actions/runs/44457666423) |
| Native validator hardening (CHE-21 follow-up) | Native readers enforce JSON object shape, strict publication permission for reviewed records, and checkout containment. | [PR #44](https://github.com/coreytshaffer/clear-lake-watch/pull/44) · [Post-merge CI #31](https://github.com/coreytshaffer/clear-lake-watch/actions/runs/44468066769) |

## Completed Reviewer Accessibility and Snapshot Follow-Ups

| Follow-up | Result | Evidence |
| --- | --- | --- |
| Reviewer accessibility and map feedback | Improved contrast, keyboard navigation, theme feedback, and marker detail focus. Added an announcement when the map filter finds no results. | [PR #45](https://github.com/coreytshaffer/clear-lake-watch/pull/45) · [Post-merge CI #33](https://github.com/coreytshaffer/clear-lake-watch/actions/runs/44477178554) |
| Snapshot wording | Show the hydrology observation date range and distinguish the eight catalogued source families from the two automated feeds used by the snapshot. | [PR #46](https://github.com/coreytshaffer/clear-lake-watch/pull/46) · [Post-merge CI #35](https://github.com/coreytshaffer/clear-lake-watch/actions/runs/44482707123) |
| Firefox marker focus | Keep the focused HTML marker card and its outline in view at native 400% zoom. | [PR #47](https://github.com/coreytshaffer/clear-lake-watch/pull/47) · [Post-merge CI #37](https://github.com/coreytshaffer/clear-lake-watch/actions/runs/44490172290) |
| Hydrology data tables | Expose the 29 Lake level and 29 Cole Creek discharge observations in keyboard-accessible date-and-value tables. | [PR #48](https://github.com/coreytshaffer/clear-lake-watch/pull/48) · [Post-merge CI #39](https://github.com/coreytshaffer/clear-lake-watch/actions/runs/44654174361) |

The [accessibility remediation record](accessibility-remediation-2026-11-16.md#merged-follow-ups-and-verification) links the sampled Chrome, Firefox, axe, and NVDA checks.

## Open Maintenance / Trust Issues

- Clear Lake Keys near Ketch Court, Jago Bay, and Soda Bay await named local review or stronger source confirmation. [Unresolved site-registry decision](site-registry-unresolved-decision.md)
- A public-page refresh depends on the next reviewed data snapshot and a separate human publication decision. [Formal public refresh runbook](formal-public-refresh-runbook.md)

## Open Reviewer-Readiness Issues

The tracked reviewer-readiness work above is complete. The [accessibility review](accessibility-review.md#follow-up-items) records what to check when the reviewer path or public materials change.

## Next Active Candidate

- Wait for mentor, faculty, or qualified technical feedback on the Secchi review packet; after feedback, decide whether to revise, add official sources, or create a separate future private pilot design.

## Boundary

Completed backlog items do not make this an operational system. Future work should preserve the public/private boundary and avoid claims of official monitoring authority, recreation safety, emergency guidance, or public-health advice.
