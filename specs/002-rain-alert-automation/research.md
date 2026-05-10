# Research: Rain Alert Automation
**Branch**: `002-rain-alert-automation` | **Date**: 2026-05-10

---

## Risks

### RISK-001: Azure Subscription Prerequisite
**Severity**: Medium | **Status**: ACCEPTED — prerequisite documented

Azure Logic Apps is an Azure service, not an M365 service. The `aiwhisperer.onmicrosoft.com` tenant needs a linked Azure subscription to create Logic Apps resources.

**Mitigation**: Azure Pay-As-You-Go subscription linked to the tenant. At 5-minute polling with ~12-15 actions per run, estimated monthly cost is $0.50–$2.00 (HTTP built-in actions are free; Teams and SharePoint managed connector actions are billed per execution at ~$0.000125/action). Document as prerequisite in quickstart.md. Accept as necessary cost for a personal automation solution.

### RISK-002: Power Automate HTTP Connector (Premium)
**Severity**: High | **Status**: RESOLVED — Azure Logic Apps used

The Open-Meteo API call requires an HTTP action. In Power Automate, the HTTP connector is premium — not included in M365 Business Basic. Azure Logic Apps (Consumption plan) includes HTTP as a **built-in** connector (not billed per action). Standard SharePoint and Teams connectors are identical between Power Automate and Logic Apps.

**Resolution**: Use Azure Logic Apps (Consumption plan) instead of Power Automate. See D-002.

### RISK-003: Teams 1:1 Private Message from Logic Apps
**Severity**: Low | **Status**: RESOLVED

Concern was that sending private Teams chat messages from Logic Apps might require a chat ID lookup via Graph API (premium HTTP call). Research confirmed the Teams standard managed connector includes "Post message in a chat or channel (V3)" which supports 1:1 chat by specifying the recipient UPN directly. No Graph API call needed.

**Resolution**: Use Teams standard connector action "Post message in a chat or channel (V3)" with chat type "1:1 chat" and `Alert.RecipientId` as the recipient. See D-008.

### RISK-004: Hourly Forecast Date/Time Evaluation
**Severity**: Low | **Status**: RESOLVED

Evaluating which hourly forecast entries fall in "today's remaining hours" vs "tomorrow's hours" requires knowing the current local hour. Logic Apps UTC expressions (`utcNow('H')`) don't account for the user's timezone.

**Resolution**: Open-Meteo returns `current.time` in the requested timezone (when `timezone=auto` is used). Parse the hour component from `current.time` to get the current local hour index. Today remaining = hourly indices `[current_hour]` through `[23]`; tomorrow = indices `[24]` through `[47]`. This avoids Windows-vs-IANA timezone name mismatches. See D-007.

---

## Decisions

### D-001: One Logic App with Parallel Branches (Not Two Separate Apps)

**Decision**: Single Logic App resource with one Recurrence trigger, one HTTP call to Open-Meteo, then two parallel branches (forecast rain, current rain).

**Rationale**: The Open-Meteo `/v1/forecast` endpoint returns both `current.weather_code` and `hourly.weather_code` in a single call (specify both via `current=weather_code,temperature_2m&hourly=weather_code,time`). A single API call is reusable by both branches. YAGNI — no reason to double the infrastructure, deployment complexity, or API calls.

**Alternatives considered**: Two separate Logic Apps (one per alert type) — rejected: doubles resource count and API calls with no benefit.

---

### D-002: Azure Logic Apps (Consumption Plan) Instead of Power Automate

**Decision**: Use Azure Logic Apps Consumption plan as the automation platform.

**Rationale**: Power Automate HTTP connector (required for Open-Meteo API calls) is premium — not included in M365 Business Basic. Azure Logic Apps includes HTTP as a built-in connector. SharePoint and Teams connectors in Logic Apps are the same standard connectors as in Power Automate. Cost: ~$0.50–$2/month.

**Constitution note**: Principle II (Platform-Native) requires M365-native solutions. This is a justified exception: the M365-native platform (Power Automate) cannot fulfill this requirement without a premium license. Azure Logic Apps is the Microsoft-endorsed cloud workflow platform and uses the same standard M365 connectors. Documented in plan.md Complexity Tracking.

**Alternatives considered**: Power Automate Premium add-on ($15/user/month) — rejected: disproportionate cost for a personal project. Power Automate free trial — rejected: 30-day limit, not viable long-term.

---

### D-003: SharePoint List (`DarkFactory-AlertState`) for Suppression State

**Decision**: Persist alert suppression timestamps in a new `DarkFactory-AlertState` SharePoint list in the DarkFactory site.

**Rationale**: Azure Logic Apps Consumption runs are stateless — variables reset on every execution. The 1-hour and 3-hour deduplication windows require state that persists across runs. SharePoint is already provisioned (Spec 003 prerequisite), uses the standard connector (no extra cost), and provides a human-readable audit trail.

**List schema**: Two items (fixed), one per alert type:
- Title: `ForecastRain` | `CurrentRain`
- `LastSentAt` (DateTime): UTC timestamp of most recent alert sent; `null` if never sent

**Alternatives considered**: Azure Storage Table — rejected: YAGNI, requires separate Azure resource. Logic App variables — rejected: reset on each run execution.

---

### D-004: Extend `DarkFactory-Settings` with Alert.* Keys (Not a Separate List)

**Decision**: Add four new rows to the existing `DarkFactory-Settings` SharePoint list.

New seed rows:
| Title | DFValue | DFCategory | DFDescription |
|---|---|---|---|
| Alert.RecipientId | `camilo.borges@xero.com` (or UPN) | Alerts | Teams UPN of private message recipient |
| Alert.ForecastSuppressionHours | `3` | Alerts | Hours to suppress duplicate forecast alerts |
| Alert.CurrentRainSuppressionHours | `1` | Alerts | Hours to suppress duplicate current rain alerts |
| Alert.PollingIntervalMinutes | `5` | Alerts | Logic App recurrence interval in minutes |

**Rationale**: Single configuration store (Constitution Principle V — DRY). These are configuration values, not operational state. Four additional rows in an existing list is simpler than provisioning a new list.

---

### D-005: WMO Rain Codes

**Decision**: The following WMO weather codes are classified as rain-alertable conditions:

| Codes | Description |
|---|---|
| 51, 53, 55 | Drizzle — light, moderate, dense |
| 56, 57 | Freezing drizzle |
| 61, 63, 65 | Rain — slight, moderate, heavy |
| 66, 67 | Freezing rain |
| 80, 81, 82 | Rain showers — slight, moderate, violent |
| 95, 96, 99 | Thunderstorm with rain |

Snow codes (71–77) and fog codes (45, 48) are excluded. Defined once as a Logic App variable at the start of the workflow; referenced by both forecast and current rain branches.

---

### D-006: Open-Meteo API Call Parameters

**Decision**: Single API call returning both current conditions and 2-day hourly forecast:

```
GET https://api.open-meteo.com/v1/forecast
  ?latitude={Weather.Latitude}
  &longitude={Weather.Longitude}
  &current=weather_code,temperature_2m
  &hourly=weather_code,time
  &forecast_days=2
  &timezone=auto
```

`timezone=auto` instructs Open-Meteo to detect timezone from the coordinates. The response `current.time` field reflects the local time, enabling correct "today remaining" / "tomorrow" boundary detection. No API key required (Open-Meteo is free and unauthenticated).

---

### D-007: Forecast Time Range Evaluation

**Decision**: Use `current.time` (from the Open-Meteo response) to derive the current local hour index. Filter hourly arrays as:
- **Today remaining**: hourly indices `[current_local_hour]` through `[23]`
- **Tomorrow**: hourly indices `[24]` through `[47]`

The Logic App parses the hour from `current.time` (format: `YYYY-MM-DDTHH:00`). This avoids Windows-vs-IANA timezone conversion. If ANY hourly code in indices `[current_local_hour]` to `[47]` is a rain code, a forecast alert is sent.

---

### D-008: Teams Connector Authentication

**Decision**: Teams standard managed connector with OAuth user-delegated authentication. The administrator (Camilo) signs in to the Teams connection in the Azure Logic Apps portal once during deployment. The connection is stored as an Azure resource and reused for all runs.

**Action**: "Post message in a chat or channel (V3)" → Chat type: "1:1 chat" → Recipient: value of `Alert.RecipientId` from DarkFactory-Settings.

No Graph API calls, no service principal, no app registration required.

---

### D-009: Logic App Recurrence Trigger

**Decision**: Native Recurrence trigger (built-in, free) with interval of 5 minutes (read from `Alert.PollingIntervalMinutes`).

**Note**: The Recurrence trigger interval is configured at workflow design time, not dynamically read at runtime. If `Alert.PollingIntervalMinutes` is changed in the settings store, the Logic App trigger must be manually updated. This is acceptable (YAGNI) — polling frequency changes are rare.

---

### D-010: Error Handling

**Decision**: Wrap the body of the Logic App in a Scope action with a Catch scope. If any action fails, the Catch logs the run as failed (visible in Logic Apps run history). No retry within a single run — the next scheduled run handles recovery (satisfies FR-010, SC-005).

**Rationale**: Logic Apps built-in retry policies on HTTP actions (3 retries, exponential backoff) cover transient API failures. Teams/SharePoint action failures surface in run history. No custom error notification needed (YAGNI — run history is the monitoring surface per FR-011).

