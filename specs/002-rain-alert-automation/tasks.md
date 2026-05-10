# Tasks: Rain Alert Automation

**Input**: Design documents from `specs/002-rain-alert-automation/`
**Plan**: [plan.md](plan.md) | **Spec**: [spec.md](spec.md)
**Platform**: Azure Logic Apps (Consumption plan) + SharePoint standard connector + Teams standard connector

---

## Phase 1: Setup

**Purpose**: Project scaffold, ARM templates, and deployment scripts — no Azure resources yet.

- [X] T001 Create `rain-alert/` directory structure with `connections/`, `deploy/` subdirectories per plan.md project structure
- [X] T002 [P] Write `rain-alert/connections/sharepoint-connection.json` ARM template for SharePoint OAuth managed connection (resource type: `Microsoft.Web/connections`, API: `sharepointonline`)
- [X] T003 [P] Write `rain-alert/connections/teams-connection.json` ARM template for Teams OAuth managed connection (resource type: `Microsoft.Web/connections`, API: `teams`)
- [X] T004 [P] Write `rain-alert/deploy/Deploy-AlertInfrastructure.ps1`: `az group create --name rg-darkfactory`, `az logic workflow create --name la-darkfactory-rain-alert` (Consumption plan, australiaeast), deploy connection ARM templates via `az deployment group create`
- [X] T005 [P] Write `rain-alert/deploy/Invoke-AlertSeedData.ps1`: idempotent PnP PowerShell script to (1) create `DarkFactory-AlertState` list + `LastSentAt` DateTime column + seed `ForecastRain` / `CurrentRain` items; (2) add `Alert.*` rows to `DarkFactory-Settings` (skip-if-exists per Spec 003 pattern) — per data-model.md seed tables

---

## Phase 2: Foundational

**Purpose**: Azure resources live, connections authorised, SharePoint data ready. Logic App workflow scaffolded with shared actions used by all branches.

**⚠ CRITICAL**: No Logic App branch work can begin until connections are authorised and SharePoint data is in place.

- [ ] T006 Run `rain-alert/deploy/Deploy-AlertInfrastructure.ps1` — creates `rg-darkfactory` resource group and `la-darkfactory-rain-alert` Logic App (Consumption plan) with empty workflow; verify in Azure portal
- [ ] T007 Authorise SharePoint and Teams OAuth connections in Azure Logic App designer (admin Camilo Borges signs in to each connection once); confirm both connections show as "Connected" in portal — per quickstart.md
- [ ] T008 Run `rain-alert/deploy/Invoke-AlertSeedData.ps1` — verify `DarkFactory-AlertState` list exists with `ForecastRain` and `CurrentRain` items; verify all four `Alert.*` rows present in `DarkFactory-Settings`
- [X] T009 Write `rain-alert/logic-app-definition.json` workflow scaffold: Recurrence trigger (every 5 minutes), `Initialize Variable` action for `rainCodes` array (`[51,53,55,56,57,61,63,65,66,67,80,81,82,95,96,99]`), `Initialize Variable` action for `wmoLabels` object (WMO code → label map from data-model.md), `HTTP GET` Open-Meteo action with parameters from data-model.md D-006, `Parse JSON` action on HTTP response
- [X] T010 Add SharePoint reads to `rain-alert/logic-app-definition.json`: `Get items` action for `DarkFactory-Settings` (OData filter: `startswith(Title,'Weather.') or startswith(Title,'Alert.')`); `Get items` action for `DarkFactory-AlertState` (no filter); deploy updated workflow and confirm first run succeeds with HTTP 200 from Open-Meteo

**Checkpoint**: Logic App runs every 5 minutes, reads Open-Meteo, reads SharePoint config and state, logs run history. No alert logic yet.

---

## Phase 3: User Story 2 — Current Rain Alert (Priority: P2)

**Goal**: Real-time rain detection end-to-end. Implemented before US1 (P1) because it validates the complete pipeline — API → SharePoint read → condition check → Teams message → state update — with the simplest possible logic (single weather code check). US1 (forecast) extends this validated pipeline.

**Independent Test**: Set `Alert.CurrentRainSuppressionHours = 0` in DarkFactory-Settings. Trigger the Logic App manually twice. Confirm Teams private message received on first trigger. Confirm no Teams message on second trigger within 1 minute (suppress). Restore suppression to 1 hour.

- [X] T011 [US2] Add current rain suppression check to current rain branch in `rain-alert/logic-app-definition.json`: extract `CurrentRain` item's `LastSentAt` from AlertState response; null-safe suppression condition: `if(equals(lastSentAt,null),true,less(addHours(lastSentAt,int(suppressionHours)),utcNow()))` — per data-model.md null handling note
- [X] T012 [US2] Add current weather code condition: `contains(variables('rainCodes'), int(body('Parse_Weather')['current']['weather_code']))` — evaluates WMO code from Open-Meteo current response against rainCodes variable
- [X] T013 [US2] Add Teams "Post a message (V3)" action (1:1 chat, recipient = `Alert.RecipientId` setting, message = current rain format from data-model.md Teams Message Formats) inside the True branch of the current rain condition
- [X] T014 [US2] Add SharePoint "Update item" action: site = DarkFactory, list = `DarkFactory-AlertState`, item ID = CurrentRain item ID, `LastSentAt` = `@{utcNow()}` — executes only after Teams message succeeds
- [ ] T015 [US2] Deploy updated `logic-app-definition.json`; manually trigger Logic App from Azure portal; verify run history shows all actions Succeeded; verify Teams private message received; wait 1 minute, trigger again, verify no second Teams message (suppression active)

**Checkpoint**: Current rain alerts delivered and suppressed correctly. Full pipeline validated.

---

## Phase 4: User Story 1 — Forecast Rain Alert (Priority: P1)

**Goal**: Proactive forecast rain detection added as a parallel branch. Builds on the validated US2 pipeline. Uses Filter array (built-in, free) instead of For Each (per independent consultant review FINDING-3).

**Independent Test**: On a day when rain is forecast (or by temporarily setting WMO codes to include code 0 = clear sky), trigger Logic App manually with `Alert.ForecastSuppressionHours = 0`. Confirm forecast Teams message received. Restore suppression to 3 hours and trigger again — confirm no second message within 3 hours.

- [X] T016 [US1] Add forecast rain suppression check in a parallel branch to `rain-alert/logic-app-definition.json`: extract `ForecastRain` item's `LastSentAt` from AlertState response; same null-safe suppression condition using `Alert.ForecastSuppressionHours` value
- [X] T017 [US1] Add current local hour extraction: `Compose` action to parse hour from `body('Parse_Weather')['current']['time']` using `int(formatDateTime(outputs('Parse_Weather')['current']['time'], 'H'))`; `Compose` action to slice hourly codes: `skip(body('Parse_Weather')['hourly']['weather_code'], outputs('Get_Current_Hour'))`
- [X] T018 [US1] Add `Filter array` action (Logic Apps built-in, no charge) on sliced hourly codes: filter expression `contains(variables('rainCodes'), int(item()))` — returns array of rain-code entries from today's remaining + tomorrow's forecast hours; no For Each loop (per consultant Finding 3)
- [X] T019 [US1] Add condition: `length(body('Filter_Forecast_Codes')) > 0`; on True: set variable `forecastRainCode` = `first(body('Filter_Forecast_Codes'))`
- [X] T020 [US1] Add Teams "Post a message (V3)" action for forecast rain alert (forecast message format from data-model.md, including forecastRainCode label from wmoLabels variable) inside the True branch
- [X] T021 [US1] Add SharePoint "Update item" action: DarkFactory-AlertState → ForecastRain → `LastSentAt = @{utcNow()}`; deploy updated `logic-app-definition.json`; verify both parallel branches appear in run history; confirm forecast and current rain branches operate independently

**Checkpoint**: Both alert types work end-to-end. Forecast and current rain branches run in parallel. Each has independent suppression state.

---

## Phase 5: User Story 3 — Reliability and Error Handling (Priority: P3)

**Goal**: Error handling configured; run recovery verified; 30-day history confirmed.

**Independent Test**: Temporarily configure an invalid Open-Meteo URL, trigger the Logic App, confirm the run shows Failed in history but no crash or exception escapes. Restore correct URL, trigger again, confirm Succeeded — no manual intervention required between the two runs.

- [X] T022 [US3] Wrap all post-trigger actions in a `Scope` action named `Main` in `rain-alert/logic-app-definition.json`; add `Catch` scope (Run After: Main with statuses `Failed`, `TimedOut`) — Catch body logs run as failed via a `Terminate` action with status `Failed` and descriptive message
- [X] T023 [US3] Set HTTP Open-Meteo action `retryPolicy` in workflow JSON: `type: exponential`, `count: 3`, `interval: PT20S`, `maximumInterval: PT600S` — per data-model.md D-010
- [X] T024 [US3] Set SharePoint and Teams connector actions `retryPolicy`: `type: fixed`, `count: 2`, `interval: PT30S`
- [ ] T025 [US3] Verify run history retention in Azure portal (Logic Apps Consumption default = 90 days; confirm exceeds FR-011 requirement of 30 days); perform recovery test per independent test above; confirm SC-005 met (recovery within one polling cycle ≤ 5 minutes)

**Checkpoint**: All three user stories functional. Error handling confirmed. System self-recovers without manual intervention.

---

## Phase 6: Polish

**Purpose**: End-to-end suppression test, documentation verification, final clean-up.

- [ ] T026 End-to-end suppression window test: set `Alert.CurrentRainSuppressionHours = 0`, trigger twice in 60 seconds — confirm both send alerts; restore to `1`, trigger twice — confirm second is suppressed; repeat for `Alert.ForecastSuppressionHours` (set to `0`, trigger twice, both send; restore to `3`)
- [X] T027 Verify `specs/002-rain-alert-automation/quickstart.md` deployment steps match final script parameter names, Logic App resource names, and portal steps; update any discrepancies
- [X] T028 [P] Confirm `rain-alert/logic-app-definition.json` is clean and committed with inline comments for each action group; verify run history shows 7 consecutive Succeeded runs in Azure portal

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No external dependencies — start immediately after branch checkout
- **Foundational (Phase 2)**: Depends on Phase 1 completion — BLOCKS all alert branch work
- **US2 (Phase 3)**: Depends on Foundational completion — validates full pipeline before US1
- **US1 (Phase 4)**: Depends on Foundational completion — parallel branch added after US2 pipeline validated
- **US3 (Phase 5)**: Depends on Foundational + US1 + US2 (wraps the completed workflow in error handling)
- **Polish (Phase 6)**: Depends on all user stories complete

### Implementation Order Rationale

US2 (Phase 3) is implemented before US1 (Phase 4) despite US1 being higher priority in the spec. Reason: US2 (single weather code check) validates the complete pipeline (HTTP → SharePoint → condition → Teams → state update) with minimal complexity. US1 (hourly array slicing + Filter array) adds complexity on top of the validated foundation. Implementing US2 first de-risks US1.

### Parallel Opportunities Within Phases

- **Phase 1**: T002, T003, T004, T005 can all run in parallel (different files)
- **Phase 2**: T006 → T007 → T008 → T009 → T010 must be sequential (each depends on previous)
- **Phase 3**: T011 → T012 → T013 → T014 are sequential (same JSON file, dependent chain)
- **Phase 4**: T016 and T017 can begin in parallel (different sections of JSON); T018 depends on T017
- **Phase 6**: T027 and T028 can run in parallel (different files)

---

## Parallel Execution Example: Phase 1

```
# All four tasks can start simultaneously:
Task T002: rain-alert/connections/sharepoint-connection.json
Task T003: rain-alert/connections/teams-connection.json
Task T004: rain-alert/deploy/Deploy-AlertInfrastructure.ps1
Task T005: rain-alert/deploy/Invoke-AlertSeedData.ps1
```

---

## Implementation Strategy

### MVP (US2 — Current Rain Alert Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all work)
3. Complete Phase 3: US2 — Current Rain Alert
4. **STOP and validate**: Real-time rain detection works end-to-end
5. Enable Logic App in Azure; monitor for 1 day on a real rain event

### Full Delivery

1. Phase 1 + 2: Foundation
2. Phase 3: US2 → validate current rain alerts
3. Phase 4: US1 → validate forecast rain alerts  
4. Phase 5: US3 → confirm error handling
5. Phase 6: Polish → 7-day stability observation

---

## Notes

- All Logic App action changes are to `rain-alert/logic-app-definition.json` — JSON changes are sequential within a phase
- `[P]` tasks involve different files with no shared dependencies
- No automated tests (not requested in spec); manual trigger + portal run history is the test surface
- After any workflow JSON change, redeploy via `az logic workflow update` and verify the next scheduled run succeeds
- The Logic App trigger interval (5 minutes) is set at design time — if `Alert.PollingIntervalMinutes` is changed in SharePoint settings, the Logic App trigger must also be updated manually in the portal (per FR-008 exception, documented in spec clarifications)
