# Implementation Plan: Outdoor Activity Weather Advisor

**Branch**: `005-activity-weather-advisor` | **Date**: 2026-05-28 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/005-activity-weather-advisor/spec.md`

## Summary

A Power Apps canvas app lets users submit outdoor activity requests (activity, location, date/time). An Azure Logic App (Option A) — and a Power Automate Premium flow (Option B, untested) — trigger on the new SharePoint list item and call a Semantic Kernel agent REST endpoint (`POST /api/assess-activity`). The agent resolves the city to coordinates via Open-Meteo Geocoding, retrieves the forecast, and uses GPT (Azure OpenAI `gpt-4o-mini`) to reason about suitability, returning `{ risk: Safe|Caution|Unsafe, reason }`. The result is written back to `DarkFactory-ActivityRequests` and delivered to the user as a Teams message via a standard Power Automate notification flow.

## Technical Context

**Language/Version**: C# / .NET 8 (SK agent); PowerShell 7 (provisioning extension); JSON (Logic App definition); Power Automate YAML (PA flows)
**Primary Dependencies**: Microsoft.SemanticKernel 1.29.0, Microsoft.Agents.Hosting.AspNetCore 1.1.0, PnP.PowerShell (tenant-infra extension)
**Storage**: SharePoint Online (`DarkFactory-ActivityRequests` list, `DarkFactory-Settings` list)
**Testing**: Manual via `curl` (SK agent endpoint); manual via canvas app + Logic App run history (E2E). No automated test project for this spec — agent code is a demo artefact.
**Target Platform**: Azure Container Apps (SK agent), Azure Logic Apps Consumption (Option A), Power Automate (Option B — untested), Power Apps (canvas app)
**Project Type**: Multi-component M365/Azure integration — REST agent + automation orchestration + low-code UI
**Performance Goals**: `POST /api/assess-activity` responds in under 10 seconds (Open-Meteo + GPT round-trip). Logic App trigger fires within 60 seconds of item creation.
**Constraints**: NuGet versions pinned (no `Version="*"`). Option B ships as YAML only — not end-to-end testable without PA Premium environment. Canvas app `.msapp` not generated (documented as YAML export / screen-by-screen spec).
**Scale/Scope**: Demo/portfolio scale — single tenant, single user at a time. No rate limiting or queuing required for v1.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Verify each principle from `.specify/memory/constitution.md`. A failing gate is a blocker —
document violations in the Complexity Tracking table with specific justification.

| Principle | Gate question | Status |
|---|---|---|
| I. Automation-First | Does every recurring operation run without manual triggering? | ✅ Both automation paths are trigger-driven (SP item creation). Teams notification is push-based. |
| II. Platform-Native | Are all extension points official and supported (SPFx, Fluent UI, Teams SDK)? | ✅ SK agent uses official M365 Agents SDK + SK. Canvas app uses standard Power Apps + SP connector. Logic App uses official Azure connector. PA uses official HTTP connector (Premium, confirmed). |
| III. Spec-Driven | Is spec.md approved and research.md complete before this plan? | ✅ spec.md written, clarified, and committed. research.md complete. |
| IV. SOLID | Does every service/component have a single responsibility? Are dependencies injected? | ✅ `WeatherPlugin` (weather data), `ActivityAssessmentPlugin` (reasoning) — each has a single concern. `HttpClient` injected via DI. |
| V. DRY | Is every config value, lookup, and style token defined exactly once? | ✅ `AgentEndpoint` stored once in `DarkFactory-Settings`. API key stored once in Logic App parameters / PA env var. WMO code descriptions defined once in the plugin helper. |
| VI. YAGNI | Is every architectural decision justified by a current, documented need? | ⚠️ **Accepted violation**: dual automation path (Option A + B) adds complexity. Justified — explicitly a learning/portfolio spec. Documented in Complexity Tracking. |
| VII. Accessibility | Is WCAG 2.1 AA verified for the colour palette before implementation? | ✅ Canvas app uses default Power Apps system palette (tested by Microsoft). Risk level emoji indicators (🟢🟡🔴) supplement, not replace, text labels. |
| Platform Gate | Is the M365 subscription (Business Basic+) and licensing confirmed? | ✅ Business Basic confirmed for base M365. Power Automate Premium confirmed for Option B. |

## Project Structure

### Documentation (this feature)

```text
specs/005-activity-weather-advisor/
├── plan.md                            # This file
├── spec.md                            # Feature specification
├── research.md                        # Technical decisions
├── data-model.md                      # SP list schema, SK agent models
├── quickstart.md                      # Run + test instructions
├── contracts/
│   ├── assess-activity-endpoint.md   # POST /api/assess-activity contract
│   ├── open-meteo-api.md             # Open-Meteo geocoding + forecast contracts
│   └── sharepoint-activity-list.md   # DarkFactory-ActivityRequests list contract
└── tasks.md                           # Implementation tasks
```

### Source Code

```text
src/
├── sk-weather-agent/                  # SK agent (.NET 8 minimal API)
│   ├── SkWeatherAgent.csproj          # NuGet deps (pinned)
│   ├── Program.cs                     # Host + POST /api/assess-activity endpoint
│   ├── WeatherAgent.cs                # Bot Framework agent (existing chat path)
│   ├── appsettings.json               # AI service + ActivityAdvisor config keys
│   ├── appsettings.Development.json   # Local dev overrides
│   ├── Plugins/
│   │   ├── WeatherPlugin.cs           # Wired to Open-Meteo (replaces stubs)
│   │   └── ActivityAssessmentPlugin.cs  # New — activity suitability reasoning
│   └── Properties/launchSettings.json
├── activity-advisor/                  # Logic App + PA flows + canvas app export
│   ├── logic-app-definition.json      # Option A — Logic App Consumption workflow
│   ├── flows/
│   │   ├── darkfactory-activity-assessment-optionb.yml  # PA Premium (UNTESTED)
│   │   └── darkfactory-activity-notification.yml        # Teams notification (standard)
│   ├── canvas-app/
│   │   └── DarkFactoryActivityAdvisor.yaml              # Canvas app screen export
│   └── deploy/
│       ├── activity-advisor-logic-app.json              # ARM template
│       └── activity-advisor-parameters.json.template    # Deployment parameters template
└── tenant-infra/
    ├── Invoke-DarkFactoryProvisioning.ps1               # Extended (calls new module)
    └── modules/
        └── DarkFactory.ActivityAdvisor.psm1             # New — provisions ActivityRequests list + Settings keys
```

**Structure Decision**: Multi-component layout. The SK agent extends the existing `src/sk-weather-agent/` copy. A new `src/activity-advisor/` directory holds all the automation and UI artefacts for this feature, keeping them separate from the existing `src/rain-alert/` (Spec 002). The Spec 003 provisioning module pattern is extended with a new `DarkFactory.ActivityAdvisor.psm1` module.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Dual automation path (Option A Logic App + Option B Power Automate) | Explicit portfolio/learning goal — demonstrate both orchestration engines side-by-side | Single path would miss the portfolio differentiation; YAGNI exception documented in spec |
| New `src/activity-advisor/` directory alongside existing `src/rain-alert/` | Spec 005 artefacts are distinct from Spec 002 rain alert logic — mixing them would make the feature boundary unclear | Combining into `src/rain-alert/` would violate single-responsibility and confuse the portfolio narrative |

---

## Key Design Decisions

| Decision | Choice | Rationale ref |
|---|---|---|
| Agent hosting | Azure Container Apps (Consumption) | research.md #1 |
| Geocoding | Open-Meteo free geocoding API | research.md #2 |
| GPT output format | JSON schema mode `{ risk, reason }` | research.md #3 |
| Endpoint pattern | Minimal API `MapPost`, not Bot Framework | research.md #4 |
| NuGet pinning | Explicit versions, no `Version="*"` | research.md #5 |
| Logic App billing | Consumption plan, `rg-darkfactory` | research.md #6 |
| Option B status | Ships as YAML, marked UNTESTED | research.md #7 |
| Teams notification | Standard PA connectors only | research.md #8 |
| Canvas app connectivity | Standard SharePoint connector | research.md #9 |

---

## Spec Drift Sync Checkpoint

> **Complete this section before opening a PR — required by the Spec Drift Policy (constitution v1.1.0+)**

After implementation, verify each artifact is accurate against the code. Check the box when confirmed or note the update made.

| Artifact | Status | Notes |
|---|---|---|
| `contracts/assess-activity-endpoint.md` — param block, output contract, example invocations | ☑ verified | Matches Program.cs endpoint implementation |
| `contracts/open-meteo-api.md` — API URLs, response shapes | ☑ verified | Matches WeatherPlugin.cs URL patterns |
| `contracts/sharepoint-activity-list.md` — column definitions, provisioning script | ☑ verified | Matches DarkFactory.ActivityAdvisor.psm1 |
| `quickstart.md` — run instructions, prereqs, verification checklist | ☑ verified | All paths and commands reflect final structure |
| `plan.md` — Project Structure matches actual directory layout | ☑ verified | All files created as specified |
| `plan.md` — Constitution Check notes reflect final design | ☑ verified | All gates evaluated above |
| `tasks.md` — post-implementation changes recorded as completed tasks | ☑ verified | All 20 tasks implemented |
