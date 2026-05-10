<!--
SYNC IMPACT REPORT
==================
Version change: [BLANK TEMPLATE] → 1.0.0
Type: MAJOR (initial ratification — no prior principles existed)

Added principles:
  I.   Dark Factory Automation-First (new)
  II.  Microsoft 365 Platform-Native (new)
  III. Spec-Driven Development (new)
  IV.  SOLID Engineering (new)
  V.   DRY — Don't Repeat Yourself (new)
  VI.  YAGNI — High Standard, Not High Complexity (new)
  VII. Accessibility and Quality Compliance (new)

Added sections:
  - Platform Standards (subscription, licensing, visual identity)
  - Development Workflow (Spec Kit gates, independent review, deployment)

Removed sections: none

Templates updated:
  ✅ .specify/memory/constitution.md (this file)
  ✅ .specify/templates/plan-template.md — Constitution Check gates updated
  ⚠  .specify/templates/spec-template.md — no changes required; structure already compatible
  ⚠  .specify/templates/tasks-template.md — no changes required; accessibility task pattern is additive

Deferred items:
  - TODO(RATIFICATION_AUTHORITY): Solo project — owner (Camilo Borges) is sole ratifier.
    Recorded here for completeness; no formal approval process needed at this scale.
-->

# TheDarkFactory365 Constitution

## Core Principles

### I. Dark Factory Automation-First

Every solution MUST run without human intervention in its steady state. Automation is the default;
manual steps are the exception and MUST be explicitly justified.

- Alerts and notifications are push-based (system notifies the user); never pull-based (user checks
  a dashboard to find out if something happened)
- Zero manual steps are required between scheduled runs in steady state
- Configuration changes (location, settings, alert targets) take effect automatically on the next
  execution cycle — no restarts, no redeployments
- If a feature requires a human to kick it off every time, it is not done

### II. Microsoft 365 Platform-Native

All solutions MUST use official, supported Microsoft 365 extension points only. No workarounds,
no unsupported APIs, no hacks that could break on the next platform update.

- SharePoint customisations MUST use SharePoint Framework (SPFx) — no Script Editor web parts,
  no direct DOM manipulation, no injected JavaScript outside of SPFx
- UI components MUST use Microsoft Fluent UI (v8 for SPFx solutions) as the structural foundation;
  Dark Factory theming is applied as a SCSS overlay on top — never as a replacement
- Teams integrations MUST use the Teams JavaScript SDK as bundled with SPFx — never install a
  separate `@microsoft/teams-js` package
- Power Platform flows MUST use standard connectors where possible; premium connectors require
  explicit justification and confirmed licensing (see Platform Standards)
- The minimum Microsoft 365 subscription for any solution in this project is **Business Basic**;
  M365 Family is confirmed insufficient for SharePoint/SPFx deployment

### III. Spec-Driven Development

No implementation begins without an approved specification and plan. The Spec Kit workflow is
the mandatory development process for every feature.

- Every feature MUST have a `spec.md` reviewed and approved before `/speckit-plan` runs
- Every plan MUST include a `research.md` with all unknowns resolved before tasks are generated
- Specifications are written for business value (WHAT and WHY); plans address technology (HOW)
- An independent review MUST be conducted for any feature that involves platform-level assumptions
  (SPFx deployment, licensing, API integration, CSP configuration)
- The active feature pointer in `CLAUDE.md` MUST be updated to the current `plan.md` before
  implementation begins

### IV. SOLID Engineering

Code MUST follow SOLID principles. Each violation requires justification in the plan's Complexity
Tracking table.

- **Single Responsibility**: Every class, service, mapper, and component has exactly one job.
  Services fetch or read. Mappers transform. Components render. No cross-cutting logic.
- **Open/Closed**: New states, codes, or conditions are added by extending lookup tables or enums —
  not by modifying existing rendering or business logic branches.
- **Liskov Substitution**: Service interfaces MUST be substitutable; concrete implementations MUST
  not add preconditions not present in the interface contract.
- **Interface Segregation**: Services expose only what their consumers need. No god interfaces.
- **Dependency Inversion**: Components and services MUST depend on abstractions (interfaces),
  not concrete implementations. Dependencies are injected at the composition root (web part
  `onInit`) — never instantiated inside components.

### V. DRY — Don't Repeat Yourself

Every piece of knowledge MUST have a single, authoritative source. Duplication is a defect.

- Configuration values live in the SharePoint `DarkFactory-Settings` list — not in code, not in
  multiple places
- Domain lookup tables (e.g., WMO weather codes, forecast period boundaries, Dark Factory colour
  tokens) are defined once and imported; never copied
- Dark Factory colour palette tokens are defined in one SCSS file and imported everywhere; no
  colour hex value appears in more than one location
- If a constant, mapping, or rule appears in two places, one of them is wrong

### VI. YAGNI — High Standard, Not High Complexity

Build exactly what the spec requires. Complexity MUST be justified by a current, documented need.

- No speculative abstractions: multi-provider weather API adapters, multi-tenant support,
  plugin architectures, and similar constructs are forbidden unless a second concrete use case
  exists today
- No premature generalisation: three similar implementations are better than one wrong abstraction
- No backwards-compatibility shims for features not yet built
- Every architectural decision that adds complexity over the simplest working solution MUST be
  justified in the plan's Complexity Tracking table with a specific, current reason
- "We might need it later" is not a valid justification

### VII. Accessibility and Quality Compliance

All user-facing solutions MUST meet WCAG 2.1 AA and must pass Microsoft's platform quality
requirements before deployment.

- WCAG 2.1 AA is non-negotiable: minimum 4.5:1 contrast ratio for normal text, 3:1 for large text,
  full keyboard navigability, meaningful ARIA labels on all informational and interactive elements
- Colour palettes MUST be verified against WCAG 2.1 AA contrast requirements before implementation
  begins — not after; unverified palettes are not accepted into the spec
- All components MUST be tested with `jest-axe` (axe-core) as part of the unit test suite
- Solutions MUST pass Microsoft's SPFx technical validation requirements and Teams app guidelines
  before being considered deployable
- The Dark Factory visual identity (defined in Spec 001) MUST be applied consistently across all
  solutions; deviations require amendment to this constitution

---

## Platform Standards

### Subscription and Licensing Gate

Before any solution reaches the implementation phase, the following MUST be confirmed:

| Requirement | Minimum | Notes |
|---|---|---|
| Microsoft 365 subscription | Business Basic | M365 Family is insufficient for SPFx/SharePoint |
| SharePoint Admin role | Required | Needed for App Catalog, CSP, list permissions |
| Tenant App Catalog | Must exist | Create via `Register-PnPAppCatalogSite` if absent |
| Power Automate premium connectors | Power Automate Premium licence OR Azure Logic Apps | HTTP connector is premium; Logic Apps (consumption) is the cost-effective alternative |

Any feature spec that depends on a capability not confirmed as available in the current subscription
MUST document this as a BLOCKER in `research.md` before planning proceeds.

### Dark Factory Visual Identity

The Dark Factory visual identity is defined in `specs/001-weather-system/spec.md` (Visual Identity
section) and is the authoritative baseline for all solutions. Key constraints:

- Background: `#0D1117` | Surface: `#161B22` | Border: `#30363D`
- Primary text: `#F0F6FC` | Secondary text: `#9CA4B0` | Accent: `#22D3EE`
- Rain/alert indicator: `#3B82F6` | Warning: `#F59E0B`
- All WCAG 2.1 AA contrast ratios verified (see Spec 001 contrast table)
- Layout: card-based, bold numerals for primary data, monochrome line-art icons
- Typography: clean sans-serif; condition labels in sentence case; no decorative fonts

To amend the visual identity, update Spec 001 and increment this constitution version.

### External API and Integration Standards

- External API endpoints MUST be stored in the `DarkFactory-Settings` SharePoint list — never
  hardcoded
- The SharePoint tenant CSP allowlist MUST include all external domains called by client-side
  SPFx web parts (enforcement active as of March 2026)
- No premium Power Automate connectors without a confirmed paid plan or Azure Logic Apps
  alternative documented in `research.md`

---

## Development Workflow

### Spec Kit Gate Sequence

Every feature MUST pass through these gates in order. Skipping a gate requires documented
justification signed off by the project owner.

```
/speckit-specify  →  spec.md reviewed
/speckit-clarify  →  all ambiguities resolved
                  →  independent review for platform-level features
/speckit-plan     →  research.md complete (no NEEDS CLARIFICATION remaining)
                  →  subscription/licensing gate passed (RISK-001 pattern)
                  →  Constitution Check passed in plan.md
/speckit-tasks    →  tasks.md generated
/speckit-implement → implementation begins
```

### Constitution Check (required in every plan.md)

Every `plan.md` MUST include a Constitution Check section that explicitly verifies each principle:

| Principle | Gate question |
|---|---|
| I. Automation-First | Does every recurring operation run without manual triggering? |
| II. Platform-Native | Are all extension points official and supported (SPFx, Fluent UI, Teams SDK)? |
| III. Spec-Driven | Is spec.md approved and research.md complete before this plan? |
| IV. SOLID | Does every service/component have a single responsibility? Are dependencies injected? |
| V. DRY | Is every config value, lookup, and style token defined exactly once? |
| VI. YAGNI | Is every architectural decision justified by a current, documented need? |
| VII. Accessibility | Is WCAG 2.1 AA verified for the colour palette before implementation? |

A failing gate is a blocker. Violations must be listed in the Complexity Tracking table with
specific justification.

### Deployment Standards

- SPFx web parts MUST be deployed to the tenant App Catalog with `-SkipFeatureDeployment` for
  tenant-wide availability
- SharePoint pages hosting web parts MUST be in published state before being added as Teams tabs
- Teams tabs MUST use the native SharePoint tab type — not a generic Website/iframe tab
- All deployment steps MUST be documented in `quickstart.md` for the feature
- The `DarkFactory-Settings` list MUST have broken permission inheritance:
  Visitors (Read), Owners (Full Control)

---

## Governance

This constitution supersedes all other practices, preferences, and conventions within the
TheDarkFactory365 project.

**Amendment procedure**:
1. Identify the principle or section to change and the reason
2. Determine version bump: MAJOR (removal or redefinition), MINOR (addition or expansion),
   PATCH (clarification or wording)
3. Update this file; update the Sync Impact Report comment at the top
4. Propagate changes to dependent templates (plan-template, spec-template as needed)
5. Note the amendment in the active feature's `plan.md` Constitution Check if mid-feature

**Versioning**:
- MAJOR: backward-incompatible governance change — a previously valid solution would now violate
  the constitution
- MINOR: new principle or section added that does not invalidate prior solutions
- PATCH: clarification, wording, or example update with no semantic change

**Compliance review**:
- Every `plan.md` Constitution Check is a compliance review for that feature
- Independent platform reviews (as conducted for Spec 001) are RECOMMENDED for any feature
  involving new M365 platform capabilities not previously validated in this project

**Version**: 1.0.0 | **Ratified**: 2026-05-10 | **Last Amended**: 2026-05-10
