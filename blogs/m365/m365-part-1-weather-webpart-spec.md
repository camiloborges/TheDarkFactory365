# The Weather Web Part Specification

_Part 1 of the M365 series_

**TL;DR**  
Before a single TypeScript file is created, we write the full specification for the DarkFactory weather web part using the Claude Code Spec Kit. This post walks through every artifact: the research decisions, the surface matrix, the acceptance criteria in GIVEN/WHEN/THEN format, the architecture constraints, and the permission manifest. When we're done, the implementation has no open questions.

---

## 1. The Specification Header

Every Spec Kit feature starts with a `spec.md` file that anchors all requirements. The header establishes scope, priority, and the decisions already made before requirements are written.

---

**Feature**: `001-weather-system`  
**Status**: Approved  
**Scope note**: Covers the central configuration store and weather display web part only. Rain alert automation is Spec 002.  
**Teams deployment target**: Team `DarkFactory`, channel `General`

### Summary

A dark-themed SharePoint Framework (SPFx) web part that displays current weather conditions and a period-based forecast for the home location. The solution runs as a Teams channel tab pinned to the DarkFactory General channel. All configuration — home coordinates, timezone, API endpoint — comes from the `DarkFactory-Settings` SharePoint list provisioned by Spec 003. Nothing is hardcoded; nothing is in the web part property pane.

### Goals

- Display current weather conditions (temperature, feels-like, humidity, wind, UV index, sunrise/sunset)
- Display today's remaining forecast in grouped periods (Morning / Afternoon / Evening / Tonight)
- Display a two-day outlook beyond today
- Read all configuration from the central `DarkFactory-Settings` SharePoint list
- Present the Dark Factory visual identity: dark background, electric accent colour, WCAG 2.1 AA contrast throughout

### Non-Goals (explicitly out of scope for v1.0)

- Viva Connections dashboard card
- Push notifications or weather alerts (that is Spec 002)
- Multi-location comparison
- Historical weather data
- Teams personal app tab (channel tab only)
- Property pane configuration (all config is administrator-managed in the SharePoint list)

---

## 2. The Surface Matrix

Before writing acceptance criteria, we enumerate every surface and its constraints. In M365, this step catches the failures that kill projects in production — not in development.

| Surface | SPFx Host | Auth context | Size constraint | CSP constraints |
|---|---|---|---|---|
| Teams channel tab (DarkFactory General) | `TeamsTab` | Teams context + SharePoint delegated | Full tab viewport | Teams CSP — no inline scripts |
| SharePoint modern page (fallback) | `SharePointWebPart` | SharePoint user token | Configurable zone width | Tenant CSP policy |
| Viva Connections | Out of scope v1.0 | — | — | — |

**Decision record:** Teams personal tab excluded — personal tabs require an app manifest and separate Teams App registration outside the scope of v1.0. The web part is deployed as a channel tab in the DarkFactory team, which uses the same native SharePoint tab type and requires no additional app registration.

**CSP decision record:** SharePoint Online CSP enforcement went live in March 2026. The web part makes client-side fetch requests to `api.open-meteo.com`. That domain must be added to the tenant CSP allowlist via `Add-SPOContentSecurityPolicy` before the web part can make API calls. This is handled by Spec 003 (tenant infrastructure provisioning) — it is not the web part's responsibility.

---

## 3. Research: External Weather API Selection

This decision was resolved in `research.md` before planning began. Every unknown that could block implementation was closed before a single task was written.

### Options Evaluated

| Option | Pros | Cons | Decision |
|---|---|---|---|
| **Open-Meteo** | Free, no API key, no account, full CORS, returns all required data in one call | Less name recognition | **Selected** |
| OpenWeatherMap Free Tier | Widely known | Requires API key (storage/security concern), HTTP only on free tier | Rejected |
| MSN Weather (via Graph) | M365-native, no external dependency | Undocumented, unsupported, has broken without notice twice in 18 months — explicit constitution violation | Rejected |
| Azure Maps Weather | First-party Azure, SLA-backed | Paid, adds Azure billing for something Open-Meteo covers free | Deferred to enterprise variant |
| Weather.gov | Free, no key | US only | Rejected |

### Selected: Open-Meteo

- **Endpoint:** `https://api.open-meteo.com/v1/forecast`
- **API key:** None required — zero friction for household use
- **Single API call** returns: current conditions, hourly forecast, daily forecast, UV index, sunrise/sunset, precipitation probability
- **Fair use limit:** ~10,000 req/day; 5-minute polling from one household = 288 req/day
- **CORS:** Full (`Access-Control-Allow-Origin: *`) — direct browser fetch from SPFx works without a proxy

**Rejection rationale for MSN Weather:** Not part of any published Microsoft API contract. A production solution that depends on an undocumented endpoint violates Principle II of the project constitution: _All solutions MUST use official, supported Microsoft 365 extension points only._

**No API key consequence:** The `DarkFactory-Settings` list stores the API base URL (`Weather.ApiBaseUrl`) so that it can be overridden for staging or testing. But there is no credential to store, rotate, or protect.

---

## 4. The Constitution Gates

These are ACCEPT/REJECT gates. Any implementation decision that hits a REJECT is blocked without a spec amendment.

```
REJECT: Location hardcoded in the web part
REJECT: API endpoint hardcoded in the web part
REJECT: Inline <script> tags or eval() — fails Teams CSP
REJECT: External API calls on every render without caching
REJECT: Any colour with < 4.5:1 contrast ratio against the background (WCAG 2.1 AA)
REJECT: Dependency on any undocumented Microsoft API

ACCEPT: All configuration read from DarkFactory-Settings SharePoint list at load time
ACCEPT: SPFx HttpClient for all external requests (respects tenant proxy/CSP)
ACCEPT: 5-minute auto-refresh interval (configurable via DarkFactory-Settings)
ACCEPT: Last-known-data fallback when API is unreachable, with visible staleness warning
ACCEPT: Fluent UI v8 as the structural foundation; Dark Factory SCSS tokens as overlay
ACCEPT: WCAG 2.1 AA verified for every colour pair before implementation begins
```

---

## 5. Acceptance Criteria

Requirements in GIVEN/WHEN/THEN format. These are the direct inputs to test cases — each scenario becomes a unit or integration test assertion.

---

### REQ-001: Current Weather Display

**GIVEN** the web part is loaded on the Teams tab  
**AND** the home location is configured in `DarkFactory-Settings`  
**AND** the Open-Meteo API is reachable  
**WHEN** the page renders  
**THEN** the web part displays:
- Current temperature (°C)
- Feels-like temperature
- Weather condition label (from WMO weather code interpretation)
- Wind speed and direction
- Humidity percentage
- UV index
- Today's sunrise and sunset times

**GIVEN** the Open-Meteo API returns an error or is unreachable  
**WHEN** the page renders  
**THEN** the web part displays the last known data  
**AND** shows a visible "Data may be outdated — last updated [timestamp]" banner  
**AND** does not display a broken layout or raw error text

**GIVEN** required configuration keys are missing from `DarkFactory-Settings`  
**WHEN** the web part loads  
**THEN** it displays a friendly setup guidance message explaining what is missing  
**AND** does not show a JavaScript error or broken layout

---

### REQ-002: Today's Remaining Forecast

**GIVEN** the web part is loaded at any time of day  
**WHEN** the forecast section renders  
**THEN** it shows only the grouped periods that have not yet passed:
- Morning (06:00–11:59)
- Afternoon (12:00–17:59)
- Evening (18:00–20:59)
- Tonight (21:00–05:59)

**GIVEN** the web part is loaded at 20:30 (Evening is current)  
**WHEN** the forecast section renders  
**THEN** Morning and Afternoon are not shown — only Evening and Tonight are visible

**GIVEN** it is after 22:00 with no remaining periods today  
**WHEN** the web part renders  
**THEN** the today-remaining section is hidden gracefully (not blank, not broken)

**GIVEN** a forecast period includes rain  
**WHEN** the web part renders  
**THEN** the period is visually distinguished with a rain indicator and the accent colour shifts from cyan to blue

---

### REQ-003: Two-Day Outlook

**GIVEN** the web part is loaded  
**WHEN** viewing the daily forecast section  
**THEN** it displays two calendar days beyond today, each showing:
- Day name formatted in the user's locale
- High temperature
- Low temperature
- Dominant weather condition

---

### REQ-004: Configuration from SharePoint List

**GIVEN** the administrator has populated the `DarkFactory-Settings` list with `Weather.*` keys  
**WHEN** the web part initialises  
**THEN** it reads `Weather.Latitude`, `Weather.Longitude`, `Weather.Timezone`, `Weather.ApiBaseUrl`, `Weather.TemperatureUnit`, and `Weather.RefreshIntervalMinutes` from the list  
**AND** none of these values are hardcoded in the web part bundle

**GIVEN** the administrator updates `Weather.Latitude` in the `DarkFactory-Settings` list  
**WHEN** the web part next loads or auto-refreshes  
**THEN** it uses the updated value without any code change or redeployment

**GIVEN** `Weather.RefreshIntervalMinutes` is set to `5`  
**WHEN** the web part has been open for 5 minutes  
**THEN** it automatically fetches fresh weather data without any user action

---

### REQ-005: Auto-Refresh and Caching

**GIVEN** the web part has fetched weather data  
**WHEN** the auto-refresh interval has not yet elapsed  
**THEN** the web part does not make a new API call — it displays the in-memory cached data

**GIVEN** the auto-refresh interval elapses  
**WHEN** the API fetch succeeds  
**THEN** the display updates with the fresh data and the staleness banner (if visible) is cleared

**GIVEN** the auto-refresh interval elapses  
**WHEN** the API fetch fails  
**THEN** the display retains the previous data  
**AND** the staleness banner appears (or remains) with an updated timestamp

---

### REQ-006: Visual Identity

**GIVEN** the web part renders in any context  
**WHEN** a colour pair is used for text against a background  
**THEN** the contrast ratio meets WCAG 2.1 AA (≥ 4.5:1 for body text, ≥ 3:1 for large text)

**GIVEN** the web part renders on the Teams tab  
**WHEN** no weather error exists  
**THEN** the accent colour is electric cyan (`#22D3EE`)

**GIVEN** any currently-active forecast period includes rain or precipitation probability > 40%  
**WHEN** the web part renders  
**THEN** the accent colour is blue (`#3B82F6`) as a rain indicator

---

## 6. Architecture Decisions

| Decision | Choice | Rationale |
|---|---|---|
| SPFx version | 1.18.x (latest stable at time of build) | Required for Teams tab deployment and Fluent UI v8 compatibility |
| UI framework | React + Fluent UI v8 | Constitution mandate: Fluent UI v8 for SPFx solutions; v9 not yet stable for SPFx at time of build |
| State management | React hooks only | Single-component scope; Redux adds complexity the spec does not justify |
| API communication | Native `fetch` via SPFx context | Open-Meteo has full CORS; SPFx HttpClient not required when CORS is available |
| Configuration source | `DarkFactory-Settings` SharePoint list | Central store shared across all TheDarkFactory365 solutions — constitution principle (DRY) |
| Styling | Fluent UI v8 tokens + Dark Factory SCSS overlay | No hardcoded hex values except in the SCSS token file; required for Teams theme compatibility |
| Testing | Jest + React Testing Library | SPFx standard; avoids Workbench dependency in unit tests |
| Forecast grouping | WMO weather code → period block mapping | Open-Meteo returns WMO codes; mapping is a pure function, easily unit-tested |

---

## 7. Permission Manifest

This maps directly to `package-solution.json`. Open-Meteo requires no OAuth scopes — there is no account and no credential. The only platform requirement is the CSP allowlist entry, which is handled at the tenant level by Spec 003.

```json
{
  "isDomainIsolated": false,
  "webApiPermissionRequests": [],
  "externalDomains": []
}
```

**No Graph permissions**: The web part reads no user data from Graph. Location, timezone, and units come from the SharePoint list.

**No `externalDomains` in the manifest**: The CSP allowlist entry for `api.open-meteo.com` is added to the tenant via `Add-SPOContentSecurityPolicy`, which is the correct mechanism for SPFx solutions calling external domains. Listing the domain in the web part manifest alone would not satisfy the tenant CSP policy.

---

## 8. What Comes Next

With this specification written and every unknown resolved, the implementation has no surprises. The next steps in the Spec Kit workflow are:

1. **`/speckit-plan`** — produce the implementation plan: project structure, phased delivery, dependency order, constitution check
2. **`/speckit-tasks`** — generate a dependency-ordered task list from the plan
3. **`/speckit-implement`** — execute each task; every task has a test that must pass before it is marked complete
4. **Spec Drift Sync** — verify contracts, quickstart, and plan match the code before the PR is opened

The spec is not overhead. It is the contract between intent and code. When something in production doesn't match expectation, the first question is always: was it in the spec?

---

_Next: [Part 2 — The AI Spec Kit: Quality Gates You Can't Skip](./m365-part-2-ai-spec-kit-quality-gates.md)_
