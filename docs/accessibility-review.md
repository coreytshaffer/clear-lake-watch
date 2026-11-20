# Accessibility Review

**Status:** reviewer-readiness pass
**Audience:** Career Services, internship reviewers, scholarship reviewers, faculty mentors, and technical reviewers
**Prepared:** 2026-05-14
**Updated through:** `bef53a2`

This note records a narrow accessibility pass for the public reviewer packet. It focuses on whether reviewers can follow the main links, understand screenshot captions, and inspect the project without depending on visual layout alone.

Clear Lake Watch is a late prototype / early MVP. It is not official public-health guidance, an official advisory, recreation guidance, emergency guidance, a validated forecast, or a deployed sensor network.

## Scope

The May 2026 pass reviewed the public packet and the rendered dashboard.

- homepage skip link, primary navigation labels, reviewer links, and public snapshot status wording;
- reviewer-facing documentation links in the README, evidence summary, evidence index, dashboard anatomy guide, and demo notes;
- public screenshot captions and alt-text-style descriptions in the reviewer notes;
- chart and map interpretation barriers for reviewers who are not relying on the visual display;
- one local rendered-dashboard browser interaction pass for skip-link behavior, notification controls, generated links, map keyboard interaction, chart rendering, and local request errors;
- conservative boundary language around public-health, recreation, emergency, forecasting, and official-advisory claims.

The [merged follow-up record](accessibility-remediation-2026-11-16.md#merged-follow-ups-and-verification) covers Chrome, Firefox, sampled NVDA use, and rendered contrast checks. The [mobile reviewer path review](mobile-reviewer-path-review.md) records the separate narrow-screen navigation pass. WCAG conformance, additional browser and assistive-technology combinations, and cross-browser notification permission prompts remain outside this evidence.

## Current Accessibility Signals

| Area | Current support | Remaining risk |
| --- | --- | --- |
| Page structure | The homepage and project page use skip links and labeled navigation. The follow-ups checked skip-link focus, Snapshot navigation, and theme controls with Chrome, Firefox, and sampled NVDA use. [PR #45](https://github.com/coreytshaffer/clear-lake-watch/pull/45) · [PR #47](https://github.com/coreytshaffer/clear-lake-watch/pull/47) | Other browser and assistive-technology combinations need their own checks. |
| Reviewer links | Reviewer documents use descriptive link text such as "Dashboard anatomy review guide" and "Career Services handoff packet." Generated `Open JSON` links were checked in their named product-card context. | Compact generated link labels should be revisited if the data-product cards are redesigned or moved out of context. |
| Screenshot descriptions | Reviewer demo notes include captions written as alt-text-style descriptions plus review cues, including refreshed homepage, portfolio signal, and Data QA notice captures from issue #22. | Captions should be refreshed whenever screenshot files are replaced or the visible reviewer path changes. |
| Status and notices | The May browser pass checked visible labels, keyboard focus, and the permission-needed message for local test notices. NVDA announced the empty map-filter status in the remediation pass. [PR #45](https://github.com/coreytshaffer/clear-lake-watch/pull/45) | Browser permission prompts and their announcements still need cross-browser review. |
| Charts and maps | Both hydrology sparklines have keyboard-accessible date-and-value tables. Sampled keyboard paths on the map reached visible marker details and their first source link. [PR #47](https://github.com/coreytshaffer/clear-lake-watch/pull/47) · [PR #48](https://github.com/coreytshaffer/clear-lake-watch/pull/48) | Other chart and map summaries need separate review before making broader nonvisual-access claims. |
| Boundary language | Reviewer docs repeatedly state what the project does and does not claim. | Older portfolio narrative files may still need copy refresh after the reviewer-readiness phase. |

## Reviewer Guidance

Use these documents first when checking accessibility and clarity:

1. [Reviewer demo notes](reviewer-demo-notes.md) for screenshot captions and a short review path.
2. [Dashboard anatomy review guide](dashboard-anatomy-review-guide.md) for dashboard-zone explanations.
3. [Clear Lake Watch v0.1 evidence summary](clear-lake-watch-v0.1-evidence-summary.md) for concise reviewer links and role fit.
4. [Browser accessibility interaction pass](browser-accessibility-interaction-pass-2026-05-28.md) for the rendered-dashboard keyboard and generated-link check.
5. [Mobile reviewer path review](mobile-reviewer-path-review.md) for narrow-screen navigation findings.
6. [Public backlog](public-backlog.md) for current reviewer-readiness status.

## Follow-Up Items

- Refresh screenshot captions whenever issue #22 screenshots are replaced by a newer public snapshot.
- If the top navigation grows, repeat mobile keyboard and narrow-width review before broad promotion.
- Review changes to other chart and map summaries for data-table equivalents before extending nonvisual-access claims.
- Keep accessibility claims narrow: describe this as a reviewer-readiness pass, not a formal accessibility certification.
