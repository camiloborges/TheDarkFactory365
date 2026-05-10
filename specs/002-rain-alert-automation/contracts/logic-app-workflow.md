# Contract: Logic App Workflow Interface
**Logic App**: `la-darkfactory-rain-alert` | **Date**: 2026-05-10

---

## Trigger

**Type**: Recurrence (built-in, free)  
**Interval**: 5 minutes (configured at design time; matches `Alert.PollingIntervalMinutes` in DarkFactory-Settings)  
**Timezone**: UTC  
**Start time**: On deployment

No external trigger — the workflow is self-scheduling.

---

## External API Contract: Open-Meteo

**Method**: GET (HTTP built-in connector, no authentication)

**Request**:
```
GET https://api.open-meteo.com/v1/forecast
  ?latitude={float}           — from DarkFactory-Settings Weather.Latitude
  ?longitude={float}          — from DarkFactory-Settings Weather.Longitude
  &current=weather_code,temperature_2m
  &hourly=weather_code,time
  &forecast_days=2
  &timezone=auto
```

**Response** (relevant fields):
```json
{
  "current": {
    "time": "YYYY-MM-DDTHH:00",
    "weather_code": integer,
    "temperature_2m": float
  },
  "hourly": {
    "time": ["YYYY-MM-DDTHH:00", ...],
    "weather_code": [integer, ...]
  }
}
```

**Error handling**: HTTP action uses built-in retry policy (3 retries, exponential backoff 20–600s). If all retries fail, the run is marked Failed in run history; next scheduled run proceeds normally (FR-010).

---

## SharePoint Read Contract: `DarkFactory-Settings`

**Action**: Get items (SharePoint standard connector)  
**Site**: `https://aiwhisperer.sharepoint.com/sites/DarkFactory`  
**List**: `DarkFactory-Settings`  
**OData filter**: `startswith(Title,'Weather.') or startswith(Title,'Alert.')`

**Keys consumed**:

| Title | Field | Used for |
|---|---|---|
| Weather.Latitude | DFValue | Open-Meteo API latitude |
| Weather.Longitude | DFValue | Open-Meteo API longitude |
| Alert.RecipientId | DFValue | Teams message recipient UPN |
| Alert.ForecastSuppressionHours | DFValue | Suppression window (forecast branch) |
| Alert.CurrentRainSuppressionHours | DFValue | Suppression window (current rain branch) |

---

## SharePoint Read Contract: `DarkFactory-AlertState`

**Action**: Get items (SharePoint standard connector)  
**Site**: `https://aiwhisperer.sharepoint.com/sites/DarkFactory`  
**List**: `DarkFactory-AlertState`  
**OData filter**: none (2 items total, fetch all)

**Items read**:

| Title | LastSentAt |
|---|---|
| ForecastRain | DateTime or null |
| CurrentRain | DateTime or null |

---

## SharePoint Write Contract: `DarkFactory-AlertState`

**Action**: Update item (SharePoint standard connector)  
**Trigger**: Executed only when an alert is successfully sent to Teams

**Update fields**:

| Field | Value |
|---|---|
| LastSentAt | `@{utcNow()}` (ISO 8601 UTC string) |

**Idempotency**: `LastSentAt` is only written after a Teams message is sent. A failed Teams action leaves `LastSentAt` unchanged, ensuring the next run retries the alert.

---

## Teams Write Contract

**Action**: "Post a message (V3)" — Teams standard connector in Logic Apps designer (note: Power Automate shows this as "Post message in a chat or channel (V3)" — same connector, different UI label)  
**Connection**: OAuth user-delegated (admin account)  
**Chat type**: 1:1 chat  
**Recipient**: value of `Alert.RecipientId` (Teams UPN)  
**Message format**: Plain text with emoji prefix (see data-model.md Teams Message Formats)

**Error handling**: If the Teams action fails, the Catch scope marks the run as Failed. `LastSentAt` is not updated (correct — next run will retry the alert if conditions still warrant it).

---

## Idempotency Contract

The Logic App guarantees:

- Re-running within the suppression window produces NO Teams message and NO write to `DarkFactory-AlertState`
- Re-running when suppression has expired and conditions match sends exactly one message per alert type per run
- A run that fails after sending the Teams message but before updating `LastSentAt` will retry the alert on the next run — acceptable duplication risk given the 5-minute cycle
- A run that fails before reaching the Teams action sends no message — correct

---

## Exit States

| State | Meaning |
|---|---|
| Succeeded | All actions completed; alerts sent or suppressed as expected |
| Failed | At least one action threw an unhandled exception (e.g., API timeout, Teams auth error) — logged in run history; next run proceeds |
| Skipped | Not applicable for Recurrence-triggered workflows |

---

## Run History Retention

Logic Apps Consumption plan retains run history for 90 days by default (exceeds the 30-day requirement in FR-011). No additional configuration needed.
