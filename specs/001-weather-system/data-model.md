# Data Model: Weather Display System
**Branch**: `001-weather-system` | **Date**: 2026-05-10

All models are TypeScript interfaces. No classes — plain data shapes only. Business logic lives in services and mappers.

---

## DisplayState

```typescript
// src/webparts/darkFactoryWeather/models/DisplayState.ts

export enum DisplayState {
  Loading = 'loading',         // Initial fetch in progress — show skeleton
  Live = 'live',               // Data fresh (< 30 min old)
  Cached = 'cached',           // Data present but older than 30 min — show staleness warning
  SetupRequired = 'setup-required', // One or more required config keys missing
  Error = 'error',             // Unrecoverable state — show error message
}
```

---

## IWeatherReading

```typescript
// src/webparts/darkFactoryWeather/models/IWeatherReading.ts

export interface IWeatherReading {
  // Temperatures in configured unit (default Celsius)
  temperature: number;
  feelsLike: number;

  // Atmospheric
  humidity: number;          // Percent (0–100)
  uvIndex: number | null;    // null if not provided by API

  // Wind
  windSpeed: number;         // km/h (or configured unit)
  windDirection: number;     // Degrees 0–360 (0 = North)

  // Condition
  weatherCode: number;       // WMO code
  conditionLabel: string;    // Human-readable label from WeatherCodeMapper
  isRain: boolean;           // Derived: true if code indicates rain/drizzle/showers

  // Time of observation
  observedAt: Date;          // Local time

  // Sun
  sunrise: Date;             // Local time for today
  sunset: Date;              // Local time for today
  uvIndexMax: number | null; // Day maximum UV (from daily data)
}
```

---

## IForecastPeriod

```typescript
// src/webparts/darkFactoryWeather/models/IForecastPeriod.ts

export type PeriodName = 'Morning' | 'Afternoon' | 'Evening' | 'Tonight';
export type DayName = string; // e.g. 'Tomorrow', 'Wednesday'

export interface IForecastPeriod {
  name: PeriodName | DayName;   // 'Morning' for today periods, day name for 2-day outlook
  isToday: boolean;             // true for Morning/Afternoon/Evening/Tonight groups

  // Temperature range
  tempMin: number;
  tempMax: number;

  // Condition
  weatherCode: number;          // Most severe WMO code in period
  conditionLabel: string;
  isRain: boolean;

  // Precipitation (today periods only; null for daily outlook)
  precipitationMm: number | null;
}
```

---

## IHomeLocation

```typescript
// src/webparts/darkFactoryWeather/models/IHomeLocation.ts

export interface IHomeLocation {
  displayName: string;     // e.g. 'Home'
  city: string;            // e.g. 'Auckland'
  latitude: number;        // WGS84 decimal degrees
  longitude: number;       // WGS84 decimal degrees
  timezone: string;        // IANA timezone, e.g. 'Pacific/Auckland'
}
```

---

## IWeatherConfig

```typescript
// src/webparts/darkFactoryWeather/models/IWeatherConfig.ts

export interface IWeatherConfig {
  location: IHomeLocation;
  apiBaseUrl: string;          // e.g. 'https://api.open-meteo.com/v1/forecast'
  temperatureUnit: 'celsius' | 'fahrenheit';
  refreshIntervalMinutes: number;  // Default: 5
}
```

---

## IConfigEntry (SharePoint list row shape)

```typescript
// src/webparts/darkFactoryWeather/models/IConfigEntry.ts
// Internal model — maps one SharePoint list item to a key/value pair

export interface IConfigEntry {
  key: string;    // Maps to list 'Title' column
  value: string;  // Maps to list 'Value' column
}
```

---

## SharePoint Configuration List Schema

**List name**: `DarkFactory-Settings`
**Site**: DarkFactory team SharePoint site

| Column name | Internal name | Type | Required | Unique |
|---|---|---|---|---|
| Title | Title | Single line text | Yes | Yes — enforced via list validation |
| Value | DFValue | Single line text | Yes | No |
| Description | DFDescription | Multiple lines text | No | No |
| Category | DFCategory | Choice | No | No |

**Choice values for Category**: `Weather`, `Alerts`, `General`

**Permissions**: Break inheritance from parent site.
- Visitors → Read
- Members → Read (do not promote to Edit unless intentional)
- Owners / Site Admin → Full Control

**Required items for Spec 001**:

| Title (Key) | Value | Category |
|---|---|---|
| `Weather.Latitude` | `-36.8509` | Weather |
| `Weather.Longitude` | `174.7645` | Weather |
| `Weather.Timezone` | `Pacific/Auckland` | Weather |
| `Weather.LocationName` | `Home` | Weather |
| `Weather.City` | `Auckland` | Weather |
| `Weather.ApiBaseUrl` | `https://api.open-meteo.com/v1/forecast` | Weather |
| `Weather.TemperatureUnit` | `celsius` | Weather |
| `Weather.RefreshIntervalMinutes` | `5` | Weather |

---

## State Transitions

```
                    ┌─────────────────┐
        page load   │                 │
        ──────────► │    Loading      │
                    │                 │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     config   │     data     │    missing   │
     error    │     ok       │    config    │
              ▼              ▼              ▼
          ┌───────┐      ┌──────┐    ┌────────────────┐
          │ Error │      │ Live │    │ Setup Required │
          └───────┘      └──┬───┘    └────────────────┘
                            │
                  30 min without refresh
                            │
                            ▼
                        ┌────────┐
                        │ Cached │
                        └────────┘
                            │
                  successful refresh
                            │
                            ▼
                        ┌──────┐
                        │ Live │
                        └──────┘
```

Error state is terminal for the current session — user must reload. SetupRequired is terminal until config is populated and page reloaded.
