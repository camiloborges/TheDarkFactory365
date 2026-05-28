# Feature Specification: Outdoor Activity Weather Advisor

**Feature Branch**: `005-activity-weather-advisor`
**Created**: 2026-05-28
**Status**: Draft
**Scope Note**: A Power Apps canvas app backed by an AI-powered SK agent REST endpoint. Users submit an outdoor activity request; an automation workflow calls the agent for a weather suitability assessment; the result is stored in SharePoint and delivered as a Teams notification. Two automation paths are included: Option A (Logic App — included) and Option B (Power Automate — conditional on Premium licence confirmation, see RISK-001).

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Submit an Activity Request (Priority: P1)

As a DarkFactory tenant user, I want to submit an outdoor activity request (activity type, location, and date/time) through a Power Apps canvas app, so that I can get an AI-powered weather suitability assessment without opening any other tool.

**Why this priority**: This is the entry point for the entire feature. The form and SharePoint list can be developed and demonstrated independently of the automation paths — a submitted item with Status "Pending" proves the data model and the app work before any agent or workflow code exists.

**Independent Test**: Open the Power Apps canvas app, fill in Activity = "Trail Run", Location = "Wellington", RequestedDateTime = tomorrow at 08:00. Submit. Confirm a new item appears in the `DarkFactory-ActivityRequests` SharePoint list with Status = "Pending" and RequestedBy = current user.

**Acceptance Scenarios**:

1. **Given** the canvas app is open, **When** the user fills in Activity, Location, and RequestedDateTime and submits, **Then** a new item is created in `DarkFactory-ActivityRequests` with Status = "Pending", and the form clears ready for the next request.
2. **Given** the user submits without filling in a required field, **When** the form validates, **Then** the submission is blocked and a field-level error message is shown — no partial item is created in SharePoint.
3. **Given** a previous request is already in the list with Status = "Complete", **When** the user opens the app, **Then** their most recent assessment (RiskLevel + AssessmentReason) is displayed in a read-only results panel beneath the form.

---

### User Story 2 — Get an AI-Powered Weather Suitability Assessment (Priority: P2)

As a DarkFactory tenant user, I want the system to automatically assess whether my submitted activity is safe given the forecast weather conditions, so that I receive a structured risk verdict (Safe / Caution / Unsafe) with a plain-language reason — without me having to look up a weather service myself.

**Why this priority**: This is the core value proposition. It requires the SK agent endpoint, Open-Meteo integration, and at least one automation path (Option A) to be operational. Option B depends on licence confirmation (RISK-001).

**Independent Test**: POST `{ "activity": "Trail Run", "location": "Wellington", "datetime": "2026-05-29T08:00:00" }` to `POST /api/assess-activity` on the running SK agent. Confirm the response contains `{ "risk": "Safe"|"Caution"|"Unsafe", "reason": "<string>" }` with a reason that references actual forecast conditions, not stub data.

**Acceptance Scenarios**:

1. **Given** a new item with Status = "Pending" is created in `DarkFactory-ActivityRequests`, **When** the Logic App (Option A) trigger fires, **Then** it calls `POST /api/assess-activity` with the item's Activity, Location, and RequestedDateTime, and writes the returned RiskLevel and AssessmentReason back to the list item, setting Status = "Complete".
2. **Given** the SK agent receives a valid assess-activity request, **When** it calls Open-Meteo for the location's forecast, **Then** the ActivityAssessmentPlugin passes the real forecast conditions to GPT, which returns a structured `{ risk, reason }` JSON response — not a hardcoded stub value.
3. **Given** the SK agent cannot reach Open-Meteo (network error), **When** the assess-activity endpoint is called, **Then** it returns HTTP 502 with a structured error body; the Logic App writes Status = "Error" to the list item so the user knows the assessment failed.
4. **Given** Option B (Power Automate) is enabled and a Premium licence is confirmed, **When** a new SP list item triggers the PA flow, **Then** the flow calls `POST /api/assess-activity` via the HTTP connector and writes the result back — identical outcome to Option A.

---

### User Story 3 — Receive a Teams Notification with the Assessment Result (Priority: P3)

As a DarkFactory tenant user, I want to receive a Teams message when my activity assessment is complete, so that I don't have to poll the SharePoint list or the canvas app to find out the result.

**Why this priority**: Adds delivery value on top of the stored result, but the assessment is already useful without it. Uses standard Power Automate connectors only (no Premium required), so it is not gated by RISK-001.

**Independent Test**: Set a list item's Status to "Complete" manually. Confirm a Teams message arrives for the RequestedBy user within 2 minutes containing the RiskLevel and a summary of the AssessmentReason.

**Acceptance Scenarios**:

1. **Given** a `DarkFactory-ActivityRequests` item transitions to Status = "Complete", **When** the Power Automate notification flow triggers, **Then** a Teams message is sent to the RequestedBy user within 2 minutes, containing the Activity, Location, RiskLevel, and AssessmentReason.
2. **Given** the notification Power Automate flow runs, **When** the Teams message is composed, **Then** the RiskLevel is visually distinguished (e.g., "🔴 Unsafe", "🟡 Caution", "🟢 Safe") so the verdict is immediately readable.
3. **Given** the RequestedBy field does not resolve to a valid Teams user (e.g., a service account was used for testing), **When** the notification flow runs, **Then** it falls back to sending the message to the `ActivityAdvisor.NotificationRecipient` address configured in `DarkFactory-Settings`.

---

### Edge Cases

- What happens when Open-Meteo does not recognise the submitted location string? The agent should return `{ "risk": "Unsafe", "reason": "Could not retrieve forecast for the specified location — please check the location name." }` rather than crashing.
- What happens when the GPT model returns a non-JSON response or omits the required fields? The `ActivityAssessmentPlugin` must validate the structured output and return a safe fallback error response to the caller.
- What happens when the Logic App fires but the SK agent endpoint is unreachable (e.g., container not running)? The Logic App step should fail with a clear HTTP error, set Status = "Error" on the list item, and not retry indefinitely.
- What happens when a user submits two requests in quick succession? Each creates an independent SP list item and triggers an independent assessment — no deduplication or queuing is required for v1.
- What happens when `DarkFactory-ActivityRequests` does not yet exist (Spec 003 extension not yet run)? The canvas app shows an error on load and the Logic App deployment fails at the trigger step with a clear message pointing to the provisioning quickstart.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The SK agent MUST expose a `POST /api/assess-activity` minimal API endpoint accepting `{ activity: string, location: string, datetime: string }` and returning `{ risk: "Safe"|"Caution"|"Unsafe", reason: string }`.
- **FR-002**: The `ActivityAssessmentPlugin` MUST call the Open-Meteo forecast API using the location from the request, not hardcoded stub data.
- **FR-003**: The `ActivityAssessmentPlugin` MUST pass the retrieved forecast conditions and the activity type to the GPT model and parse the structured `{ risk, reason }` response.
- **FR-004**: The SK agent `WeatherPlugin` MUST be updated to use real Open-Meteo HTTP calls, replacing all city-hardcoded stub returns.
- **FR-005**: All NuGet package references in `SkWeatherAgent.csproj` MUST be pinned to explicit versions before the project is committed to TheDarkFactory365, so that the GHA CI build is deterministic.
- **FR-006**: The Power Apps canvas app MUST allow users to submit an activity request (Activity, Location, RequestedDateTime) which creates an item in `DarkFactory-ActivityRequests` with Status = "Pending".
- **FR-007**: The canvas app MUST validate that Activity, Location, and RequestedDateTime are all provided before allowing submission.
- **FR-008**: The `DarkFactory-ActivityRequests` SharePoint list MUST be provisioned by an extension to the Spec 003 provisioning script, with columns: Activity (Text), Location (Text), RequestedDateTime (DateTime), Status (Choice: Pending/Complete/Error), RiskLevel (Choice: Safe/Caution/Unsafe), AssessmentReason (Note), RequestedBy (Person).
- **FR-009**: The `DarkFactory-Settings` list MUST be extended with two new keys: `ActivityAdvisor.AgentEndpoint` (the SK agent base URL) and `ActivityAdvisor.NotificationRecipient` (fallback Teams recipient).
- **FR-010**: Option A — A Logic App (Consumption) MUST trigger when a new item is created in `DarkFactory-ActivityRequests`, call `POST /api/assess-activity`, and write RiskLevel, AssessmentReason, and Status = "Complete" back to the item.
- **FR-011**: Option A — The Logic App MUST set Status = "Error" on the list item if the SK agent call fails, rather than leaving Status = "Pending" indefinitely.
- **FR-012**: Option B — A Power Automate flow MAY implement the same trigger-and-assess pattern using the HTTP connector, conditional on Power Automate Premium licence availability (see RISK-001). If the licence is not available, Option B MUST be documented as a stub with implementation notes only.
- **FR-013**: A standard Power Automate flow (no premium connectors) MUST trigger when a `DarkFactory-ActivityRequests` item transitions to Status = "Complete" and send a Teams message to the RequestedBy user with the RiskLevel and AssessmentReason.
- **FR-014**: The Teams notification MUST visually distinguish the RiskLevel using colour or emoji so the verdict is immediately readable without reading the full reason text.
- **FR-015**: The SK agent MUST be deployable to Azure Container Apps (or equivalent) and its endpoint URL stored in `DarkFactory-Settings` so the Logic App / Power Automate flow can resolve it at runtime without hardcoded values.
- **FR-016**: The `POST /api/assess-activity` endpoint MUST bypass Bot Framework activity routing — it is a plain minimal API endpoint, not an agent activity handler.

### Key Entities

- **DarkFactory-ActivityRequests**: New SharePoint list. Columns: Activity (Text), Location (Text), RequestedDateTime (DateTime), Status (Choice: Pending/Complete/Error), RiskLevel (Choice: Safe/Caution/Unsafe), AssessmentReason (Note), RequestedBy (Person).
- **ActivityAssessmentPlugin**: New Semantic Kernel `KernelFunction` in `src/sk-weather-agent/Plugins/`. Takes activity type + Open-Meteo forecast → GPT reasoning → structured `{ risk, reason }` JSON.
- **SK Agent** (`src/sk-weather-agent/`): The sk-weather-agent-dotnet sample copied from research, extended with the new `ActivityAssessmentPlugin` and the `POST /api/assess-activity` endpoint.
- **Logic App (Option A)**: Extension of the existing `la-darkfactory-rain-alert` resource group pattern. Triggered by new SP list item, calls SK agent, writes result back.
- **Power Automate (Option B)**: Alternative to the Logic App using PA Premium HTTP connector. Conditional on RISK-001 resolution.
- **Canvas App**: Power Apps canvas app. Form UI for submitting activity requests. Reads assessment results from the same SP list.
- **Teams Notification Flow**: Standard Power Automate flow (no premium connectors). Triggered by Status change to "Complete". Sends adaptive card or text message to the RequestedBy user.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user submitting an activity request in the canvas app receives a RiskLevel and AssessmentReason in the SharePoint list within 3 minutes of submission — no manual steps required.
- **SC-002**: The Teams notification arrives within 2 minutes of the SP list item reaching Status = "Complete".
- **SC-003**: `POST /api/assess-activity` returns a valid `{ risk, reason }` response in under 10 seconds for any NZ city supported by Open-Meteo, when the GPT model is reachable.
- **SC-004**: The SK agent's `WeatherPlugin` returns real Open-Meteo data for any valid city name — no stub strings present in any response path.
- **SC-005**: The GHA CI pipeline passes a deterministic build of `src/sk-weather-agent/` with all NuGet versions pinned — no floating `Version="*"` references in the project file.
- **SC-006**: The canvas app blocks submission when any required field is empty — verified by attempting to submit with each field blank in turn.
- **SC-007**: The Spec 003 provisioning script extension creates `DarkFactory-ActivityRequests` idempotently — running it twice does not create duplicate lists or columns.

---

## Risks

### RISK-001 — Power Automate Premium Licence (Option B)

**Description**: The Option B automation path requires a Power Automate Premium licence because it uses the HTTP connector to call the SK agent REST endpoint. The HTTP connector is not available on the standard/seeded licence included with M365 Business Basic.

**Impact**: Premium licence is available. Option B ships as fully implemented Power Automate YAML. It cannot be end-to-end tested in the current environment (no live PA Premium environment at time of spec completion), so it is marked `[UNTESTED — requires PA Premium]` in quickstart.md and tasks.md.

**Resolution**: Power Automate Premium is available. Option B ships as working YAML with the HTTP connector. Testing gate: flow must be manually validated once a Premium environment is provisioned.

**Status**: RESOLVED — Option B ships. Marked untested pending Premium environment.

---

## Assumptions

- Spec 003 (Tenant Infrastructure) provisioning has been run at least once — the DarkFactory SharePoint site, App Catalog, and `DarkFactory-Settings` list already exist.
- The SK agent is hosted on **Azure Container Apps** (same resource group pattern as Spec 003). Its public ingress URL is written to `DarkFactory-Settings.ActivityAdvisor.AgentEndpoint` after deployment.
- **Azure OpenAI** is the target AI service (`UseAzureOpenAI: true`). The deployment name is `gpt-4o-mini` unless a different deployment is provisioned in the tenant's Azure OpenAI resource.
- The canvas app targets the existing DarkFactory SharePoint site — no new site provisioning is required.
- The Teams notification path uses standard Power Automate connectors only (SharePoint trigger + Teams message) and is not gated by RISK-001.
- Power Apps standard connectors (SharePoint) are sufficient for the canvas app — no premium connectors are required for the UI layer.
- The dual automation path (Option A + Option B) is intentional for portfolio/learning purposes and is accepted complexity per Spec 005 scope (Principle VI YAGNI justified — documented in plan Complexity Tracking).
- NuGet package versions in `src/sk-weather-agent/` are pinned to the latest stable versions available at plan time. Floating `Version="*"` references from the research sample are replaced before any CI pipeline runs against the project.
- **Open-Meteo geocoding**: Location strings from the canvas app are city names. The SK agent resolves them to lat/lon using the Open-Meteo Geocoding API (`https://geocoding-api.open-meteo.com/v1/search?name={city}&count=1`) before calling the forecast endpoint. No API key is required for either endpoint.
- **Endpoint authentication**: The `POST /api/assess-activity` endpoint is internal — exposed only within the Azure Container Apps ingress (not public internet). Logic App and Power Automate call it over private/VNet-scoped networking or with a managed identity header. For local development, the endpoint runs unauthenticated on `localhost:3978`.
- The canvas app reads assessments directly from the `DarkFactory-ActivityRequests` SharePoint list using the standard SharePoint connector — no additional data source is required.
