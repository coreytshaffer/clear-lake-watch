# Accessibility remediation for contrast, theme controls, and navigation

Review began November 16, 2026 against `f608ffc97b1d50f4a13081697dfb85f8ba9ac6cd`. The remediation and follow-ups were merged into `main` through `bef53a2`. This record covers sampled reviewer-readiness checks. [Initial remediation](https://github.com/coreytshaffer/clear-lake-watch/pull/45) · [Latest follow-up](https://github.com/coreytshaffer/clear-lake-watch/pull/48)

## Scope and changes

- Retain data values, snapshot dates, public-safety boundary language, map assignments and interpretation logic unchanged.
- Darken only light-theme `.signal-review` text, retaining its background and review meaning.
- Use dark text on the pale teal dark-theme primary-button background; preserve white text in light mode.
- Use changing action labels, `Switch to dark mode` / `Switch to light mode`, with no `aria-pressed`. Update the static initial buttons in the homepage and project page. Remove the obsolete pressed-state CSS selector; keep hover styling.
- Tighten horizontal navigation spacing at the existing 420 CSS px breakpoint. Nav links and the theme button keep a minimum size of 40 × 40 CSS px at that breakpoint.
- Use shrinkable single-column tracks for the project page's arm and source grids and let their badges wrap in the stacked layout.
- Let navigation scroll with the page at the existing stacked breakpoint of 980 CSS px or less, or at viewport heights of 480 CSS px or less. Use a 16 CSS px section anchor offset plus the device safe-area inset, and reserve 6 CSS px of scroll padding for the focus outline in those viewports.
- Expose the schematic map as a named group. The eight focusable SVG circles have button roles, accessible labels, and Enter, Space, and pointer activation. The HTML marker buttons use the same selection behavior.
- Publish the updated theme action through a polite status region on activation. The status stays empty during startup.
- Move focus to the selected marker details after activation. The detail panel uses this focus move for its announcement.

The audit's low-contrast review badge is the `.signal-review` signal badge, not the separate `.review-badge` site-review component.

## Verification

New source-level regression tests were run before production changes: three failed for the expected contrast/theme defects, while light-theme primary contrast passed. After the changes, all four pass.

- Light review signal: approximately **3.48:1 → 5.83:1**, alpha-composited over `--panel-strong` cream.
- Dark primary button: approximately **2.03:1 → 8.96:1**.
- Theme action tested through the actual `setTheme` function for light → dark → light, including document theme, stored preference and browser theme-color updates.

These ratios are source-level calculations, not measurements of every rendered background or state. CSS gradients, all cascade interactions, all component variants and forced-color mode remain untested.

Commands passed:

- `node --test scripts/*.test.*`: 22 tests passed, zero failed (includes suite/parent test counts).
- `node scripts/dashboard-utils.smoke.mjs`.
- `python scripts/validate-public-mirror.py`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/validate-public-mirror.ps1`.
- `git diff --check`.

The mirror validators reported existing dated-data warnings for the dashboard snapshot and two FHABS sources.

Browser-only `tests/dashboard-utils.test.html` was not executed.

## Rendered browser checks

Playwright checked the pinned base and revised patch in Chrome 157 on Windows for 32 combinations across both pages, both themes and four viewport conditions. The narrow viewports were 800 CSS px tall. Chrome's 400% page zoom turned a 1280 × 1024 viewport into 320 × 256 CSS px.

| Viewport | Homepage rows, base → revised | Project rows, base → revised |
| --- | ---: | ---: |
| 320 CSS px | 3 → 3 | 3 → 3 |
| 360 CSS px | 3 → 3 | 2 → 2 |
| 390 CSS px | 3 → 2 | 2 → 2 |
| 400% page zoom | 3 → 3 | 3 → 3 |

Rows count the nav links and theme button below the brand. The original first-slice patch gave the project page three rows at 360 and 390 CSS px. The revision restores two rows and the base header height of about 142 CSS px in both themes.

The project page fit the viewport in all four conditions. The previous draft overflowed by 224, 184 and 154 CSS px at the three narrow widths respectively, and by 224 CSS px at 400% zoom. The Snapshot heading cleared the header after keyboard activation from both pages at all four sizes.

Enter and Space changed the theme and retained visible focus on the theme button. The skip link focused main content on both pages. At 400%, the sampled focus targets and outlines were fully visible, including the Reviewer demo notes link whose outline was previously clipped by about 6 CSS px.

Additional Chrome checks confirmed that the header scrolled away at 640 × 800, 980 × 800 and 1280 × 480 CSS px. It stayed sticky at 981 × 800 and 1280 × 800 CSS px, with the Snapshot heading visible after the anchor jump.

## V5 axe and browser checks

V5 limits primary-button transitions to the hover transform. On the homepage, the View Project Page button's theme colors now change together.

| Homepage scenario | V4 minimum contrast | V5 minimum contrast |
| --- | ---: | ---: |
| Saved dark theme on startup | 2.96:1 | 8.96:1 |
| Light to dark | 2.96:1 | 8.96:1 |
| Dark to light | 2.03:1 | 6.15:1 |

Contrast was measured at the first color change and on subsequent animation frames for about 260 ms. V5 stayed above 4.5:1 in all sampled frames and retained the hover movement.

Axe-core 4.14.1 scanned both pages and themes in Chrome at 1280 × 1024 CSS px using WCAG 2.0–2.2 A and AA tags and best-practice rules. V2 reported eight SVG marker ARIA violations in each homepage theme.

| Page | Theme | Automated failing nodes | Nodes flagged for manual review |
| --- | --- | ---: | ---: |
| Homepage | Light | 0 | 492 |
| Homepage | Dark | 0 | 493 |
| Project | Light | 0 | 133 |
| Project | Dark | 0 | 299 |

The manual items include contrast checks over backgrounds axe could not resolve and four homepage ARIA label checks. Chrome's accessibility tree exposed all eight SVG markers as named buttons in both themes. Enter and Space activated both marker control types and focused the updated details. On both pages and from either initial theme, Enter and Space updated the theme status and retained focus on the toggle.

## V5 muted NVDA check

NVDA 2026.3.1 used its silence synthesizer while logging its generated speech for the foreground Chrome preview. The v3 baseline missed three of the four updated theme-label announcements and read the details twice for each sampled marker selection.

- NVDA announced both skip-link names. Enter moved focus to main content and NVDA announced the main landmark.
- NVDA announced `Switch to light mode` after Enter and `Switch to dark mode` after Space on both pages. Each announcement occurred while focus stayed on the toggle, before any refocus.
- NVDA announced the sampled SVG marker and HTML marker as named buttons. Enter on the SVG marker and Space on the HTML marker focused the updated detail panel and produced one detail announcement each.

## CHE-16 verification before merge

The local review used `c1ec40b` as its base. The v5 patch focused the marker detail
panel but left its heading clipped or off-screen in 42 of 50 tested cases. A
follow-up scrolls the panel into view when its heading is outside the visible
area. All 50 cases passed in Chrome across both themes, including widths of
320, 360, and 390 CSS px, a 320 × 256 short viewport, and a 390 × 450 short
viewport. Enter, Space, and pointer selection exposed the updated heading.
The next Tab reached a visible source link, and the saved theme survived
reload on both pages.

Muted NVDA 2026.3.1 passed 21 speech assertions for skip links, theme labels,
marker buttons, repeated selection, detail links, and the map filter. The
reviewed-only filter left focus on the select and produced one announcement
of “No mapped reports for this filter.” The status cleared when the filter
again had results.

The initial rendered check found 67 low-contrast text samples. The follow-up
corrected the panel labels, dark status cards and callouts, secondary
buttons, project chips, and map labels. The repeated rendered check passed
all 1,451 sampled text instances across both pages and themes. All four axe
scans reported zero automated violations. The View Project Page button
remained at or above 6.15:1 across sampled theme transitions.

The homepage reviewer shortcuts now form a navigation landmark named by the
visible Internship Reviewer Path label. The three chart badge rows expose
named groups and retain their visible badges. Chrome exposed all four
names in both themes. The repeated axe scans returned zero automated
violations and zero ARIA label flags. Muted NVDA passed 25 speech assertions
including the reviewer landmark and temporary focus probes for all three
chart groups.

## Merged follow-ups and verification

- The accessibility remediation merged as `c74554d`. The PR records the final Chrome keyboard, rendered contrast, axe, and NVDA checks for the homepage and project page. [PR #45](https://github.com/coreytshaffer/clear-lake-watch/pull/45) · [Post-merge CI #33](https://github.com/coreytshaffer/clear-lake-watch/actions/runs/44477178554)
- The snapshot wording changes merged as `dbe496e`. The browser checks covered hydrology date ranges and the catalogued source-family count. [PR #46](https://github.com/coreytshaffer/clear-lake-watch/pull/46) · [Post-merge CI #35](https://github.com/coreytshaffer/clear-lake-watch/actions/runs/44482707123)
- The Firefox marker focus fix merged as `6e926db`. Firefox 153.0 at native 400% zoom (320 × 235 CSS px) passed in both themes. Tab and Shift+Tab kept the HTML marker focus outline visible. After activating a sampled marker, the next Tab reached the visible first source link. [PR #47](https://github.com/coreytshaffer/clear-lake-watch/pull/47) · [Post-merge CI #37](https://github.com/coreytshaffer/clear-lake-watch/actions/runs/44490172290)
- The accessible hydrology tables merged as `bef53a2`. The browser checks covered date and value parity for all 29 observations per series, with Lake level in `ft` and Cole Creek discharge in `ft3/s`. Both disclosures were keyboard-operable in Firefox at native 400% in both themes. NVDA announced both controls and their states, both captions, the headers and units, and sampled date and value cells during table navigation. [PR #48](https://github.com/coreytshaffer/clear-lake-watch/pull/48) · [Post-merge CI #39](https://github.com/coreytshaffer/clear-lake-watch/actions/runs/44654174361)

The linked CI runs cover Linux and Windows PowerShell 5.1 mirror validation. The PR descriptions record the manual browser and screen-reader evidence for the tested paths.
