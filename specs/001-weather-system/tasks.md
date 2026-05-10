# Tasks: Weather Display System

**Branch**: `001-weather-system` | **Date**: 2026-05-10 | **Plan**: [plan.md](plan.md) | **Spec**: [spec.md](spec.md)
**SPFx project root**: `dark-factory-weather/` (separate directory, scaffolded in Phase 1)

**Tests**: Included — plan.md explicitly specifies unit tests for all services, mappers, and hooks; jest-axe for all components.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no shared state dependencies)
- **[Story]**: Which user story this task belongs to ([US1], [US2], [US3])
- All paths are relative to the `dark-factory-weather/` SPFx project root unless noted otherwise

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: SPFx project scaffold and tooling configuration. Must complete before any source files are authored.

- [ ] T001 Scaffold SPFx project: run `yo @microsoft/sharepoint` in a new `dark-factory-weather/` directory — solution name `dark-factory-weather`, target SharePoint Online only, enable Teams, web part name `DarkFactoryWeather`, framework React (per quickstart.md)
- [ ] T002 Install additional dependencies: `npm install @fluentui/react@8` and `npm install --save-dev jest @testing-library/react @testing-library/jest-dom jest-axe jest-fetch-mock`
- [ ] T003 [P] Configure `tsconfig.json` path aliases: `@models/*`, `@services/*`, `@mappers/*`, `@hooks/*`, `@components/*` pointing to `src/webparts/darkFactoryWeather/` subdirectories
- [ ] T004 [P] Configure `config/serve.json` `initialPage` to `https://aiwhisperer.sharepoint.com/sites/DarkFactory/_layouts/workbench.aspx`
- [ ] T005 [P] Configure Jest in `jest.config.js` with TypeScript + tsconfig path alias resolution, jsdom test environment, jest-fetch-mock setup file, and jest-axe matcher

**Checkpoint**: `gulp serve` starts without errors; workbench opens on DarkFactory site

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: All TypeScript models (pure interfaces — no logic), SCSS palette tokens, ConfigService, SPFx entry point, and root component skeleton. Everything in this phase is a hard dependency for at least one user story.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T006 [P] Create `src/webparts/darkFactoryWeather/models/DisplayState.ts` — `DisplayState` enum with values: `Loading`, `Live`, `Cached`, `SetupRequired`, `Error` (per data-model.md)
- [ ] T007 [P] Create `src/webparts/darkFactoryWeather/models/IWeatherReading.ts` — `IWeatherReading` interface (temperature, feelsLike, humidity, uvIndex, windSpeed, windDirection, weatherCode, conditionLabel, isRain, observedAt, sunrise, sunset, uvIndexMax — per data-model.md)
- [ ] T008 [P] Create `src/webparts/darkFactoryWeather/models/IForecastPeriod.ts` — `PeriodName` type, `DayName` type, `IForecastPeriod` interface (name, isToday, tempMin, tempMax, weatherCode, conditionLabel, isRain, precipitationMm — per data-model.md)
- [ ] T009 [P] Create `src/webparts/darkFactoryWeather/models/IHomeLocation.ts` — `IHomeLocation` interface (displayName, city, latitude, longitude, timezone — per data-model.md)
- [ ] T010 [P] Create `src/webparts/darkFactoryWeather/models/IWeatherConfig.ts` — `IWeatherConfig` interface (location: IHomeLocation, apiBaseUrl, temperatureUnit, refreshIntervalMinutes — per data-model.md)
- [ ] T011 [P] Create `src/webparts/darkFactoryWeather/models/IConfigEntry.ts` — `IConfigEntry` interface (key, value — internal mapping of SharePoint list Title → DFValue)
- [ ] T012 Create `src/webparts/darkFactoryWeather/components/DarkFactoryWeather.module.scss` — define all 8 Dark Factory palette CSS custom properties: `--df-bg: #0D1117`, `--df-surface: #161B22`, `--df-border: #30363D`, `--df-text-primary: #F0F6FC`, `--df-text-secondary: #9CA4B0`, `--df-accent: #22D3EE`, `--df-rain: #3B82F6`, `--df-warning: #F59E0B`
- [ ] T013 Implement `src/webparts/darkFactoryWeather/services/ConfigService.ts` — reads all 8 `Weather.*` keys from `DarkFactory-Settings` list in parallel via `spHttpClient` REST API (`?$filter=Title eq '{key}'&$select=Title,DFValue`); assembles `IWeatherConfig`; validates required keys (`Weather.Latitude`, `Weather.Longitude`, `Weather.Timezone`, `Weather.LocationName`, `Weather.ApiBaseUrl`) and coordinate/integer formats; throws typed `ConfigError` with missing key names on failure (per contracts/sharepoint-config-list.md)
- [ ] T014 Write unit tests for `ConfigService` in `tests/unit/ConfigService.test.ts` — mock `spHttpClient`; assert: all 8 keys present → correct `IWeatherConfig` assembled with parsed floats/integers; required key missing → `ConfigError` thrown listing missing key; `Weather.Latitude` non-numeric → `ConfigError`; optional key absent → default value used
- [ ] T015 Create `src/webparts/darkFactoryWeather/DarkFactoryWeatherWebPart.ts` SPFx entry point — `onInit()` instantiates `ConfigService` (injected with `this.context.spHttpClient` and `this.context.pageContext.web.absoluteUrl`); property pane exposes one field: config list name (default `DarkFactory-Settings`); passes services as props to root component
- [ ] T016 Create `src/webparts/darkFactoryWeather/components/DarkFactoryWeather.tsx` root component skeleton — owns `displayState` (starts `Loading`), `weatherData: IWeatherReading | null`, `lastUpdated: Date | null` state; on mount calls `ConfigService`; on `ConfigError` transitions to `SetupRequired`; on unhandled error transitions to `Error`; renders correct child based on `displayState` with no data logic in JSX; apply `--df-bg` background from module SCSS

**Checkpoint**: `gulp serve` → web part loads in workbench → shows Loading spinner → transitions to SetupRequired (config list not yet populated)

---

## Phase 3: User Story 1 — View Current Weather Conditions (Priority: P1) 🎯 MVP

**Goal**: Live current weather data displayed with full Dark Factory styling and auto-refresh.

**Independent Test**: Open Teams tab → current temperature, feels-like, wind, humidity, UV, sunrise, sunset appear for configured home location → wait 5 min → data refreshes without page reload.

### Tests for User Story 1

> **Write tests FIRST — verify they FAIL before implementing the corresponding source**

- [ ] T017 [P] [US1] Write unit tests for `WeatherCodeMapper` in `tests/unit/WeatherCodeMapper.test.ts` — assert: WMO codes 51–67 → `isRain: true`; codes 80–82 → `isRain: true`; codes 95/96/99 → `isRain: true`; code 0 → `isRain: false`; unknown code → safe default label and `isRain: false`
- [ ] T018 [P] [US1] Write unit tests for `WeatherService` in `tests/unit/WeatherService.test.ts` — mock `fetch` using jest-fetch-mock with fixture JSON matching `OpenMeteoResponse` shape; assert: correct `IWeatherReading` assembled (temperature, windDirection compass mapping, isRain derived from weatherCode); HTTP 4xx/5xx → throws `WeatherFetchError`; network error → throws `WeatherFetchError`
- [ ] T021 [US1] Write unit tests for `CacheService` in `tests/unit/CacheService.test.ts` — assert: `save` → `load` round-trip returns original data; `isStale` returns `false` for data < 30 min old, `true` for ≥ 30 min; `QuotaExceededError` on `save` → handled silently, `load` returns `null`; localStorage unavailable → `load` returns `null`

### Implementation for User Story 1

- [ ] T019 [P] [US1] Create `src/webparts/darkFactoryWeather/mappers/WeatherCodeMapper.ts` — static WMO code lookup table (code → `{ label: string; isRain: boolean }`); exported pure function `getWeatherCode(code: number)`; `isRain` formula: `(code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95`; safe default for unknown codes
- [ ] T020 [P] [US1] Create `src/webparts/darkFactoryWeather/services/CacheService.ts` — `save(data: IWeatherReading, periods: IForecastPeriod[], forecastDays: IForecastPeriod[]): void` with scoped localStorage key + ISO timestamp; `load(): CachedWeatherData | null` returns null if localStorage unavailable or key absent; `isStale(timestamp: Date): boolean` true if older than 30 minutes; catches `QuotaExceededError` silently
- [ ] T022 [US1] Implement `src/webparts/darkFactoryWeather/services/WeatherService.ts` — `fetch(config: IWeatherConfig): Promise<{ reading: IWeatherReading; periods: IForecastPeriod[]; forecastDays: IForecastPeriod[] }>`; builds Open-Meteo URL from config per `contracts/open-meteo-api.md` (all required parameters); maps `OpenMeteoCurrent` → `IWeatherReading` using `WeatherCodeMapper`; maps `daily[0]` sunrise/sunset; maps `daily[1..2]` → `forecastDays` (stub — full mapping in T031); on any error throws typed `WeatherFetchError`
- [ ] T023 [US1] Create `src/webparts/darkFactoryWeather/hooks/useAutoRefresh.ts` — `useAutoRefresh(onRefresh: () => Promise<void>, intervalMs: number): void`; calls `onRefresh` on mount; starts `setInterval`; on `visibilitychange` hidden → clears interval; on `visibilitychange` visible → calls `onRefresh` immediately then restarts interval; clears interval and removes listener on unmount
- [ ] T024 [US1] Write unit tests for `useAutoRefresh` in `tests/unit/useAutoRefresh.test.ts` — mock `document.visibilityState`; assert: `onRefresh` called on mount; interval cleared on hidden; `onRefresh` called immediately on visible; interval cleared on unmount
- [ ] T025 [US1] Wire `WeatherService`, `CacheService`, and `useAutoRefresh` into `DarkFactoryWeather.tsx` — on successful config: call `WeatherService.fetch()`, save to `CacheService`, set state to `Live` with data; on `WeatherFetchError`: load `CacheService`, set state to `Cached` (if data present) or `Error` (first load); pass `onRefresh` to `useAutoRefresh` with interval from config
- [ ] T026 [P] [US1] Implement `src/webparts/darkFactoryWeather/components/CurrentConditions/CurrentConditions.tsx` — props: `reading: IWeatherReading`; renders using Fluent UI `Stack` and `Text`: large bold temperature, feels-like, condition label (apply `--df-rain` colour when `isRain`), wind speed + compass direction label (N/NE/E/SE/S/SW/W/NW from degrees), humidity %, UV index (hidden if `null`), sunrise time, sunset time; all data points have `aria-label` with units spelled out (e.g., `aria-label="22 degrees Celsius"`); apply Dark Factory SCSS tokens
- [ ] T027 [P] [US1] Implement `src/webparts/darkFactoryWeather/components/StatusBar/StatusBar.tsx` — props: `state: DisplayState; lastUpdated: Date | null; missingKeys?: string[]`; renders: `Live`/`Cached` → small "Updated {time}" in `--df-text-secondary`; `Stale` (≥ 30 min — see T034 for staleness detection) → amber `--df-warning` indicator + "Data may be outdated — last updated {time}"; `Error` → error message for first-load case; all text has `role="status"` or `aria-live`

**Checkpoint**: Full current-conditions display with auto-refresh working in workbench. Data visible < 3s. Staleness warning appears when data > 30 min old.

---

## Phase 4: User Story 2 — View Today's Remaining Forecast and 3-Day Outlook (Priority: P2)

**Goal**: Today remaining grouped forecast periods and 2-day outlook displayed with rain visual distinction.

**Independent Test**: Load web part at different times of day (e.g., afternoon) — only remaining periods appear (Afternoon, Evening, Tonight); 2-day forecast shows correct day names, high/low, condition; rain periods show accent border.

### Tests for User Story 2

- [ ] T029 [P] [US2] Write unit tests for `ForecastPeriodMapper` in `tests/unit/ForecastPeriodMapper.test.ts` — given full-day hourly fixture data: at 14:00 returns `[Afternoon, Evening, Tonight]`; at 22:00 returns `[Tonight]`; at 00:30 returns all 4 periods (Morning, Afternoon, Evening, Tonight); verify precipitation summing; verify condition uses max WMO severity; verify temperature min/max aggregation

### Implementation for User Story 2

- [ ] T030 [P] [US2] Implement `src/webparts/darkFactoryWeather/mappers/ForecastPeriodMapper.ts` — `mapTodayPeriods(hourly: OpenMeteoHourly, now: Date): IForecastPeriod[]`; period boundaries: Morning 06–11, Afternoon 12–17, Evening 18–20, Tonight 21–23; filters out periods where all hours have already passed; aggregates: tempMin/tempMax, condition (max WMO code = most severe), precipitationMm (sum); `mapForecastDays(daily: OpenMeteoDaily, now: Date): IForecastPeriod[]`; maps `daily.time[1]` and `daily.time[2]` to `IForecastPeriod` with day names (e.g., "Tomorrow", "Wednesday")
- [ ] T031 [US2] Extend `WeatherService.fetch()` in `src/webparts/darkFactoryWeather/services/WeatherService.ts` to map hourly data → today remaining periods using `ForecastPeriodMapper.mapTodayPeriods()` and `daily[1..2]` → forecast days using `ForecastPeriodMapper.mapForecastDays()`; update unit test fixture in T018 to assert `periods` and `forecastDays` mapping
- [ ] T032 [P] [US2] Implement `src/webparts/darkFactoryWeather/components/ForecastStrip/ForecastStrip.tsx` — props: `periods: IForecastPeriod[]`; renders remaining today periods as horizontal Fluent UI cards (Morning / Afternoon / Evening / Tonight); rain periods (`isRain: true`) get `--df-rain` left border; component is hidden (`return null`) if `periods.length === 0`; each card has period name, condition label, temp range
- [ ] T033 [P] [US2] Implement `src/webparts/darkFactoryWeather/components/ForecastDays/ForecastDays.tsx` — props: `days: IForecastPeriod[]`; renders 2 day cards with day name, high/low temperature, condition label; rain days get same `--df-rain` visual treatment as `ForecastStrip`
- [ ] T034 [US2] Update `DarkFactoryWeather.tsx` root component to: (1) render `ForecastStrip` and `ForecastDays` with `periods`/`forecastDays` from `WeatherService`; (2) detect staleness — compare `lastUpdated` against 30-min threshold and pass `Stale` vs `Cached` vs `Live` display state to `StatusBar`

**Checkpoint**: Full weather display — current conditions + today remaining forecast (only future periods) + 2-day outlook. Rain periods visually distinguished. Sections hide gracefully when data absent.

---

## Phase 5: User Story 3 — Manage Home Location and Configuration (Priority: P3)

**Goal**: Admin sets up config store once; web part reads it transparently. Missing config shows a friendly actionable message, not an error.

**Independent Test**: Delete a required key from `DarkFactory-Settings` → reload web part → setup guidance message appears listing the missing key and linking to the list. Re-add key → reload → weather appears.

### Implementation for User Story 3

- [ ] T035 [P] [US3] Implement `SetupRequired` display state rendering in `DarkFactoryWeather.tsx` — when `ConfigError` caught, store `missingKeys: string[]` in component state; render amber banner using `--df-warning` that lists missing key names in a `<ul>` and provides a direct link to the DarkFactory-Settings list admin URL (constructed from site URL)
- [ ] T036 [P] [US3] Update `StatusBar.tsx` — when `state === SetupRequired` render the setup guidance message: "Configuration incomplete — missing keys: {list}. Open [DarkFactory-Settings] to add them." with the list link; use `role="alert"` for screen reader announcement
- [ ] T037 [US3] Validate `ConfigService` handles all 8 config keys per `contracts/sharepoint-config-list.md` and quickstart.md seed data — cross-check: required keys fail loudly, optional keys (`Weather.City`, `Weather.TemperatureUnit`, `Weather.RefreshIntervalMinutes`) use documented defaults when absent; update unit tests if gaps found

**Checkpoint**: Admin experience fully functional — clear setup guidance when config missing, seamless weather display once configured

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Teams context detection, responsive layout, accessibility audit, and production deployment.

- [ ] T038 [P] Implement Teams context detection in `DarkFactoryWeatherWebPart.ts` `onInit()` — check `this.context.sdks.microsoftTeams`; set `isTeams: boolean` and pass as prop to `DarkFactoryWeather.tsx`; use `isTeams` only for minor layout padding adjustment (no functional difference)
- [ ] T039 [P] Add responsive layout in `DarkFactoryWeather.module.scss` — media query at `768px` breakpoint: below → `ForecastStrip` periods stack vertically, `ForecastDays` cards stack vertically; above → horizontal card row; verify no horizontal overflow on 320px viewport
- [ ] T040 [P] Add `jest-axe` accessibility assertions to component tests — test `CurrentConditions`, `ForecastStrip`, `ForecastDays`, `StatusBar` with `toHaveNoViolations()` from jest-axe; fix any reported violations before marking complete
- [ ] T041 Verify keyboard tab order across the web part — expected: `StatusBar` → `CurrentConditions` → `ForecastStrip` → `ForecastDays`; add explicit `tabIndex` or `role` attributes where browser default order is incorrect
- [ ] T042 [P] Update `DarkFactoryWeatherWebPart.manifest.json` — set correct `title`, `description`, and reference a monochrome icon SVG matching Dark Factory aesthetic; required for App Catalog display
- [ ] T043 Build production package: run `gulp bundle --ship && gulp package-solution --ship` in `dark-factory-weather/`; verify `sharepoint/solution/dark-factory-weather.sppkg` is generated without errors
- [ ] T044 Deploy and verify: run App Catalog deploy command from quickstart.md (`Add-PnPApp ... -SkipFeatureDeployment`); create modern SharePoint page, add web part, publish; add as SharePoint tab in Teams DarkFactory → General; run all verification checklist items from quickstart.md

**Checkpoint**: Web part passes jest-axe, keyboard-navigable, renders correctly in both Teams and SharePoint, deployed to App Catalog and live in Teams tab

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 completion — **BLOCKS all user stories**
- **US1 (Phase 3)**: Depends on Phase 2 completion — no dependency on US2 or US3
- **US2 (Phase 4)**: Depends on Phase 2 completion; T031 extends `WeatherService` from T022 (US1 must complete first to avoid conflicts)
- **US3 (Phase 5)**: Depends on Phase 2 completion; T035/T036 extend root component from T025/T027 (US1 must complete first)
- **Polish (Phase 6)**: Depends on all story phases complete

### Within Each User Story

- Tests (T017, T018, T021, T024, T029) written and confirmed FAILING before implementing the corresponding source
- Models (T006–T011) before services and mappers
- Mappers (T019, T030) before services that consume them (T022, T031)
- Services (T013, T020, T022) before components that render their output
- Components (T026, T027, T032, T033) before wiring into root (T025, T034)

### Key Within-Phase Dependencies

| Task | Depends on |
|---|---|
| T022 WeatherService | T019 WeatherCodeMapper |
| T025 Root component wiring | T022 WeatherService, T020 CacheService, T026 CurrentConditions, T027 StatusBar |
| T031 Extend WeatherService | T030 ForecastPeriodMapper |
| T034 Root forecast wiring | T031 extended WeatherService, T032 ForecastStrip, T033 ForecastDays |
| T035 SetupRequired UI | T016 Root component shell |
| T043 Build | All source tasks complete |
| T044 Deploy | T043 Build |

### Parallel Opportunities

All tasks marked `[P]` within the same phase can run simultaneously (they target different files with no shared write conflicts):
- T006–T011: All 6 model files in parallel
- T003, T004, T005: All tooling config files in parallel
- T017, T018, T021: All US1 test files in parallel
- T019, T020: WeatherCodeMapper + CacheService in parallel
- T026, T027: CurrentConditions + StatusBar in parallel
- T029: ForecastPeriodMapper tests while US1 implementation completes
- T030: ForecastPeriodMapper while WeatherService (T022) completes
- T032, T033: ForecastStrip + ForecastDays in parallel
- T035, T036: SetupRequired UI + StatusBar update in parallel
- T038, T039, T040, T041, T042: All polish tasks in parallel

---

## Parallel Example: Phase 2 Foundational Models

```
# Launch all 6 model files simultaneously:
Task: "T006 — Create DisplayState.ts"
Task: "T007 — Create IWeatherReading.ts"
Task: "T008 — Create IForecastPeriod.ts"
Task: "T009 — Create IHomeLocation.ts"
Task: "T010 — Create IWeatherConfig.ts"
Task: "T011 — Create IConfigEntry.ts"

# Then sequentially:
Task: "T012 — SCSS palette tokens"
Task: "T013 — ConfigService (depends on models)"
Task: "T014 — ConfigService unit tests"
Task: "T015 — SPFx entry point (depends on ConfigService)"
Task: "T016 — Root component skeleton (depends on entry point)"
```

---

## Implementation Strategy

### MVP (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks everything)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Open Teams workbench tab → live weather data, auto-refresh, staleness warning
5. Deploy MVP to App Catalog and Teams tab

### Incremental Delivery

1. Complete Setup + Foundational → web part loads, shows SetupRequired
2. Add US1 → current weather live → deploy MVP
3. Add US2 → forecast panels → deploy update
4. Add US3 → setup error guidance → deploy update
5. Polish → accessibility + responsive + App Catalog deployment

---

## Summary

| Phase | Tasks | Parallelizable | Story |
|---|---|---|---|
| Phase 1: Setup | T001–T005 | T003, T004, T005 | — |
| Phase 2: Foundational | T006–T016 | T006–T011 | — |
| Phase 3: US1 (P1) | T017–T027 | T017, T018, T019, T020, T021, T024, T026, T027 | US1 |
| Phase 4: US2 (P2) | T029–T034 | T029, T030, T032, T033 | US2 |
| Phase 5: US3 (P3) | T035–T037 | T035, T036 | US3 |
| Phase 6: Polish | T038–T044 | T038, T039, T040, T041, T042 | — |
| **Total** | **44 tasks** | **28 parallelizable** | |
