# Contract: Open-Meteo APIs

**Consumer**: SK Agent `ActivityAssessmentPlugin` and `WeatherPlugin`
**Date**: 2026-05-28

Both APIs are free and require no API key.

---

## 1. Geocoding API

Resolves a city name to latitude/longitude coordinates.

### Request

```
GET https://geocoding-api.open-meteo.com/v1/search
  ?name={city_name}
  &count=1
  &language=en
  &format=json
```

### Success Response

```json
{
  "results": [
    {
      "id": 2179537,
      "name": "Wellington",
      "latitude": -41.28664,
      "longitude": 174.77557,
      "elevation": 20.0,
      "feature_code": "PPLC",
      "country_code": "NZ",
      "country": "New Zealand",
      "timezone": "Pacific/Auckland",
      "population": 381900
    }
  ]
}
```

### No-results Response (location not found)

```json
{}
```

When `results` is absent or empty, the plugin returns HTTP 502 with `error: "geocoding_failed"`.

---

## 2. Forecast API

Returns current conditions and hourly forecast for a location.

### Request

```
GET https://api.open-meteo.com/v1/forecast
  ?latitude={lat}
  &longitude={lon}
  &current=temperature_2m,weathercode,windspeed_10m,precipitation,relative_humidity_2m
  &hourly=temperature_2m,weathercode,precipitation_probability,windspeed_10m
  &forecast_days=3
  &timezone=auto
```

### Success Response (abbreviated)

```json
{
  "latitude": -41.25,
  "longitude": 174.75,
  "timezone": "Pacific/Auckland",
  "current": {
    "time": "2026-05-28T14:00",
    "temperature_2m": 12.4,
    "weathercode": 3,
    "windspeed_10m": 28.5,
    "precipitation": 0.0,
    "relative_humidity_2m": 72
  },
  "hourly": {
    "time": [
      "2026-05-28T00:00",
      "2026-05-28T01:00"
    ],
    "temperature_2m": [10.2, 10.8],
    "weathercode": [1, 2],
    "precipitation_probability": [5, 10],
    "windspeed_10m": [18.3, 20.1]
  }
}
```

### Slot selection for ActivityAssessmentPlugin

The plugin selects the hourly forecast slot closest to `request.datetime`. Algorithm:
1. Parse `request.datetime` as `DateTimeOffset`.
2. Find the index `i` in `hourly.time[]` where `|time[i] - requestedTime| is minimised`.
3. Extract `temperature_2m[i]`, `weathercode[i]`, `precipitation_probability[i]`, `windspeed_10m[i]`.
4. Pass extracted values to the GPT prompt.

### WMO Weather Code → Human-readable description

```csharp
private static string DescribeWeatherCode(int code) => code switch
{
    0          => "Clear sky",
    1          => "Mainly clear",
    2          => "Partly cloudy",
    3          => "Overcast",
    45 or 48   => "Fog",
    >= 51 and <= 57 => "Drizzle",
    >= 61 and <= 67 => "Rain",
    >= 71 and <= 77 => "Snow",
    >= 80 and <= 82 => "Rain showers",
    85 or 86   => "Snow showers",
    95         => "Thunderstorm",
    96 or 99   => "Thunderstorm with hail",
    _          => $"Unknown conditions (WMO {code})"
};
```

---

## Error handling

Both endpoints return HTTP 200 even for empty results (geocoding) — the plugin must check for empty `results` array, not HTTP status. A non-200 response from either endpoint is treated as a transient failure and surfaced as HTTP 502 from the agent endpoint.
