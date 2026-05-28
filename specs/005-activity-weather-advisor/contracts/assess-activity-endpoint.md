# Contract: POST /api/assess-activity

**Owner**: SK Agent (`src/sk-weather-agent/`)
**Consumers**: Azure Logic App (`la-darkfactory-activity-advisor`), Power Automate (Option B)
**Date**: 2026-05-28

---

## Endpoint

```
POST /api/assess-activity
Content-Type: application/json
X-Api-Key: {api_key}
```

Base URL is read from `DarkFactory-Settings.ActivityAdvisor.AgentEndpoint` at runtime.

---

## Request Body

```json
{
  "activity": "Trail Run",
  "location": "Wellington",
  "datetime": "2026-05-29T08:00:00"
}
```

| Field | Type | Required | Constraints |
|---|---|---|---|
| `activity` | string | Yes | Max 100 chars. Free text or from canvas app dropdown |
| `location` | string | Yes | Max 200 chars. City name — resolved to lat/lon internally via Open-Meteo Geocoding |
| `datetime` | string | Yes | ISO 8601 format. Used to select the nearest hourly forecast slot (±30 min window) |

---

## Success Response — HTTP 200

```json
{
  "risk": "Caution",
  "reason": "Wind speeds of 45 km/h are forecast at 08:00 — trail running is possible but exposed ridgelines should be avoided."
}
```

| Field | Type | Values |
|---|---|---|
| `risk` | string enum | `"Safe"` / `"Caution"` / `"Unsafe"` |
| `reason` | string | 1–3 sentences. Max 500 chars. References specific forecast values. |

---

## Error Responses

| HTTP status | `error` field | Cause |
|---|---|---|
| `400 Bad Request` | `"invalid_request"` | Missing or malformed required field |
| `401 Unauthorized` | `"unauthorized"` | Missing or invalid `X-Api-Key` header |
| `502 Bad Gateway` | `"geocoding_failed"` | Open-Meteo geocoding returned no results for the location |
| `502 Bad Gateway` | `"forecast_failed"` | Open-Meteo forecast API returned an error or was unreachable |
| `502 Bad Gateway` | `"assessment_failed"` | GPT returned an unexpected response shape |
| `500 Internal Server Error` | `"internal_error"` | Unhandled exception |

Error body shape:
```json
{
  "error": "geocoding_failed",
  "message": "Could not resolve location 'Atlantis' to coordinates. Please check the city name."
}
```

---

## Authentication

`X-Api-Key` header. The key value is stored in:
- **Logic App**: as a `securestring` parameter (`ActivityAdvisorApiKey`) — never in the workflow JSON
- **Power Automate**: as an environment variable (string type) — never hardcoded in the flow YAML
- **SK Agent**: validated in `Program.cs` middleware against `appsettings.json["ActivityAdvisor:ApiKey"]`

For local development (`ASPNETCORE_ENVIRONMENT=Development`), the key check is bypassed.

---

## Caller Notes (Logic App / Power Automate)

- On HTTP 502 or 500: Write `Status = "Error"` to the SP list item. Do **not** retry automatically — the error is logged on the agent side.
- Parse the response body with `json(body('HTTP_Call'))` — do not use schema parsing that would fail on error responses.
- Timeout: Set HTTP action timeout to `PT30S` (30 seconds). The Open-Meteo + GPT round-trip is expected under 10 seconds; 30 seconds gives headroom for cold starts.
