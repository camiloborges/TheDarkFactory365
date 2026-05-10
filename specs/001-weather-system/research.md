# Research: Weather Display System
**Branch**: `001-weather-system` | **Date**: 2026-05-10 | **Phase**: 0

---

## Risks

### RISK-001 (RESOLVED ✅): Microsoft 365 Business Basic Confirmed

**Finding**: Microsoft 365 Family (personal subscription) does not include SharePoint Online tenant features, App Catalog, tenant-level CSP management, or the SharePoint Administrator role — all of which are required for SPFx deployment.

**Resolution**: New **Microsoft 365 Business Basic** tenant provisioned:
- **Tenant domain**: `aiwhisperer.onmicrosoft.com`
- **Confirmed**: 2026-05-10
- Provides full SharePoint Online, App Catalog, Admin Centre, Teams business, Exchange Online, Power Automate (standard connectors)

**Status**: BLOCKER resolved. Implementation may proceed. All plan assumptions hold.

---

### RISK-002 (BLOCKER for Spec 002): Power Automate HTTP Connector is Premium

**Finding**: The HTTP connector in Power Automate — required to call the Open-Meteo API from a scheduled flow — is a **Premium connector**. It is not included in Microsoft 365 Business Basic.

**Options for Spec 002**:
| Option | Cost | Notes |
|---|---|---|
| Power Automate Premium licence | ~$15/user/month | Unlocks HTTP and all premium connectors |
| Power Automate per-flow plan | ~$100/flow/month | Expensive for personal use |
| Azure Logic Apps | Pay-per-use (~$0.000025/action) | ~$0.02/month for 5-min polling — cheapest option |
| Azure Function (timer trigger) | Free tier covers this | Pro-code, more control, no premium connectors needed |

**Recommended resolution for Spec 002**: Use **Azure Logic Apps** (consumption plan) as the scheduler and HTTP caller. Negligible cost, no premium connector licensing, full HTTP support.

**Gate for Spec 002**: Resolve before planning Spec 002.

---

### RISK-003 (OPERATIONAL): SharePoint CSP Enforcement Already Active

**Finding**: SharePoint Online Content Security Policy enforcement began **March 1, 2026**. As of today (May 10, 2026), enforcement is live. Client-side `fetch()` calls from SPFx web parts to `api.open-meteo.com` will be **blocked by the browser** unless `api.open-meteo.com` is added to the tenant CSP allowlist.

**Resolution**: Add to CSP allowlist as a deployment prerequisite (see Deployment section in plan.md). Cmdlet: `Add-SPOContentSecurityPolicy -Source "https://api.open-meteo.com"`.

---

## Research Decisions

### D-001: Weather API — Open-Meteo Confirmed

**Decision**: Open-Meteo (`https://api.open-meteo.com/v1/forecast`)

**Rationale**:
- Zero cost, no API key, no account required
- Returns all required data in a single API call: current conditions, hourly forecast, daily forecast, UV index, sunrise/sunset
- Full CORS support (`Access-Control-Allow-Origin: *`) — direct browser fetch works
- Strong Oceania coverage (NZ/AU backed by NOAA and EU Copernicus data)
- Fair use limit ~10,000 req/day; 5-minute polling by one household = 288 req/day

**Alternatives considered**:
- WeatherAPI.com: Requires API key; 1M calls/month free; backup option if Open-Meteo coverage is insufficient
- OpenWeatherMap: UV index requires a separate API call on free tier; rejected
- Tomorrow.io: 500 calls/day free tier — too tight for 5-minute polling; rejected

**Single unified API call**:
```
GET https://api.open-meteo.com/v1/forecast
  ?latitude={LAT}
  &longitude={LON}
  &current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m,uv_index
  &hourly=temperature_2m,apparent_temperature,weather_code,precipitation
  &daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max
  &timezone={IANA_TIMEZONE}
  &forecast_days=3
  &wind_speed_unit=kmh
```

**Response fields used**:

| Field path | Type | Unit | Maps to |
|---|---|---|---|
| `current.temperature_2m` | number | °C | Current temp |
| `current.apparent_temperature` | number | °C | Feels-like |
| `current.relative_humidity_2m` | number | % | Humidity |
| `current.weather_code` | integer | WMO | Condition label + icon |
| `current.wind_speed_10m` | number | km/h | Wind speed |
| `current.wind_direction_10m` | integer | degrees | Wind direction |
| `current.uv_index` | number | index | UV index |
| `daily.time[0]` | string | YYYY-MM-DD | Today |
| `daily.sunrise[0]` | string | ISO8601 local | Sunrise |
| `daily.sunset[0]` | string | ISO8601 local | Sunset |
| `daily.uv_index_max[0]` | number | index | Day max UV |
| `hourly.time[]` | string[] | ISO8601 local | Period grouping |
| `hourly.temperature_2m[]` | number[] | °C | Period temp |
| `hourly.weather_code[]` | integer[] | WMO | Period condition |
| `hourly.precipitation[]` | number[] | mm | Period rain amount |
| `daily.time[1..2]` | string[] | YYYY-MM-DD | Forecast days |
| `daily.temperature_2m_max[1..2]` | number[] | °C | Day highs |
| `daily.temperature_2m_min[1..2]` | number[] | °C | Day lows |
| `daily.weather_code[1..2]` | integer[] | WMO | Day conditions |

---

### D-002: WMO Rain Condition Codes

Rain detection (for visual distinction and Spec 002 alerts) uses these WMO codes:

| Code range | Label | Category |
|---|---|---|
| 51, 53, 55 | Light / Moderate / Heavy Drizzle | Drizzle |
| 61, 63, 65 | Slight / Moderate / Heavy Rain | Rain |
| 80, 81, 82 | Slight / Moderate / Violent Showers | Showers |
| 95, 96, 99 | Thunderstorm (with/without hail) | Storm |

**Rain detection rule**: `weatherCode >= 51 && weatherCode <= 67 || weatherCode >= 80 && weatherCode <= 82 || weatherCode >= 95`

All other codes are non-rain. Full code list stored in `WeatherCodeMapper.ts` as a lookup table — single source of truth, no duplication.

---

### D-003: Today Remaining — Grouped Period Boundaries

Periods are derived from the hourly data array using local time (timezone applied by Open-Meteo when `timezone` parameter is set):

| Period | Local hours included | Shown if... |
|---|---|---|
| Morning | 06:00 – 11:59 | Current local hour < 12 |
| Afternoon | 12:00 – 17:59 | Current local hour < 18 |
| Evening | 18:00 – 20:59 | Current local hour < 21 |
| Tonight | 21:00 – 23:59 | Current local hour < 24 |

**Aggregation per period**:
- Temperature: average of hourly values in range
- Condition: WMO code with highest severity (highest numeric value) in range
- Precipitation: sum of hourly precipitation mm in range

If a period has no remaining hours (all hours have passed), it is excluded from the display.

---

### D-004: SPFx Version — 1.22.2 on Node 22 LTS

**Decision**: SPFx 1.22.2, Node.js 22 LTS, TypeScript 5.8, React 17.0.1

**Key constraints**:
- Build toolchain: Heft-based (not gulp) from SPFx 1.22+
- Fluent UI: **@fluentui/react v8** — this is the SPFx-bundled version; do not use v9
- Teams SDK: Use `this.context.sdks.microsoftTeams` — do not install separate `@microsoft/teams-js`

**Teams context detection**:
```typescript
const inTeams = !!this.context.sdks.microsoftTeams;
if (inTeams) {
  const ctx = await this.context.sdks.microsoftTeams.teamsJs.app.getContext();
  // Teams-specific rendering
}
```

---

### D-005: Dark Theme — Scoped SCSS, Not SPFx ThemeProvider

**Decision**: Apply Dark Factory palette as scoped SCSS CSS custom property overrides inside the web part's `.module.scss` files, wrapped in a Fluent UI v8 `ThemeProvider` with a programmatically created dark theme object.

**Rationale**: SPFx's `ThemeProvider` / `getTheme()` reads the **site theme** set by the SharePoint Admin — it cannot be driven from inside the web part at runtime. For a scoped dark theme that works regardless of site theme, the correct pattern is:
1. Create a Fluent UI theme object via `createTheme({ palette: {...} })`
2. Wrap the root component in `<ThemeProvider theme={darkFactoryTheme}>`
3. Override specific colours with scoped SCSS CSS custom properties for non-Fluent elements

This gives full Dark Factory aesthetics without requiring a tenant-level theme change, and works in both SharePoint and Teams contexts.

---

### D-006: Caching Strategy — localStorage with Scoped Keys and Expiry

**Decision**: `localStorage` with web part manifest ID prefix, JSON-serialised with expiry timestamp

**Pattern**:
- Key format: `spfx_{manifestId}_weather_cache`
- Value: `{ data: WeatherReading, timestamp: number }`
- Expiry: never block display (always show cached), but set `DisplayState.stale` after 30 minutes
- Quota guard: catch `QuotaExceededError` and fall back silently to uncached state

**Rationale**: Weather data is small (< 5KB). localStorage is synchronous and appropriate for this use case. No need for IndexedDB for this payload size. PnP caching decorators are an option but add a dependency for minimal gain.

---

### D-007: Auto-Refresh — Page Visibility API Pattern

**Decision**: Custom `useAutoRefresh` React hook using `document.visibilitychange` event

**Behaviour**:
1. On mount: start 5-minute `setInterval`, fetch immediately
2. On tab hidden (`document.hidden === true`): clear interval
3. On tab visible: fetch immediately, restart interval
4. On unmount: clear interval, remove event listener

This prevents unnecessary Open-Meteo calls when the tab is in the background and ensures data is fresh immediately on re-focus.

---

### D-008: Config Store — SharePoint List `DarkFactory-Settings`

**Decision**: SharePoint list on the DarkFactory team site with these columns:

| Column | Type | Required | Notes |
|---|---|---|---|
| Title (Key) | Single line text | Yes | Unique config key name |
| Value | Single line text | Yes | Config value as string |
| Description | Multiple lines text | No | Human-readable description |
| Category | Choice | No | e.g., Weather, General, Spec002 |

**Permissions**: Break inheritance — Visitors (Read), Site Owner/Admin (Full Control)

**Access pattern**: SPFx reads via `spHttpClient` using OData `$filter=Title eq '{key}'&$select=Title,Value`. All family members need at minimum **Visitor** access to the DarkFactory team site.

**Config keys for Spec 001**:

| Key | Example Value | Description |
|---|---|---|
| `Weather.Latitude` | `-36.8509` | Home latitude (WGS84) |
| `Weather.Longitude` | `174.7645` | Home longitude (WGS84) |
| `Weather.Timezone` | `Pacific/Auckland` | IANA timezone |
| `Weather.LocationName` | `Home` | Display name |
| `Weather.ApiBaseUrl` | `https://api.open-meteo.com/v1/forecast` | API endpoint |
| `Weather.TemperatureUnit` | `celsius` | celsius or fahrenheit |
| `Weather.RefreshIntervalMinutes` | `5` | Polling interval |

---

### D-009: SPFx Property Pane — Config List Name Only

**Decision**: Property pane stores one field: `configListName` (default: `DarkFactory-Settings`). All runtime config lives in the SharePoint list.

**Rationale**: Keeps the web part portable — it can be pointed at a different config list without code changes. The property pane is the only place where a "meta-configuration" value (what list to read from) is appropriate.

---

### D-010: Deployment Prerequisites Summary

In order of execution:

1. ✅ Confirm Microsoft 365 Business subscription (RISK-001)
2. Provision tenant App Catalog (if not exists): `Register-PnPAppCatalogSite`
3. Create DarkFactory Teams team and General channel (if not exists)
4. Add `api.open-meteo.com` to CSP allowlist: `Add-SPOContentSecurityPolicy -Source "https://api.open-meteo.com"`
5. Create `DarkFactory-Settings` SharePoint list with broken permissions
6. Populate config keys
7. Build SPFx package: `gulp bundle --ship && gulp package-solution --ship`
8. Deploy to App Catalog: `Add-PnPApp -Path ./sharepoint/solution/*.sppkg -Publish -SkipFeatureDeployment`
9. Create SharePoint page on DarkFactory team site, add web part, publish page
10. Add SharePoint page as native Teams tab in General channel

---

### D-011: Testing Strategy

| Test type | Scope | Tool |
|---|---|---|
| Unit | ForecastPeriodMapper, WeatherCodeMapper, CacheService | Jest |
| Unit | WeatherService (mock fetch) | Jest + jest-fetch-mock |
| Unit | ConfigService (mock spHttpClient) | Jest |
| Component | CurrentConditions, ForecastStrip, ForecastDays, StatusBar | Jest + React Testing Library |
| Accessibility | All components | jest-axe (axe-core) |
| Manual | Teams tab, SharePoint page, mobile, keyboard nav | Manual checklist |
