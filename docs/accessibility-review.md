# Accessibility Review

**Status:** reviewer-readiness pass
**Audience:** Career Services, internship reviewers, scholarship reviewers, faculty mentors, and technical reviewers
**Prepared:** 2026-05-14
**Updated:** 2026-05-28 browser interaction pass

This note records a narrow accessibility pass for the public reviewer packet. It focuses on whether reviewers can follow the main links, understand screenshot captions, and inspect the project without depending on visual layout alone.

Clear Lake Watch is a late prototype / early MVP. It is not official public-health guidance, an official advisory, recreation guidance, emergency guidance, a validated forecast, or a deployed sensor network.

## Scope

Reviewed:

- homepage skip link, primary navigation labels, reviewer links, and public snapshot status wording;
- reviewer-facing documentation links in the README, evidence summary, evidence index, dashboard anatomy guide, and demo notes;
- public screenshot captions and alt-text-style descriptions in the reviewer notes;
- chart and map interpretation barriers for reviewers who are not relying on the visual display;
- one local rendered-dashboard browser interaction pass for skip-link behavior, notification controls, generated links, map keyboard interaction, chart rendering, and local request errors;
- conservative boundary language around public-health, recreation, emergency, forecasting, and official-advisory claims.

Not reviewed:

- a full WCAG conformance audit;
- manual screen-reader testing;
- keyboard testing in every browser;
- browser notification permission-prompt testing across browser vendors;
- color contrast measurement across every state;
- formal mobile navigation review, which is tracked separately in issue #23.

## Current Accessibility Signals

| Area | Current support | Remaining risk |
| --- | --- | --- |
| Page structure | The dashboard uses a skip link, labeled navigation, section headings, and named regions for the main dashboard sections. A May 28 browser pass confirmed the skip link moves keyboard focus to the main content area. | Screen-reader behavior and browser-matrix keyboard behavior still need manual review before broader promotion. |
| Reviewer links | Reviewer documents use descriptive link text such as "Dashboard anatomy review guide" and "Career Services handoff packet." Generated `Open JSON` links were checked in their named product-card context. | Compact generated link labels should be revisited if the data-product cards are redesigned or moved out of context. |
| Screenshot descriptions | Reviewer demo notes include captions written as alt-text-style descriptions plus review cues, including refreshed homepage, portfolio signal, and Data QA notice captures from issue #22. | Captions should be refreshed whenever screenshot files are replaced or the visible reviewer path changes. |
| Status and notices | Snapshot status and data QA notices use conservative language and avoid alert-like public-safety claims. A May 28 browser pass confirmed visible labels, keyboard-focusable controls, and a permission-needed status message for test notices. | Browser permission prompts and screen-reader announcement behavior still need deeper assistive-technology review. |
| Charts and maps | Reviewer docs explain that maps and charts are portfolio evidence, source context, and QA surfaces rather than official condition labels. A May 28 browser pass confirmed map filter use, keyboard marker selection, focused marker details, chart rows, and coverage cards. | Nonvisual review still depends on surrounding text summaries; future chart/map work should expose more data-table equivalents. |
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
- Add data-table equivalents for chart and map summaries before making stronger nonvisual-access claims.
- Keep accessibility claims narrow: describe this as a reviewer-readiness pass, not a formal accessibility certification.
