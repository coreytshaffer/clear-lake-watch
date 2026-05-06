# Cross-Platform Typography Audit

Status: static CSS audit complete; local mobile-width screenshot review complete; non-Windows/device screenshot review still pending

Date: 2026-05-05

This note records the current typography posture for Clear Lake Watch. It is a conservative static audit, not a full cross-device visual QA pass.

## Current Font Strategy

Clear Lake Watch uses no external web fonts. This keeps the static dashboard lightweight, privacy-conscious, and resilient when opened locally or mirrored from a simple static host.

The current body font stack is:

```css
"Aptos", "Segoe UI", -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif
```

The current display font stack is:

```css
"Georgia", "Palatino Linotype", "Book Antiqua", Times, serif
```

## Findings

- The previous body stack was Windows-centered because it preferred Aptos and Segoe UI without explicit macOS/iOS and generic fallback steps.
- The display stack was acceptable but thin; adding `Book Antiqua` and `Times` gives older Windows and non-Windows systems a clearer fallback path.
- The stylesheet used nonzero letter spacing, including a negative heading value. That can make text less predictable across platforms, especially when fallback fonts differ.
- No web font is recommended at this stage. The project benefits more from no-build reliability than from tighter brand typography.

## Changes Made

- Expanded the body font stack with Apple system and common cross-platform fallbacks.
- Expanded the display font stack with additional local serif fallbacks.
- Normalized explicit `letter-spacing` values to `0`.
- Preserved the current no-build, no-external-font architecture.

## Remaining Review

A local mobile-width screenshot review is recorded in `docs/screenshot-review.md`. The captured homepage first viewport did not show immediate heading, navigation, button, or card-text wrapping problems.

Before a broad public publication pass, capture at least one more final promotion screenshot, preferably on a non-Windows or physical mobile browser, and check:

- hero heading wrapping
- navigation label wrapping
- stat-card value wrapping
- chart label readability
- map-marker detail text
- source/status card density

If text looks cramped on non-Windows systems, prefer spacing, width, and font-size adjustments before adding a web font.
