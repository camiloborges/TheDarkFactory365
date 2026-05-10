# The Weather Web Part Specification

_Part 1 of the M365 series_

**TL;DR**  
Before a single TypeScript file is created, we write the full specification for our Office 365 Weather Web Part using the GitHub Spec Kit. This post walks through every artifact: the research decisions, the surface matrix, the acceptance criteria in GIVEN/WHEN/THEN format, the architecture constraints, and the permission manifest. When we're done, a developer can pick this up and build the right thing without asking a single clarifying question.

---

## 1. The Specification Header

Every GitHub Spec Kit specification starts with a header issue that acts as the anchor for all requirements. In GitHub, this becomes a pinned issue in the repository tagged `spec:approved`.

---

**GitHub Issue: `[SPEC] Weather Web Part — Master Specification`**  
**Labels:** `spec:approved`, `surface:sharepoint`, `surface:teams`, `risk:high`  
**Milestone:** `v1.0 — Core Weather Display`

### Summary

A modern SharePoint Framework (SPFx) web part that displays current weather conditions and a short forecast for a configurable location. The solution must work as a SharePoint page web part and as a Teams personal tab. It must not store user data or expose tenant credentials to the client.

### Goals

- Display current weather (temperature, conditions, wind, humidity) for a user-configured location
- Display a 5-day forecast summary
- Support metric and imperial units
- Integrate with the M365 user's locale for date/time formatting
- Function on SharePoint modern pages and Microsoft Teams personal tabs

### Non-Goals (explicitly out of scope for v1.0)

- Viva Connections dashboard card
- Push notifications or weather alerts
- Multi-location comparison
- Historical weather data
- Mobile native app integration

---

## 2. The Surface Matrix

Before writing acceptance criteria, we enumerate every surface and its constraints. This is the M365-specific step that most specs skip.

| Surface | SPFx Host | Auth Context | Size Constraint | CSP Constraints |
|---|---|---|---|---|
| SharePoint modern page | `SharePointWebPart` | SharePoint user token | Configurable via zone | Tenant CSP policy |
| Teams personal tab | `TeamsTab` | Teams SSO (AAD) | 100% viewport height | Teams CSP — no inline scripts |
| Teams channel tab | Out of scope v1.0 | — | — | — |
| Viva Connections | Out of scope v1.0 | — | — | — |

**Decision record:** Teams channel tab excluded from v1.0 because the configuration UX (tab configuration dialog) requires a separate spec and adds significant surface area. Channel tab support deferred to v1.1.

---

## 3. Research: External Weather API Selection

**GitHub Discussion: `[RESEARCH] Weather API selection for SPFx web part`**  
**Status:** Decision recorded. No further discussion needed.

### Options Evaluated

| Option | Pros | Cons | Decision |
|---|---|---|---|
| OpenWeatherMap Free Tier | No auth required for basic call, generous free quota | HTTP only on free tier (need HTTPS upgrade), key must be stored somewhere | **Selected** |
| MSN Weather API (via Graph) | No external dependency, M365-native | Undocumented, unsupported, can be removed by Microsoft at any time | Rejected |
| Weather.gov API | Free, no key needed, US-only | US only — non-starter for global tenants | Rejected |
| Azure Maps Weather | First-party Azure service, SLA-backed | Paid, adds Azure billing dependency | Deferred to enterprise variant |

### Selected: OpenWeatherMap Current Weather + Forecast APIs

- **Current weather endpoint:** `https://api.openweathermap.org/data/2.5/weather`
- **5-day forecast endpoint:** `https://api.openweathermap.org/data/2.5/forecast`
- **API key storage:** SPFx tenant-wide property (not in web part properties — this prevents the key from appearing in page source)
- **CSP implication:** Tenant administrator must add `api.openweathermap.org` to the tenant CSP allowlist

**Rejection rationale for MSN Weather:** The MSN Weather endpoint is not part of any published Microsoft API contract. It has broken without notice twice in the past 18 months across the community. Building a production web part on an undocumented endpoint is an explicit violation of our Constitution: _REJECT: No dependency on undocumented or unsupported vendor APIs._

---

## 4. The Constitution (Non-Negotiable Constraints)

These are ACCEPT/REJECT gates. Any implementation decision that violates a REJECT is blocked — no exceptions without a spec amendment.

```
REJECT: API key stored in web part property pane (visible in page source)
REJECT: Direct user location access (Geolocation API) without explicit opt-in prompt
REJECT: Inline <script> tags or eval() — fails Teams CSP
REJECT: HTTP (non-TLS) API calls in any surface
REJECT: External API calls made on every render without caching
REJECT: Hardcoded locale — must use SPFx context.pageContext.cultureInfo

ACCEPT: API key stored in SharePoint tenant-wide property bag (server-side config)
ACCEPT: User-configurable location stored in web part property pane
ACCEPT: SPFx HttpClient for all external requests (respects tenant proxy/CSP)
ACCEPT: 30-minute client-side cache using sessionStorage keyed by location+units
ACCEPT: Graceful degradation — show error state when API is unreachable
```

---

## 5. Acceptance Criteria

Each requirement below maps to a GitHub Issue. The issue number is the canonical reference in pull requests.

---

### REQ-001: Display Current Weather

**GitHub Issue:** `[REQ-001] Display current weather for configured location`  
**Labels:** `spec:approved`, `surface:sharepoint`, `surface:teams`  
**Milestone:** `v1.0 — Core Weather Display`

**GIVEN** the web part is configured with a valid city name  
**AND** the OpenWeatherMap API is reachable  
**WHEN** the page containing the web part loads  
**THEN** the web part displays:
- City name and country code
- Current temperature in the configured unit (°C or °F)
- Weather condition description (e.g., "Partly cloudy")
- Weather condition icon (from OpenWeatherMap icon set)
- Feels-like temperature
- Humidity percentage
- Wind speed and direction

**GIVEN** the web part is configured with a valid city name  
**AND** the OpenWeatherMap API returns a 4xx or 5xx error  
**WHEN** the page loads  
**THEN** the web part displays a user-friendly error message  
**AND** does not display a broken layout or JavaScript error in the console

---

### REQ-002: Display 5-Day Forecast

**GitHub Issue:** `[REQ-002] Display 5-day forecast summary`  
**Labels:** `spec:approved`, `surface:sharepoint`, `surface:teams`  
**Milestone:** `v1.0 — Core Weather Display`

**GIVEN** the web part is configured with a valid city name  
**AND** the OpenWeatherMap API is reachable  
**WHEN** the page loads  
**THEN** the web part displays 5 daily forecast entries, each showing:
- Day label (formatted using the user's M365 locale)
- High and low temperature
- Dominant weather condition icon

**GIVEN** the forecast API returns data for a city with a different UTC offset than the user  
**WHEN** the page renders  
**THEN** forecast days are grouped by the **location's local date**, not the user's local date

---

### REQ-003: Location Configuration

**GitHub Issue:** `[REQ-003] Property pane location configuration`  
**Labels:** `spec:approved`, `surface:sharepoint`  
**Milestone:** `v1.0 — Core Weather Display`

**GIVEN** a page author opens the web part property pane  
**WHEN** they type a city name in the Location field  
**THEN** the web part preview updates with weather for that city within 3 seconds  
**AND** the location is saved to web part properties on pane close

**GIVEN** a page author enters a city name that does not resolve in the OpenWeatherMap geocoding API  
**WHEN** they close the property pane  
**THEN** the web part displays a "Location not found" message  
**AND** the invalid location is **not** saved to web part properties (previous valid location is preserved)

**GIVEN** a page author selects metric or imperial in the Units dropdown  
**WHEN** the page renders  
**THEN** all temperatures, wind speeds, and distances use the selected unit system  
**AND** the unit preference is saved per web part instance (not tenant-wide)

---

### REQ-004: API Key Configuration

**GitHub Issue:** `[REQ-004] Tenant-wide API key management`  
**Labels:** `spec:approved`, `surface:sharepoint`, `risk:high`  
**Milestone:** `v1.0 — Core Weather Display`

**GIVEN** a SharePoint administrator has stored the OpenWeatherMap API key in the tenant property bag key `WeatherWebPartApiKey`  
**WHEN** the web part initializes  
**THEN** it reads the API key from the tenant property bag via the SharePoint REST API  
**AND** the API key is never written to the DOM, window object, or client-accessible storage

**GIVEN** no API key is present in the tenant property bag  
**WHEN** the web part renders  
**THEN** it displays a clear message to the page author (not to end users): "API key not configured. Contact your SharePoint administrator."  
**AND** this message is only visible to users with page edit permissions

---

### REQ-005: Caching

**GitHub Issue:** `[REQ-005] 30-minute client-side weather cache`  
**Labels:** `spec:approved`, `surface:sharepoint`, `surface:teams`  
**Milestone:** `v1.0 — Core Weather Display`

**GIVEN** the web part has fetched weather data for a given location and units combination  
**WHEN** the same web part instance renders again within 30 minutes  
**THEN** it uses the cached response and does not call the OpenWeatherMap API  

**GIVEN** a user navigates away from the page and returns within 30 minutes  
**WHEN** the web part renders  
**THEN** it uses sessionStorage-cached data if the cache key matches `weather_{location}_{units}`

**GIVEN** 30 minutes have elapsed since the last API call  
**WHEN** the web part renders  
**THEN** it makes a fresh API call and updates the cache

---

### REQ-006: Teams Tab Compatibility

**GitHub Issue:** `[REQ-006] Teams personal tab surface support`  
**Labels:** `spec:approved`, `surface:teams`, `risk:high`  
**Milestone:** `v1.0 — Core Weather Display`

**GIVEN** the web part is added to a Teams personal app as a tab  
**WHEN** the tab loads  
**THEN** the web part renders without JavaScript errors  
**AND** authentication uses the Teams SSO flow (not cookie-based SharePoint auth)  
**AND** the layout fills the available tab viewport without horizontal scrollbars

**GIVEN** the Teams client is in dark theme  
**WHEN** the tab loads  
**THEN** the web part applies Fluent UI dark theme tokens  
**AND** text contrast ratios meet WCAG 2.1 AA requirements

---

## 6. Architecture Decisions

**GitHub Issue:** `[ARCH] Weather Web Part — Architecture Decision Record`  
**Labels:** `spec:approved`

| Decision | Choice | Rationale |
|---|---|---|
| SPFx version | 1.18.x (latest stable) | Required for Teams SSO and Viva extensibility in v1.1 |
| UI framework | React + Fluent UI v9 | Platform standard; Fluent v9 supports Teams dark/light theme context |
| State management | React hooks only (no Redux) | Single-component scope; Redux adds complexity without benefit |
| API communication | SPFx `HttpClient` | Respects tenant proxy config; required by Constitution |
| Styling | Fluent UI tokens only | No hardcoded colours; required for Teams theme support |
| Testing framework | Jest + React Testing Library | SPFx standard; avoids Workbench dependency in unit tests |
| Bundle size target | < 150 KB gzipped | Performance baseline for modern SharePoint pages |

---

## 7. Permission Manifest

This section maps directly to `package-solution.json` in the SPFx project.

```json
{
  "isDomainIsolated": false,
  "webApiPermissionRequests": [
    {
      "resource": "Microsoft Graph",
      "scope": "User.Read"
    }
  ],
  "externalDomains": [
    "api.openweathermap.org"
  ]
}
```

**`User.Read` justification:** Required to read `me/mailboxSettings` for the user's locale and timezone. Used solely for date/time formatting in the forecast. No user data is stored or transmitted.

**`api.openweathermap.org` justification:** External weather API. Domain must be in the SPFx external domains list to pass CSP in production tenants.

---

## 8. What Comes Next

With this specification complete and committed to GitHub, the development workflow is locked:

1. Every PR references the REQ issue it implements
2. The spec issue is updated if implementation reveals a gap (Cascade Principle)
3. Acceptance criteria drive integration test cases — no spec, no test, no merge
4. The Architecture Decision Record is updated if any technical decision changes

The spec is the source of truth. The code is evidence that the spec was met.

---

_Next: [Part 2 — Scaffolding the Project Without Breaking the Spec](./m365-part-2-scaffolding.md)_
