# Contract: Open-Meteo API
**Version**: v1 | **Date**: 2026-05-10 | **Provider**: Open-Meteo (open-meteo.com)

---

## Endpoint

```
GET https://api.open-meteo.com/v1/forecast
```

No authentication. No API key. CORS: `Access-Control-Allow-Origin: *` (direct browser fetch supported).

---

## Request

### Required parameters

| Parameter | Type | Example |
|---|---|---|
| `latitude` | float | `-36.8509` |
| `longitude` | float | `174.7645` |
| `timezone` | string (IANA) | `Pacific/Auckland` |

### Variable parameters (must be included as-is)

```
current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m,uv_index
hourly=temperature_2m,apparent_temperature,weather_code,precipitation
daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max
forecast_days=3
wind_speed_unit=kmh
```

### Optional parameters (from config store)

| Parameter | Default | Notes |
|---|---|---|
| `temperature_unit` | `celsius` | `celsius` or `fahrenheit` — read from `Weather.TemperatureUnit` |

### Full example URL

```
https://api.open-meteo.com/v1/forecast?latitude=-36.8509&longitude=174.7645&timezone=Pacific%2FAuckland&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m,uv_index&hourly=temperature_2m,apparent_temperature,weather_code,precipitation&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max&forecast_days=3&wind_speed_unit=kmh
```

---

## Response

### Top-level shape

```typescript
interface OpenMeteoResponse {
  latitude: number;
  longitude: number;
  timezone: string;                // e.g. "Pacific/Auckland"
  timezone_abbreviation: string;   // e.g. "NZST"
  utc_offset_seconds: number;
  current: OpenMeteoCurrent;
  hourly: OpenMeteoHourly;
  daily: OpenMeteoDaily;
}
```

### Current object

```typescript
interface OpenMeteoCurrent {
  time: string;                    // ISO8601 local time, e.g. "2026-05-10T14:30"
  temperature_2m: number;          // °C (or °F if requested)
  apparent_temperature: number;    // °C feels-like
  relative_humidity_2m: number;    // % (0–100)
  weather_code: number;            // WMO code integer
  wind_speed_10m: number;          // km/h
  wind_direction_10m: number;      // degrees 0–360
  uv_index: number;                // 0+ (may be 0 at night)
}
```

### Hourly object

```typescript
interface OpenMeteoHourly {
  time: string[];                  // Array of ISO8601 local timestamps, one per hour
  temperature_2m: number[];        // Parallel arrays — index matches time[]
  apparent_temperature: number[];
  weather_code: number[];
  precipitation: number[];         // mm per hour
}
```

`forecast_days=3` returns 72 hourly entries (3 × 24h). Today's entries start at index 0 (local midnight). The `WeatherService` filters to only today's remaining hours.

### Daily object

```typescript
interface OpenMeteoDaily {
  time: string[];                  // ["2026-05-10", "2026-05-11", "2026-05-12"]
  weather_code: number[];
  temperature_2m_max: number[];    // Daily high
  temperature_2m_min: number[];    // Daily low
  sunrise: string[];               // ISO8601 local time
  sunset: string[];                // ISO8601 local time
  uv_index_max: number[];          // Daily UV maximum
}
```

Index 0 = today. Indices 1 and 2 = the two forecast days shown in the 2-day outlook.

---

## WMO Weather Code Lookup

Full lookup table lives in `WeatherCodeMapper.ts` (single source of truth). Summary of rain codes used for `isRain` detection:

| Codes | Category |
|---|---|
| 51, 53, 55 | Drizzle (light → heavy) |
| 61, 63, 65 | Rain (slight → heavy) |
| 67 | Freezing rain (heavy) |
| 80, 81, 82 | Rain showers (slight → violent) |
| 95, 96, 99 | Thunderstorm |

**isRain formula**: `(code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95`

---

## Error Handling

| HTTP status | Meaning | Web part behaviour |
|---|---|---|
| 200 | Success | Parse and display |
| 400 | Bad parameters | Log error, show cached data + staleness warning |
| 429 | Rate limited | Log warning, show cached data + staleness warning; retry on next interval |
| 5xx | Server error | Log error, show cached data + staleness warning |
| Network error | Offline / DNS | Show cached data + staleness warning |

The web part **never surfaces raw API errors to the user**. All failure paths map to `DisplayState.Cached` (if prior data exists) or `DisplayState.Error` (first load only).
