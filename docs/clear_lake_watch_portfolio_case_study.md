# Clear Lake Watch: Watershed Intelligence Dashboard Prototype

## Portfolio Summary

**Clear Lake Watch** is my flagship environmental systems project: a late-prototype / early-MVP dashboard for Clear Lake, California that integrates public environmental data, GIS context, site-registry QA, source freshness checks, public methodology guardrails, and local-first monitoring architecture.

The project is designed as a **situational-awareness and research-planning prototype**, not an official public-health advisory tool. Its purpose is to explore how public data, transparent uncertainty, spatial context, and local-first environmental monitoring systems could support watershed resilience around Clear Lake.

**Project type:** Environmental data dashboard / watershed intelligence prototype  
**Status:** Late prototype / early MVP  
**Location focus:** Clear Lake, Lake County, California  
**Primary themes:** Water quality, cyanobacterial blooms, public data, GIS, source transparency, community monitoring, local-first infrastructure

**Live dashboard:** [Add link]  
**GitHub repository:** [Add link]  
**Methodology page:** [Add link]  
**Project page:** [Add link]

---

## The Problem

Clear Lake is a complex and high-stakes environmental system. Public information exists across multiple sources, but it can be difficult for residents, students, researchers, and collaborators to understand what is current, what is directly observed, what is reported, what is derived, and what still needs local review.

Water-quality communication around cyanobacterial blooms is especially sensitive. A useful public dashboard needs to provide context without overstating confidence, replacing official guidance, or flattening uncertainty into a misleading “safe/unsafe” signal.

Clear Lake Watch began as a response to that challenge: how can a public-facing environmental dashboard make lake conditions easier to explore while remaining honest about data limitations, source freshness, review status, and public-health boundaries?

---

## My Role

I designed and built Clear Lake Watch as an environmental science portfolio project and systems-integration artifact. My role included:

- Defining the project scope and public communication boundaries
- Designing the dashboard structure and user-facing information architecture
- Integrating public environmental data sources into static dashboard-ready files
- Building site-registry and map-review concepts for lake-arm assignment QA
- Creating methodology and disclaimer language for responsible interpretation
- Planning the local-first architecture for future field, weather, and sensor workflows
- Separating public-reviewed outputs from private intake, review, and experimental workflows

This project reflects my broader interest in **Cybernetic Ecology**: using feedback systems, environmental data, local knowledge, and resilient technical infrastructure to better understand and manage complex ecological systems.

---

## Project Goals

Clear Lake Watch was designed around five core goals:

1. **Make public lake-condition data easier to explore**  
   Bring public environmental signals into a clearer dashboard interface.

2. **Preserve uncertainty instead of hiding it**  
   Clearly separate observed, reported, derived, planning, and experimental signals.

3. **Support spatial understanding of Clear Lake**  
   Organize monitoring context around lake arms, site registry entries, coordinates, and map trust status.

4. **Protect public trust**  
   Avoid presenting the dashboard as official public-health guidance or a substitute for agency advisories.

5. **Prepare for future local-first monitoring**  
   Design the public dashboard as a reviewed publication layer that can eventually sit on top of a broader local environmental monitoring backbone.

---

## What I Built

The current prototype includes:

- A static public dashboard for Clear Lake environmental situational awareness
- Public snapshot cards generated from reviewed public data files
- USGS hydrology context and FHABS-derived report summaries
- OpenStreetMap-derived Clear Lake shoreline geometry
- Registry-backed map markers and lake-arm grouping
- Map trust filtering for reviewed versus needs-review markers
- Source-status and data-product panels
- Reporting-pattern analytics with caveats against overinterpretation
- Public methodology and disclaimer page
- Separate project roadmap page
- Weather-context placeholder for future shared monitoring backbone integration
- Responsive layout, dark mode, skip links, screen-reader summaries, and mobile-friendly design elements
- Local-first architecture notes for future telemetry, field, and review workflows

The dashboard is intentionally lightweight and no-build. This keeps the public publication layer easier to validate, mirror, and maintain while the project matures.

---

## Data Sources and Signal Types

Clear Lake Watch treats different data sources as different kinds of evidence. Rather than blending everything into one simplified condition score, the project labels and separates signals so users can understand what kind of information they are seeing.

Current and planned source families include:

- **FHABS reports:** Public harmful algal bloom reports and related advisory/reporting context
- **USGS hydrology:** Lake-level and streamflow context from public water services
- **OpenStreetMap shoreline geometry:** Geographic context for the public map layer
- **Site registry records:** Local project structure for stable IDs, lake-arm grouping, and review status
- **Future weather context:** Public-safe weather telemetry from a shared environmental monitoring backbone
- **Future field/microscopy records:** Reviewed private intake workflow before any public export

The project distinguishes between:

- **Observed** data
- **Reported** data
- **Derived** summaries
- **Needs-review** assignments
- **Planning** content
- **Experimental** features

This distinction is central to the project’s trust model.

---

## Design and Architecture

Clear Lake Watch uses a layered structure:

```text
public source data → local refresh/normalization → reviewed JSON exports → static public dashboard
```

The broader architecture vision is:

```text
edge collection → local processing → local storage → reviewed public exports → static public mirror
```

The public dashboard is not meant to be the entire monitoring system. It is the publication surface: the part that shows reviewed, public-safe information. Private review surfaces, local databases, field notes, and future sensor telemetry should remain behind review boundaries until they are ready for public release.

This architecture reflects several priorities:

- resilience during outages
- reduced dependency on cloud services
- clear separation between raw, reviewed, and public data
- low-cost static publishing
- future compatibility with local environmental monitoring devices
- explicit boundaries around AI and forecasting features

---

## Public-Health and Governance Boundaries

Because harmful algal bloom information can influence public behavior, Clear Lake Watch is intentionally conservative in its language.

The dashboard does **not**:

- issue official advisories
- certify water safety
- replace local, state, federal, or Tribal guidance
- publish unreviewed field observations directly
- present experimental forecasts as current conditions
- treat report counts as direct bloom-severity estimates

This is especially important because reporting patterns can reflect monitoring intensity, public attention, and source availability — not just environmental conditions.

Future field observations, microscopy records, or community-science submissions should include explicit permission, reviewer traceability, location precision, taxonomic confidence, and publication decisions before appearing in public dashboard outputs.

---

## Ethical and Accessibility Considerations

Clear Lake Watch is designed around responsible environmental communication. Key ethical considerations include:

- **Do not bypass official public-health guidance**
- **Do not overstate provisional or heuristic assignments**
- **Do not publish private reviewer notes or unreviewed field records**
- **Respect Tribal data sovereignty and local governance relationships**
- **Keep experimental AI and forecasting clearly separated from observed data**
- **Use accessibility features so the dashboard is not only useful to sighted users**

Accessibility features and design considerations include:

- skip links
- semantic regions
- screen-reader summary text
- keyboard-focus styling
- responsive layout
- high-contrast dark and light modes
- text caveats alongside visual charts and maps

---

## Technical Stack

**Frontend:** HTML, CSS, JavaScript  
**Deployment model:** Static public dashboard / GitHub Pages-compatible  
**Data format:** Local JSON exports  
**Mapping approach:** SVG map layer with public shoreline geometry and source-attributed markers  
**Architecture pattern:** Local-first data generation with reviewed public export boundary  
**Future integration targets:** weather telemetry, field observations, microscopy records, edge devices, local AI-assisted review workflows

---

## Challenges and Tradeoffs

### Challenge 1: Public usefulness vs. public-health risk

A dashboard can make information easier to access, but it can also create false confidence if users interpret it as official safety guidance. Clear Lake Watch addresses this by using disclaimers, methodology notes, signal labels, and conservative public-facing language.

### Challenge 2: Spatial context vs. assignment uncertainty

Mapping bloom reports requires handling coordinates, landmarks, lake-arm groupings, and site-registry matches. Some assignments are reviewed starters, while others require local review. The dashboard keeps that uncertainty visible through review-status labels and map trust filtering.

### Challenge 3: Feature growth vs. trust hardening

It would be easy to add more features quickly, especially forecasting, AI summaries, or public submission forms. I intentionally prioritized source transparency, review boundaries, and public methodology before expanding into higher-risk capabilities.

### Challenge 4: Public dashboard vs. private monitoring system

The project needs both a public-facing surface and private operational workflows. Clear Lake Watch separates those concerns by treating the dashboard as a static, reviewed publication layer rather than the full operational monitoring system.

---

## What I Learned

This project helped me practice environmental systems thinking in a practical technical context. The biggest lesson is that environmental dashboards are not just software products — they are trust systems.

A useful environmental data product must answer more than “Can this data be displayed?” It also has to answer:

- Where did this data come from?
- How fresh is it?
- What does it actually measure?
- What does it not measure?
- What should users avoid concluding from it?
- Which parts are reviewed, provisional, or experimental?
- Who has authority over public-health or land/water governance decisions?

That framing has shaped the architecture, language, and roadmap of Clear Lake Watch.

---

## Current Status

Clear Lake Watch is currently a **late prototype / early MVP**.

It is mature enough to serve as a public portfolio artifact and systems-integration case study, but it should not be treated as a completed monitoring authority.

The strongest current use cases are:

- portfolio demonstration
- environmental data systems case study
- public-data dashboard prototype
- research-planning tool
- architecture foundation for future local-first monitoring

---

## Publication Readiness and Validation

Clear Lake Watch now has a release-governed review path for portfolio use. The project includes a publication checklist that separates local review, private repository work, public mirror updates, and flagship promotion.

Current release evidence includes:

- a publication review checklist for freshness, private-file exclusion, claim review, site-registry posture, screenshots, Git scope, and final publish readiness
- local dashboard validation through `scripts/validate-dashboard.ps1 -SkipHttp`
- SQLite validation for private site-review and field/microscopy stores
- a local mobile-width screenshot review for first-viewport typography and wrapping
- public/private mirror documentation that keeps local records, SQLite stores, and unreviewed intake files out of the public dashboard

The recommended next release scope is a **portfolio-safe release**, not a broad public launch. That means the project can be shown as a professional artifact with clear validation evidence, screenshots, README, methodology page, project page, and case study, while avoiding official monitoring, public-health advisory, live field-submission, validated forecast, or deployed sensor-network claims.

---

## Next Steps

Near-term priorities include:

1. Choose the portfolio-safe release scope before adding live feature surfaces.
2. Add polished screenshots or short demo clips for portfolio use.
3. Replace placeholder links with the dashboard, repository, methodology, and project-page URLs.
4. Add a concise validation-status note from the latest dashboard and SQLite checks.
5. Soft-share privately with an SNHU advisor, career services, or one trusted environmental/water-quality contact for wording and professionalism feedback.
6. Complete real site-registry review before promoting uncertain FHABS landmark-to-arm assignments.
7. Connect reviewed weather-context exports only after the current trust-hardening pass is complete.
8. Continue keeping field, microscopy, and AI-assisted workflows behind reviewed publication boundaries.

---

## Screenshots

[Add screenshot: dashboard hero and live snapshot]

[Add screenshot: map trust filter and site-registry QA]

[Add screenshot: methodology disclaimer or signal types]

---

## Possible Portfolio Blurb

**Clear Lake Watch** is a late-prototype watershed intelligence dashboard for Clear Lake, California. It integrates public environmental data, GIS context, site-registry QA, source-status tracking, and local-first monitoring architecture while clearly separating reviewed information from provisional, planning, and experimental signals.

---

## Information To Add

To finish this case study, I should add:

- Live dashboard URL
- GitHub repository URL
- Project page URL
- Methodology page URL
- Three screenshots
- A brief personal note about why Clear Lake matters to me
- Any concrete project metrics I want to highlight
- Validation status from the latest dashboard check
- Whether I want to frame this under “Cybernetic Ecology” publicly or keep that as a subtitle
