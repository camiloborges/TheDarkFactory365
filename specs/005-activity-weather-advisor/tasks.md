# Tasks: Outdoor Activity Weather Advisor

**Input**: Design documents from `specs/005-activity-weather-advisor/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel with other [P] tasks in the same phase (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1/US2/US3)

---

## Phase 1: Setup — Project Infrastructure

**Purpose**: Create new directories and pin NuGet versions before any feature code is written.

- [x] T001 [US1/US2/US3] Create `src/activity-advisor/` directory structure: `flows/`, `canvas-app/`, `deploy/` subdirectories
- [x] T002 [US2] Pin NuGet packages in `src/sk-weather-agent/SkWeatherAgent.csproj` — replace all `Version="*"` with explicit pinned versions per research.md Decision 5
- [x] T003 [US2] Add `ActivityAdvisor` config section to `src/sk-weather-agent/appsettings.json` — keys: `ApiKey`, `AgentEndpoint` (for reference)

**Checkpoint**: Directory structure in place, project builds with pinned deps

---

## Phase 2: Foundations — Shared Infrastructure

**Purpose**: Provisioning module and SP list must exist before automation paths or the canvas app can function.

- [x] T004 [US1] Create `src/tenant-infra/modules/DarkFactory.ActivityAdvisor.psm1` — idempotent provisioning of `DarkFactory-ActivityRequests` list with all 8 columns per `contracts/sharepoint-activity-list.md`
- [x] T005 [US1] Add `ActivityAdvisor.AgentEndpoint` and `ActivityAdvisor.NotificationRecipient` seed rows to the `DarkFactory-Settings` provisioning in `DarkFactory.ActivityAdvisor.psm1`
- [x] T006 [US1] Register `DarkFactory.ActivityAdvisor.psm1` in `src/tenant-infra/Invoke-DarkFactoryProvisioning.ps1` — import module, call provisioning function

**Checkpoint**: Run `Invoke-DarkFactoryProvisioning.ps1` — `DarkFactory-ActivityRequests` list appears in SharePoint with correct columns, `DarkFactory-Settings` has two new rows

---

## Phase 3: User Story 2 (P1 implementation priority) — SK Agent 🎯 MVP

> US2 is implemented first because it is the core backend that unblocks both automation paths (US2 acceptance) and is independently testable with `curl` before any other component exists.

**Goal**: `POST /api/assess-activity` returns real weather-based risk assessment.

**Independent Test**: `curl -X POST http://localhost:3978/api/assess-activity -H "Content-Type: application/json" -H "X-Api-Key: dev-key-123" -d '{"activity":"Trail Run","location":"Wellington","datetime":"2026-05-29T08:00:00"}'` returns `{ "risk": "Safe"|"Caution"|"Unsafe", "reason": "..." }` with a reason referencing real forecast data.

- [x] T007 [US2] Update `src/sk-weather-agent/Plugins/WeatherPlugin.cs` — replace hardcoded city stubs with real Open-Meteo HTTP calls (geocoding + forecast) per `contracts/open-meteo-api.md`. Inject `HttpClient` via constructor. Implement `DescribeWeatherCode()` helper.
- [x] T008 [P] [US2] Create `src/sk-weather-agent/Plugins/ActivityAssessmentPlugin.cs` — new `KernelFunction` that takes `activity`, `location`, `datetime`; calls Open-Meteo geocoding → forecast → selects hourly slot nearest to requested datetime; calls GPT with structured prompt; parses `{ risk, reason }` JSON response per research.md Decision 3
- [x] T009 [US2] Add `POST /api/assess-activity` minimal API endpoint to `src/sk-weather-agent/Program.cs` — register `ActivityAssessmentPlugin` in DI, validate `X-Api-Key` header (bypass in Development env), call plugin, return JSON response or structured error body per `contracts/assess-activity-endpoint.md`
- [x] T010 [P] [US2] Register `ActivityAssessmentPlugin` as singleton in `src/sk-weather-agent/Program.cs` DI setup alongside existing `WeatherPlugin`

**Checkpoint**: `curl` test returns real data for Wellington. Unknown city returns `{ "error": "geocoding_failed" }`.

---

## Phase 4: User Story 1 — Canvas App

**Goal**: User can submit an activity request from Power Apps; new SP list item appears with `Status = Pending`.

**Independent Test**: Open canvas app, submit Activity="Hiking", Location="Auckland", RequestedDateTime=tomorrow 09:00. Verify new item in `DarkFactory-ActivityRequests` with `Status=Pending` and correct field values.

- [x] T011 [US1] Create `src/activity-advisor/canvas-app/DarkFactoryActivityAdvisor.yaml` — canvas app screen export with Submit screen (activity dropdown, location text, datetime picker, Submit button using `Patch()`) and Results gallery (current user's last 5 requests showing Status/RiskLevel/AssessmentReason)
- [x] T012 [US1] Document canvas app PowerFx formulas in `src/activity-advisor/canvas-app/DarkFactoryActivityAdvisor.yaml` — `Patch()` on submit, `Filter()` + `Sort()` for results gallery, `User().Email` for RequestedBy, field-level validation (all three fields required)

**Checkpoint**: Canvas app YAML export committed. Import and connect to SP list per quickstart Step 5.

---

## Phase 5: User Story 2 (automation paths) — Logic App A + Power Automate B

**Goal**: Automation triggers on `Pending` items, calls SK agent, writes assessment back to SP list.

**Independent Test (Option A)**: With SK agent running and LA deployed and enabled, create a new item in `DarkFactory-ActivityRequests` with Status=Pending. Within 60 seconds, the Logic App run history shows a successful run and the item has `Status=Complete`, `RiskLevel` and `AssessmentReason` populated.

- [x] T013 [US2] Create `src/activity-advisor/logic-app-definition.json` — Logic App Consumption workflow: SP trigger (When item created, DarkFactory-ActivityRequests), HTTP POST to agent, Parse JSON response, Update SP item (RiskLevel, AssessmentReason, Status=Complete), Error scope sets Status=Error per research.md Decision 6 and `contracts/assess-activity-endpoint.md`
- [x] T014 [P] [US2] Create `src/activity-advisor/deploy/activity-advisor-logic-app.json` — ARM template for Logic App deployment to `rg-darkfactory`
- [x] T015 [P] [US2] Create `src/activity-advisor/deploy/activity-advisor-parameters.json.template` — deployment parameters template (SharePointSiteUrl, ActivityAdvisorApiKey as securestring, AgentEndpointUrl)
- [x] T016 [P] [US2] `[UNTESTED — requires PA Premium]` Create `src/activity-advisor/flows/darkfactory-activity-assessment-optionb.yml` — Power Automate cloud flow YAML with HTTP connector: same trigger/action pattern as Option A per research.md Decision 7

**Checkpoint (Option A)**: Logic App deployed, authorised, enabled. End-to-end test per Independent Test above.

---

## Phase 6: User Story 3 — Teams Notification Flow

**Goal**: Teams message sent to requester within 2 minutes of `Status = Complete`.

**Independent Test**: Manually set a `DarkFactory-ActivityRequests` item to `Status=Complete`. Confirm Teams message arrives within 2 minutes containing RiskLevel (with emoji) and AssessmentReason.

- [x] T017 [US3] Create `src/activity-advisor/flows/darkfactory-activity-notification.yml` — Power Automate flow YAML: SP trigger (When item modified, filter Status eq 'Complete'), Teams post message action with emoji risk indicator (🟢/🟡/🔴), fallback to NotificationRecipient from DarkFactory-Settings if RequestedBy does not resolve per research.md Decision 8

**Checkpoint**: Flow imported, connected, enabled. Manual status update to Complete triggers Teams message.

---

## Phase 7: Polish & Cross-Cutting

- [x] T018 [P] [US1/US2/US3] Update `specs/005-activity-weather-advisor/plan.md` Spec Drift Sync Checkpoint — verify all contracts, quickstart, and plan.md Project Structure match actual implementation
- [x] T019 [P] [US1/US2/US3] Verify `quickstart.md` Step 1–6 reflects final implementation details — update any paths or commands that changed during implementation
- [x] T020 [US2] Update `src/sk-weather-agent/README.md` — add section documenting the new `POST /api/assess-activity` endpoint, `ActivityAssessmentPlugin`, and updated Open-Meteo wiring

---

## Dependencies

```
T001 (dirs) → T004, T011, T013, T017
T002 (pinned deps) → T007, T008, T009, T010 (agent must build)
T003 (appsettings) → T009 (endpoint reads ActivityAdvisor:ApiKey)
T004, T005, T006 (SP list) → T011 (canvas app targets the list), T013 (LA trigger targets the list)
T007, T008, T010 → T009 (endpoint depends on both plugins registered)
T009 (endpoint live) → T013 (LA calls the endpoint)
T013 → T014, T015 (ARM template wraps the definition)
T016 (PA Option B) — parallel with T013, independent of deployment scripts
T009 (agent assessed items) → T017 (notification triggers on Status=Complete)
```

## Parallel execution (same phase, different files)

Phase 3: T008 (ActivityAssessmentPlugin) and T010 (DI registration scaffold) can be drafted in parallel — T009 needs both to be complete.

Phase 5: T014 (ARM template) and T015 (parameters template) and T016 (PA Option B) can all be written in parallel with T013.

## Implementation strategy

**MVP** (minimum to prove the value loop): T001 → T002 → T003 → T004–T006 → T007–T010 → T013
That gives: provisioned SP list + running SK agent endpoint + triggering Logic App = full US2 story working end-to-end.

US1 (canvas app) and US3 (Teams notification) are additive layers that can follow.

## Task summary

| Phase | Tasks | User story |
|---|---|---|
| 1 — Setup | T001–T003 | All |
| 2 — Foundations | T004–T006 | US1 |
| 3 — SK Agent | T007–T010 | US2 |
| 4 — Canvas App | T011–T012 | US1 |
| 5 — Automation | T013–T016 | US2 |
| 6 — Notification | T017 | US3 |
| 7 — Polish | T018–T020 | All |

**Total**: 20 tasks | **MVP scope**: T001–T010 + T013 (11 tasks)
