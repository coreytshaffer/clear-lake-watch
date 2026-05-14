# Mobile Reviewer Path Review

**Status:** reviewer-readiness pass  
**Audience:** Career Services, internship reviewers, scholarship reviewers, faculty mentors, and technical reviewers  
**Prepared:** 2026-05-14  

This note records a narrow mobile usability review for the public dashboard reviewer path after adding the Portfolio navigation link, reviewer homepage section, accessibility note, and refreshed screenshot packet.

Clear Lake Watch is a late prototype / early MVP. It is not official public-health guidance, an official advisory, recreation guidance, emergency guidance, a validated forecast, or a deployed sensor network.

## Scope

Reviewed:

- sticky primary navigation at 390px, 360px, and 320px viewport widths;
- visibility and wrapping of Snapshot, Map, Analytics, Data, Project, Methodology, Portfolio, and Dark Mode controls;
- whether the mobile page has horizontal overflow;
- whether the public prototype, snapshot boundary, reviewer links, and portfolio signal remain reachable on a narrow screen;
- whether a mobile menu disclosure is needed now.

Not reviewed:

- a full mobile design redesign;
- every downstream dashboard card;
- physical-device testing;
- screen-reader testing on mobile operating systems;
- official accessibility certification.

## Findings

| Check | Finding | Review meaning |
| --- | --- | --- |
| Sticky navigation | The nav remains sticky after scroll and keeps all primary links visible. At 390px and 360px, links wrap across three rows; at 320px, links still fit without overlap. | Reviewer navigation is usable, though visually tall. |
| Tap target size | Navigation links and the theme toggle measure about 40px high at the narrowest checked width. | The controls are close to common mobile target guidance and remain practical for review. |
| Horizontal overflow | The page width matched the viewport at 390px, 360px, and 320px. | The added Portfolio link does not create sideways scrolling. |
| Reviewer path | Public prototype framing, the snapshot boundary, reviewer links, and portfolio signal remain reachable on mobile. | The mobile path still supports Career Services and internship-review use. |
| Mobile menu disclosure | A disclosure menu is not required for the current link set. | Reconsider if another top-level nav item is added or if physical-device testing shows the sticky nav blocks too much content. |

## Measured Review Notes

- 390px viewport: sticky nav stayed at the top after scroll, measured about 376px wide by 190px tall, and showed all primary links without overlap.
- 360px viewport: sticky nav stayed at the top after scroll, measured about 346px wide by 190px tall, and showed all primary links without overlap.
- 320px viewport: sticky nav stayed at the top after scroll, measured about 306px wide by 190px tall, and wrapped the Data, Project, Methodology, Portfolio, and Dark Mode controls onto lower rows without horizontal overflow.

## Decision

No mobile navigation redesign is needed for this reviewer-readiness slice. The current wrapped sticky navigation is acceptable for a late prototype / early MVP public portfolio review.

Future work should consider a compact mobile disclosure menu only if:

- more top-level navigation links are added;
- physical-device testing shows the sticky nav blocks too much of the page;
- keyboard or assistive-technology review finds a concrete navigation blocker.

## Related Files

- [Reviewer demo notes](reviewer-demo-notes.md)
- [Accessibility review](accessibility-review.md)
- [Dashboard anatomy review guide](dashboard-anatomy-review-guide.md)
- [Public backlog](public-backlog.md)
- [Mobile homepage screenshot](public-screenshots/clear-lake-watch-homepage-mobile-2026-05-14.png)
