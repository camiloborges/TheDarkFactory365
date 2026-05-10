# Data Model: Rain Alert Automation
**Branch**: `002-rain-alert-automation` | **Date**: 2026-05-10

---

## SharePoint Lists

### `DarkFactory-AlertState` (new — provisioned by this spec)

Stores persistent suppression state across Logic App runs. Contains exactly two items (one per alert type). Items are seeded during deployment; never created or deleted at runtime — only updated.

| Column | Type | Required | Description |
|---|---|---|---|
| Title | Text | Yes | Alert type identifier. Fixed values: `ForecastRain`, `CurrentRain` |
| LastSentAt | DateTime (UTC) | No | UTC timestamp of the most recent alert sent for this type. `null` means no alert has ever been sent. |

**Seed data** (created once at deployment):

| Title | LastSentAt |
|---|---|
| ForecastRain | *(null — no alert yet)* |
| CurrentRain | *(null — no alert yet)* |

**Null handling**: `LastSentAt` is `null` on first deployment. The Logic App suppression condition MUST be null-safe:
`if(equals(lastSentAt, null), true, less(addHours(lastSentAt, suppressionHours), utcNow()))` — evaluates to `true` (send alert) when `LastSentAt` is null.

**Permissions**: Inherited from DarkFactory site (Owners full control, Members read). The Logic App connection (admin OAuth) has full control.

---

### `DarkFactory-Settings` (extended — 4 new rows added by this spec)

Existing list from Spec 001. New `Alert.*` rows are added during this spec's deployment. No schema changes to the list itself — only new items.

| Title | DFValue | DFCategory | DFDescription |
|---|---|---|---|
| Alert.RecipientId | `(admin UPN, e.g. camilo@aiwhisperer.onmicrosoft.com)` | Alerts | Teams user principal name to receive private rain alert messages |
| Alert.ForecastSuppressionHours | `3` | Alerts | Hours before an identical forecast rain alert can be re-sent |
| Alert.CurrentRainSuppressionHours | `1` | Alerts | Hours before another current rain alert can be sent |
| Alert.PollingIntervalMinutes | `5` | Alerts | Logic App recurrence interval; must be updated manually in the Logic App trigger if changed |

---

## Logic App Internal Objects

### `WeatherApiResponse`

Shape of the Open-Meteo API response, referenced in Logic App expressions. Not a stored object.

```json
{
  "current": {
    "time": "2026-05-10T14:00",
    "weather_code": 63,
    "temperature_2m": 12.5
  },
  "hourly": {
    "time": ["2026-05-10T00:00", "2026-05-10T01:00", ...],
    "weather_code": [0, 1, 61, 63, ...]
  }
}
```

- `current.time`: Local time string in format `YYYY-MM-DDTHH:MM` (timezone = auto from coordinates)
- `current.weather_code`: WMO code for current conditions
- `current.temperature_2m`: Current temperature in configured unit
- `hourly.time[0..23]`: Today's hourly timestamps (local time)
- `hourly.time[24..47]`: Tomorrow's hourly timestamps (local time)
- `hourly.weather_code[i]`: WMO code for that hour

---

### `RainCodes` (Logic App variable — array)

Defined once as an Initialize Variable action at the start of the workflow. Referenced by both branches.

```
[51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]
```

| Range | Conditions |
|---|---|
| 51, 53, 55 | Drizzle — light, moderate, dense |
| 56, 57 | Freezing drizzle |
| 61, 63, 65 | Rain — slight, moderate, heavy |
| 66, 67 | Freezing rain |
| 80, 81, 82 | Rain showers — slight, moderate, violent |
| 95, 96, 99 | Thunderstorm with rain |

---

### `WmoCodeLabels` (Logic App variable — object)

Human-readable label map for WMO codes used in Teams alert messages. Defined once at start of workflow.

```json
{
  "51": "light drizzle", "53": "moderate drizzle", "55": "heavy drizzle",
  "56": "light freezing drizzle", "57": "heavy freezing drizzle",
  "61": "light rain", "63": "moderate rain", "65": "heavy rain",
  "66": "light freezing rain", "67": "heavy freezing rain",
  "80": "light rain showers", "81": "moderate rain showers", "82": "violent rain showers",
  "95": "thunderstorm", "96": "thunderstorm with hail", "99": "thunderstorm with heavy hail"
}
```

---

## State Transitions

```
Logic App Run (every 5 min)
│
├─ Read AlertState[ForecastRain].LastSentAt
│   ├─ [null or > ForecastSuppressionHours ago]
│   │   ├─ [any rain code in hourly[current_hour..47]] → Send Teams message
│   │   │                                              → Update LastSentAt = utcNow()
│   │   └─ [no rain code in forecast window] → No action
│   └─ [within ForecastSuppressionHours] → Suppressed, no action
│
└─ Read AlertState[CurrentRain].LastSentAt
    ├─ [null or > CurrentRainSuppressionHours ago]
    │   ├─ [current.weather_code in RainCodes] → Send Teams message
    │   │                                      → Update LastSentAt = utcNow()
    │   └─ [current.weather_code not in RainCodes] → No action
    └─ [within CurrentRainSuppressionHours] → Suppressed, no action
```

Both branches execute in parallel after the shared Open-Meteo API call.

---

## Teams Message Formats

### Forecast Rain Alert Message

```
🌧 Rain forecast alert — {LocationName}

Rain is forecast in the upcoming hours:
  Conditions: {WMO label for first rain-forecast code}
  Window: Today from {start_hour}:00 through to end of tomorrow
  Alert sent: {utcNow()} UTC

You may want to pack an umbrella or reschedule outdoor plans.
```

### Current Rain Alert Message

```
🌧 Rain alert — {LocationName}

It is currently raining at your home location.
  Conditions: {WMO label for current code}
  Temperature: {temperature_2m}°{unit}
  Detected at: {utcNow()} UTC
```

---

## Azure Resources

| Resource | Type | Notes |
|---|---|---|
| Resource Group | `rg-darkfactory` | Container for all DarkFactory Azure resources |
| Logic App | `la-darkfactory-rain-alert` | Consumption plan; single workflow |
| API Connection — SharePoint | `connection-sharepoint-darkfactory` | OAuth (admin user) |
| API Connection — Teams | `connection-teams-darkfactory` | OAuth (admin user) |
