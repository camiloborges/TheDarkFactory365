# Data Model: Outdoor Activity Weather Advisor

**Feature**: 005-activity-weather-advisor
**Date**: 2026-05-28

---

## SharePoint Lists

### DarkFactory-ActivityRequests (New)

Provisioned by Spec 003 extension in `src/tenant-infra/`. Stores activity requests and their AI-generated assessments.

| Column name | SP Type | Required | Notes |
|---|---|---|---|
| `Title` | Single line of text | Yes | Auto-populated by canvas app: `"{Activity} @ {Location}"` |
| `Activity` | Single line of text | Yes | From canvas app dropdown: Trail Run, Cycling, Swimming, Hiking, Other |
| `Location` | Single line of text | Yes | City name as typed by user |
| `RequestedDateTime` | Date and Time | Yes | Intended activity date/time (not submission time) |
| `Status` | Choice | Yes | `Pending` (default) / `Complete` / `Error` |
| `RiskLevel` | Choice | No | `Safe` / `Caution` / `Unsafe` — written by Logic App / PA after assessment |
| `AssessmentReason` | Multiple lines of text | No | Plain text reason from GPT — written by Logic App / PA |
| `RequestedBy` | Person or Group | Yes | Current user (canvas app sets via `User()`) |

**State transitions**:
```
[New item] → Status: Pending
    ↓ (Logic App A / PA B triggers)
Status: Complete  (RiskLevel + AssessmentReason populated)
Status: Error     (SK agent unreachable or returned error)
```

**Indexing**: Index `Status` column for efficient Logic App / PA trigger filtering and canvas app gallery queries.

### DarkFactory-Settings (Existing — new rows only)

| Key | Value type | Description |
|---|---|---|
| `ActivityAdvisor.AgentEndpoint` | URL string | Base URL of the deployed SK agent ACA container, e.g. `https://sk-weather-agent.{hash}.australiaeast.azurecontainerapps.io` |
| `ActivityAdvisor.NotificationRecipient` | Email string | Fallback Teams notification recipient when `RequestedBy` does not resolve to a valid Teams user |

---

## SK Agent Models

### ActivityAssessmentRequest (inbound — POST /api/assess-activity)

```json
{
  "activity": "Trail Run",
  "location": "Wellington",
  "datetime": "2026-05-29T08:00:00"
}
```

| Field | Type | Constraints |
|---|---|---|
| `activity` | string | Required, max 100 chars |
| `location` | string | Required, max 200 chars. City name resolved to lat/lon via geocoding |
| `datetime` | string (ISO 8601) | Required. Used to select the nearest hourly forecast slot |

### ActivityAssessmentResponse (outbound)

```json
{
  "risk": "Caution",
  "reason": "Wind speeds of 45 km/h are forecast at 08:00 — trail running is possible but exposed ridgelines should be avoided."
}
```

| Field | Type | Constraints |
|---|---|---|
| `risk` | enum string | One of: `Safe`, `Caution`, `Unsafe` |
| `reason` | string | 1–3 sentences. References specific forecast values. Max 500 chars |

### ActivityAssessmentErrorResponse (outbound on failure)

```json
{
  "error": "geocoding_failed",
  "message": "Could not resolve location 'Atlantis' to coordinates. Please check the city name."
}
```

### OpenMeteoGeocodingResult (internal — geocoding API response, relevant fields)

```json
{
  "results": [
    {
      "name": "Wellington",
      "latitude": -41.2866,
      "longitude": 174.7756,
      "country": "New Zealand",
      "timezone": "Pacific/Auckland"
    }
  ]
}
```

### OpenMeteoForecastResult (internal — forecast API response, relevant fields)

```json
{
  "current": {
    "temperature_2m": 12.4,
    "weathercode": 3,
    "windspeed_10m": 28.5,
    "precipitation": 0.0,
    "relative_humidity_2m": 72
  },
  "hourly": {
    "time": ["2026-05-29T08:00", "2026-05-29T09:00"],
    "temperature_2m": [11.2, 12.8],
    "weathercode": [80, 3],
    "precipitation_probability": [65, 20],
    "windspeed_10m": [32.1, 25.4]
  }
}
```

---

## Logic App Parameters

### la-darkfactory-activity-advisor parameters

| Parameter | Type | Source |
|---|---|---|
| `ActivityAdvisorApiKey` | securestring | Azure Logic Apps parameter (stored as Logic App parameter, value in Azure) |
| `SharePointSiteUrl` | string | Deployment parameter |
| `AgentEndpointUrl` | string | Read from `DarkFactory-Settings` at runtime, or deployment parameter |

---

## Power Apps Canvas App Data Sources

| Source | Connector | Tables/Lists used |
|---|---|---|
| DarkFactory SharePoint site | SharePoint (standard) | `DarkFactory-ActivityRequests` (read/write) |

---

## Enums

### Activity types (canvas app dropdown)

| Value | Display label |
|---|---|
| `Trail Run` | Trail Run |
| `Cycling` | Cycling |
| `Swimming` | Swimming |
| `Hiking` | Hiking |
| `Other` | Other |

### Status values

| Value | Set by |
|---|---|
| `Pending` | Canvas app (on submission) |
| `Complete` | Logic App A / Power Automate B (after successful assessment) |
| `Error` | Logic App A / Power Automate B (on SK agent call failure) |

### RiskLevel values

| Value | Meaning |
|---|---|
| `Safe` | Conditions are suitable. No significant hazard. |
| `Caution` | Conditions are marginal. Activity possible with precautions. |
| `Unsafe` | Conditions pose a meaningful risk to health or safety. |
