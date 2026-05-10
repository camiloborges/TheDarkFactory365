# Feature Specification: Rain Alert Automation

**Feature Branch**: `001-weather-system`
**Created**: 2026-05-10
**Status**: Draft
**Depends On**: Spec 001 — Weather Display System (configuration store must be set up first; API provider is Open-Meteo as defined in Spec 001)
**Teams Deployment Target**: Private message to administrator; flows run in the `DarkFactory` tenant context
**Scope Note**: This spec covers the automated rain detection and private Teams notification flows only. The weather display web part is covered in Spec 001.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Receive a Forecast Rain Alert (Priority: P1)

As the family administrator, I want to receive a private Teams message when tomorrow's or today's remaining forecast predicts rain, so that I can plan ahead — packing an umbrella, rescheduling outdoor activities — before the rain arrives.

**Why this priority**: A proactive forecast alert is more useful than a reactive "it's raining now" alert. It gives lead time to act. This is the Dark Factory principle: inform before the event, not during it.

**Independent Test**: Can be tested by configuring the flow and confirming a private Teams message is received on a day when rain is forecast, before rain actually begins.

**Acceptance Scenarios**:

1. **Given** the forecast automation runs its scheduled check, **When** rain is predicted in today's remaining forecast or tomorrow's forecast, **Then** a private Teams message is sent to the administrator indicating rain is forecast, the expected time window, and the expected intensity.
2. **Given** a forecast rain alert was already sent in the past 3 hours for the same forecast window, **When** the next check runs, **Then** no duplicate alert is sent.
3. **Given** the forecast check runs, **When** no rain is predicted in the relevant forecast window, **Then** no Teams message is sent.
4. **Given** a forecast rain alert is sent, **When** the administrator reads it, **Then** the message includes: the forecast time window (e.g., "this afternoon 2pm–6pm"), the expected condition (e.g., "heavy rain"), the current date and time of the alert, and the home location name.

---

### User Story 2 — Receive a Current Rain Alert (Priority: P2)

As the family administrator, I want to receive a private Teams message when it is actively raining at our home address right now, so that I can take immediate action — bringing in laundry, closing windows, alerting family members heading outside.

**Why this priority**: Real-time detection catches rain events that were not forecast or that deviated from predictions. It is the reactive safety net that complements the proactive forecast alert.

**Independent Test**: Can be tested (or simulated) by triggering the flow when a rain condition is active at the configured location and confirming a private Teams message is received.

**Acceptance Scenarios**:

1. **Given** the current conditions check runs, **When** rain is detected as the active weather condition at the home location, **Then** a private Teams message is sent to the administrator indicating it is currently raining.
2. **Given** a "currently raining" alert was sent within the past 1 hour, **When** the next check also detects rain, **Then** no duplicate alert is sent (suppression window applies).
3. **Given** rain stops and the next check detects a non-rain condition, **When** rain starts again after the suppression window has expired, **Then** a new alert is sent for the new rain event.
4. **Given** a current rain alert is sent, **When** the administrator reads it, **Then** the message includes: the current condition label (e.g., "light rain", "heavy rain"), the current temperature, the time of detection, and the home location name.
5. **Given** the automation has already sent a forecast alert for rain "this afternoon", **When** the current conditions check confirms it is now raining, **Then** the real-time alert is still sent — it is not suppressed by the forecast alert.

---

### User Story 3 — Alerts Work Reliably Without Manual Intervention (Priority: P3)

As the family administrator, I want the alert system to run automatically on its schedule and handle errors gracefully, so that I never need to manually trigger it or fix it after a transient failure.

**Why this priority**: A Dark Factory solution must be self-sustaining. An alert system that requires babysitting defeats its own purpose.

**Independent Test**: Can be tested by simulating API failures and confirming the flow recovers on the next scheduled run without manual intervention.

**Acceptance Scenarios**:

1. **Given** the weather API returns an error on one polling cycle, **When** the next scheduled cycle runs, **Then** the flow retries normally and sends alerts if conditions warrant — the previous failure does not block future runs.
2. **Given** the Teams messaging action fails (e.g., temporary connectivity issue), **When** the flow completes, **Then** the failure is logged visibly in the flow run history so the administrator can investigate if needed.
3. **Given** the flow has been running for 30 days without changes, **When** a rain event occurs, **Then** alerts are still sent correctly — no manual renewal or reset is required.

---

### Edge Cases

- What if rain is forecast but the forecast later changes to no rain (forecast revision)? The alert has already been sent — no retraction is issued. This is acceptable; the administrator treats it as advisory.
- What if the home location is updated in the config store mid-day? The next poll cycle will use the new location. Alerts sent before the update referenced the old location — this is acceptable and noted in the alert message via the location name field.
- What if the weather API changes its rain condition codes between API versions? The flow must use the API's standard condition codes for rain detection, not hardcoded string matching. If the API is changed, the flow configuration is updated accordingly.
- What if both a forecast alert and a current rain alert are triggered at the same polling cycle? Both messages are sent. They are distinct alert types with distinct messages — one is not suppressed by the other.
- What if the administrator's Microsoft 365 account has changed (e.g., re-configured)? The private message target is configured in the settings store, so it can be updated without modifying the flow itself.
- What happens if the polling frequency is increased beyond API rate limits? The configuration store governs polling frequency; the administrator is responsible for staying within their API plan limits.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST check the weather forecast on a 5-minute schedule and send a private Teams message to the administrator when rain is predicted in the current day's remaining forecast or tomorrow's forecast.
- **FR-002**: The system MUST check current weather conditions on a 5-minute schedule and send a private Teams message to the administrator when rain is the active condition at the home location.
- **FR-003**: Forecast rain alerts MUST be suppressed if an equivalent alert (same forecast window) was sent within the past 3 hours.
- **FR-004**: Current rain alerts MUST be suppressed if a current rain alert was sent within the past 1 hour.
- **FR-005**: Forecast rain alerts and current rain alerts MUST NOT suppress each other — they are independent alert types.
- **FR-006**: Forecast rain alert messages MUST include: the forecast time window, expected rain condition/intensity, alert timestamp, and configured home location name.
- **FR-007**: Current rain alert messages MUST include: the current condition label, current temperature, detection timestamp, and configured home location name.
- **FR-008**: The automation MUST read all configuration (home location, API credentials, alert recipient, polling frequency) from the central configuration store established in Spec 001. Nothing may be hardcoded.
- **FR-009**: The automation MUST recover automatically from transient API or connectivity failures — a single failed poll cycle must not prevent subsequent cycles from running.
- **FR-010**: Flow run history MUST be retained and visible to the administrator for at least 30 days to support troubleshooting.
- **FR-011**: The private Teams message recipient MUST be configurable via the settings store — changing the recipient must not require modifying the automation itself.

### Key Entities

- **RainForecastAlert**: A record of a forecast rain alert that was sent — includes the forecast window covered, condition label, and timestamp sent. Used to enforce the 3-hour suppression window.
- **CurrentRainAlert**: A record of a current rain alert that was sent — includes condition label, temperature at time of alert, and timestamp sent. Used to enforce the 1-hour suppression window.
- **AlertConfig**: Configuration for the alert system — includes the recipient identifier (administrator's Teams identity), forecast look-ahead window (today remaining + tomorrow), forecast suppression window (3 hours), current rain suppression window (1 hour), and polling interval (5 minutes).

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A forecast rain alert is delivered to the administrator's Teams private message within 5 minutes of a rain-predicting forecast appearing in the API data.
- **SC-002**: A current rain alert is delivered to the administrator's Teams private message within 5 minutes of rain being detected as the active condition.
- **SC-003**: No more than 1 forecast alert is sent per forecast window per 3-hour period under continuous rain-forecast conditions.
- **SC-004**: No more than 1 current rain alert is sent per 1-hour period under continuous rain conditions.
- **SC-005**: The automation recovers from a transient API failure within one polling cycle (≤5 minutes) without manual intervention.
- **SC-006**: The alert recipient can be changed in the configuration store and takes effect within one polling cycle, with no changes to the automation itself.
- **SC-007**: The system runs for 30 consecutive days without requiring manual restarts, renewals, or fixes under normal operating conditions.

---

## Assumptions

- Spec 001 (Weather Display System) is fully deployed and the central configuration store is set up before this spec is implemented.
- **Open-Meteo** (the API selected in Spec 001) provides rain condition codes and hourly forecast data sufficient to distinguish rain types (drizzle, light rain, heavy rain, showers) and to detect rain in upcoming forecast windows.
- Microsoft Power Automate (included in the Microsoft 365 Family subscription) supports 5-minute scheduled triggers without requiring a premium plan. This should be verified during planning — Power Automate free/included tiers may enforce a minimum interval; if so, the minimum supported interval becomes the polling frequency.
- The administrator (Camilo) is the sole recipient of private rain alerts. Multi-recipient alerts are out of scope for v1.
- "Forecast look-ahead" covers today's remaining hours and the full next calendar day only. Alerts for rain predicted 2+ days out are out of scope for v1.
- The suppression windows (3 hours for forecast, 1 hour for current rain) are stored in the configuration store and can be adjusted without modifying the automation.
- Alert suppression state (last sent timestamps) is stored within the automation's own run history or a lightweight store — not in the SharePoint settings list.
- Severe weather alerts (storms, hail, wind warnings) beyond rain detection are out of scope for v1.
- No alert retraction or "rain has stopped" notification is sent in v1.
- The administrator accepts that forecast alerts may occasionally be sent for rain events that do not materialise (forecast inaccuracy is a weather API limitation, not a system defect).
