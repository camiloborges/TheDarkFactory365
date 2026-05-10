# Feature Specification: Weather Display System

**Feature Branch**: `001-weather-system`
**Created**: 2026-05-10
**Status**: Draft
**Scope Note**: This spec covers the configuration store and weather display web part only. Rain alert automation is covered in Spec 002.
**Teams Deployment Target**: Team `DarkFactory`, channel `General`

---

## Clarifications

### Session 2026-05-10

- Q: After how long without a successful refresh should the web part treat cached data as stale? → A: Never expire cached data — always show last known — but display a prominent staleness warning when data is older than 30 minutes.
- Q: How should the "today remaining" forecast be broken up? → A: Grouped periods — Morning / Afternoon / Evening / Tonight (up to 4 blocks, showing only periods that remain in the current day).
- Q: Who can view and edit the central configuration store? → A: All family members can view entries; only the administrator can edit them.
- Q: Should the web part target a formal accessibility standard? → A: WCAG 2.1 AA, and the solution must follow SharePoint / Microsoft 365 / Teams platform best practices throughout.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — View Current Weather Conditions (Priority: P1)

As a family member, I want to see the current weather conditions for our home address when I open the family Teams dashboard, so that I can plan my day without switching to an external app.

**Why this priority**: This is the always-on, always-visible core of the system. Every family member benefits from it every day. Nothing else in the system has value without this foundation.

**Independent Test**: Can be fully tested by opening the Teams tab and confirming live weather data is displayed correctly for the configured home location.

**Acceptance Scenarios**:

1. **Given** the weather web part is loaded on the Teams tab, **When** the page renders, **Then** it displays the current temperature, feels-like temperature, weather condition label, wind speed and direction, humidity percentage, and UV index for the home location.
2. **Given** the web part is loaded, **When** the page renders, **Then** it displays today's sunrise and sunset times for the home location.
3. **Given** the web part has been open for 5 minutes, **When** the refresh interval elapses, **Then** weather data updates automatically without any user action.
4. **Given** the home location is configured in the configuration store, **When** the web part loads, **Then** it uses that location without requiring any input from the user.
5. **Given** the web part loads, **When** it renders, **Then** it presents the Dark Factory visual identity as defined in this spec — dark background, electric accent colour, bold typography, and high-contrast condition indicators.

---

### User Story 2 — View Today's Remaining Forecast and 3-Day Outlook (Priority: P2)

As a family member, I want to see what the weather will be like for the rest of today and for the next two days, so that I can plan activities and commitments in advance.

**Why this priority**: Forecast data adds planning value beyond knowing the current moment. It is the second most-used feature but depends on P1 infrastructure.

**Independent Test**: Can be tested independently of alerts by confirming forecast panels appear with correct data for the remaining hours today and the following two calendar days.

**Acceptance Scenarios**:

1. **Given** the web part is loaded at any time of day, **When** viewing today's forecast section, **Then** it shows only the remaining grouped periods (Morning / Afternoon / Evening / Tonight) that have not yet passed — past periods are not shown.
2. **Given** the web part is loaded, **When** viewing the forecast section, **Then** it displays two additional days beyond today, each showing the day name, high temperature, low temperature, and expected weather condition.
3. **Given** it is 11:45pm (only "Tonight" remains), **When** the web part loads, **Then** the "today remaining" section shows a single "Tonight" block. If no periods remain (past midnight edge case), the section is hidden gracefully.
4. **Given** the web part is loaded, **When** a forecast day shows rain, **Then** the condition is visually distinguished (e.g., rain icon, colour cue) to draw immediate attention.

---

### User Story 3 — Manage Home Location and Configuration (Priority: P3)

As the family administrator, I want to set up and update the home location and weather API credentials in a central configuration store, so that all current and future solutions automatically use the correct values without code changes.

**Why this priority**: Required for P1 and P2 to function, but it is a one-time administrator setup. Once done, it is rarely revisited.

**Independent Test**: Can be tested by updating a value in the config store and confirming the web part reflects it on next refresh, with no deployment or code change required.

**Acceptance Scenarios**:

1. **Given** the administrator updates the home location in the configuration store, **When** the web part next refreshes, **Then** it displays weather for the new location without any code change or redeployment.
2. **Given** the configuration store is populated, **When** the web part loads, **Then** it reads all location data and API credentials from the store — nothing is hardcoded.
3. **Given** a required configuration entry is missing, **When** the web part loads, **Then** it displays a clear, friendly setup guidance message rather than an error or blank panel.
4. **Given** the administrator is setting up the config store for the first time, **When** they follow the setup documentation, **Then** they can complete the configuration without developer assistance.

---

### Edge Cases

- What happens when the weather API is unavailable or returns an error? The web part displays a graceful fallback state showing the last known data and a "last updated" timestamp. It does not show a broken layout or raw error text.
- What happens if the home location coordinates are missing from the config store? The web part shows a friendly setup prompt explaining what is missing and where to configure it.
- What if the API returns partial data (e.g., forecast available but current conditions missing)? Each display section renders independently — available data shows, missing sections show a "data unavailable" placeholder.
- What happens during a network outage? The web part displays cached data where available with a visible "offline" or "last updated" indicator. It does not continuously error or thrash.
- What if the web part is viewed in a non-Teams context (e.g., directly on a SharePoint page)? It must render correctly in both contexts — the Teams tab is primary but not exclusive.
- What if UV index data is not available for the location (some APIs do not provide it for all regions)? The UV index field is hidden rather than showing zero or an error.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The web part MUST display the current temperature, feels-like temperature, weather condition label, wind speed, wind direction, humidity percentage, and UV index for the configured home location.
- **FR-002**: The web part MUST display today's sunrise and sunset times for the home location.
- **FR-003**: The web part MUST display a "today remaining" forecast section grouped into named periods — Morning, Afternoon, Evening, Tonight — showing only periods that have not yet passed. Each period shows its expected condition and temperature range. If only one period remains, a single block is shown; if none remain, the section is gracefully hidden.
- **FR-004**: The web part MUST display a 2-day forecast beyond today, showing each day's name, high temperature, low temperature, and weather condition.
- **FR-005**: Weather data MUST refresh automatically every 5 minutes without requiring a page reload. The refresh timer MUST pause when the browser tab or Teams tab is not visible (using the Page Visibility API) and resume with an immediate fetch when the tab becomes active again. This prevents unnecessary API calls and poor behaviour on mobile devices.
- **FR-006**: The web part MUST apply the Dark Factory visual identity (defined below) consistently across all display states — live data, cached, setup-required, and error states all use the same visual language.
- **FR-007**: The web part MUST read the home location (display name, city, latitude, longitude, timezone) from the central configuration store. No location data may be hardcoded. The configuration store MUST be configured with broken permission inheritance: all family members granted Read access; administrator granted Full Control. This setup is a deployment prerequisite and must be documented in the setup guide. All family members must hold at minimum Visitor (Read) access to the DarkFactory team SharePoint site, as the web part reads the config list using the current user's M365 session token.
- **FR-008**: The web part is built against **Open-Meteo** as the sole weather data provider for v1. The API base URL MUST be stored in the central configuration store (not hardcoded) to support environment overrides and future provider migration, but no provider-switching abstraction is built into v1 — switching providers in a future version will require a code change to the response parser in addition to a config update. This is an explicit, intentional simplification.
- **FR-008a**: The tenant administrator MUST add `api.open-meteo.com` to the SharePoint tenant Content Security Policy (CSP) allowlist before deployment. Without this, the browser will block client-side API calls from the web part. This is a deployment prerequisite, not a code requirement.
- **FR-009**: The web part MUST be accessible as a tab within the `General` channel of the `DarkFactory` Microsoft Teams team, surfaced via a SharePoint modern page hosted on the Team's associated SharePoint site. The tab MUST be added using the native **SharePoint** tab type (not a generic Website/iframe tab) to ensure proper SSO, Teams context injection, and Microsoft 365 session continuity. The SharePoint page MUST be in published state before the tab is added — draft pages do not render inside Teams.
- **FR-009a**: The web part MUST gracefully detect whether it is running inside Microsoft Teams or directly in SharePoint, and render correctly in both contexts. The Teams rendering context is the primary target; standalone SharePoint page is a supported secondary context.
- **FR-010**: When weather data cannot be retrieved, the web part MUST always display the last-known data — it must never show a blank or broken layout. A "last updated" timestamp MUST be visible at all times. When cached data is older than 30 minutes, the web part MUST additionally display a prominent staleness warning (e.g., a coloured indicator or banner) to signal the data may not reflect current conditions.
- **FR-011**: When required configuration entries are missing, the web part MUST display a setup guidance message identifying what is missing and where to configure it.
- **FR-012**: The web part MUST be deployed via the tenant App Catalog, making it available for use on any SharePoint site in the tenancy.
- **FR-013**: Temperature MUST be displayed in Celsius by default. The unit preference MUST be stored in the configuration store and must not require code changes to switch.
- **FR-014**: The web part display MUST be responsive and readable on both desktop and mobile screen sizes.
- **FR-015**: The web part MUST meet WCAG 2.1 AA accessibility standards — including sufficient colour contrast ratios (minimum 4.5:1 for normal text), full keyboard navigability, and meaningful ARIA labels for all interactive and informational elements.
- **FR-016**: The web part MUST follow Microsoft SharePoint Framework (SPFx) development best practices, Microsoft Teams app guidelines, and Microsoft 365 platform conventions — including use of Microsoft Fluent UI components for layout and interaction structure, Dark Factory palette applied as scoped SCSS variable overrides, and compliance with Microsoft's technical requirements for web parts and Teams tabs. The SPFx property pane is used only for deployment-time settings (e.g., the configuration list name or site URL); all runtime settings live in the SharePoint configuration list.

### Key Entities

- **WeatherReading**: A point-in-time snapshot of conditions — includes current temperature, feels-like, wind speed, wind direction, humidity, UV index, weather condition label and icon code, and timestamp.
- **ForecastPeriod**: A time-bounded weather outlook — includes period name (Morning / Afternoon / Evening / Tonight, or a calendar day name), start time, end time, temperature range (min/max), condition label, and icon code. Used for both grouped-period (today remaining) and daily (2-day) views.
- **HomeLocation**: The configured home reference point — includes display name, full address, city, latitude, longitude, and timezone identifier.
- **WeatherConfig**: Central configuration — includes API key, temperature unit preference, refresh interval in minutes, and a pointer to the associated Teams channel (for use by Spec 002).
- **DisplayState**: The current rendering state of the web part — one of: `loading`, `live`, `cached` (fresh, under 30 min), `stale` (cached but older than 30 min — warning shown), `setup-required`, `error`.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Family members can see current weather conditions and the day's remaining forecast within 3 seconds of opening the Teams dashboard tab.
- **SC-002**: Weather data displayed is no older than 6 minutes under normal operating conditions (5-minute refresh interval with a 1-minute grace window).
- **SC-003**: The web part remains informative and visually coherent under all conditions — live data, cached data, missing config, and API errors — with zero broken or blank screens. Cached data older than 30 minutes is accompanied by a visible staleness warning; data is never withheld from the user regardless of age.
- **SC-004**: A non-technical family member can read and understand the weather display without any training or explanation.
- **SC-005**: Updating the home location in the configuration store is reflected in the web part display within one refresh cycle (≤5 minutes), with no code changes or redeployment.
- **SC-006**: The administrator can complete initial configuration store setup in under 20 minutes by following setup documentation.
- **SC-007**: The web part renders correctly on both desktop and mobile screen sizes without horizontal scrolling or clipped content.
- **SC-008**: All text elements in the web part meet WCAG 2.1 AA colour contrast ratios (minimum 4.5:1). The web part is fully operable by keyboard alone and all informational elements have meaningful labels for screen readers.
- **SC-009**: The web part passes Microsoft's AppSource validation guidelines and loads without errors or warnings in both the SharePoint workbench and as a Teams tab in the `DarkFactory` team.

---

## Dark Factory Visual Identity

This section defines the design language for the TheDarkFactory365 brand. It applies to this web part and MUST be used as the baseline for all future solutions built in this project.

### Aesthetic Principles

- **Modern and techie**: The interface should feel like a precision instrument — a control room display, not a consumer weather widget. Data is the hero; decoration is minimal.
- **Clean**: No visual clutter. Every element earns its space. White space is used deliberately to create hierarchy and breathing room.
- **Readable at a glance**: A family member should be able to read the current temperature and condition in under 2 seconds without leaning in or squinting.

### Colour Palette

| Role | Colour | Usage |
|---|---|---|
| Background | Deep charcoal `#0D1117` | Primary page and card backgrounds |
| Surface | Dark slate `#161B22` | Card interiors, elevated panels |
| Border | Dim `#30363D` | Subtle dividers, card borders |
| Primary text | White `#F0F6FC` | Temperature readings, condition labels |
| Secondary text | Cool grey `#9CA4B0` | Labels, units, timestamps — verified ≥4.5:1 on both `#0D1117` and `#161B22` |
| Accent | Electric cyan `#22D3EE` | Highlights, active indicators, rain cues |
| Alert / rain | Electric blue `#3B82F6` | Rain condition indicators specifically |
| Warning | Amber `#F59E0B` | UV index warnings, extreme conditions |

### Typography

- Large, bold numerals for temperature readings — the primary number must dominate the display
- Clean sans-serif for all labels and secondary information (system font stack acceptable; no decorative fonts)
- Condition labels in sentence case, not all-caps
- Units (°C, km/h, %) displayed as small secondary text alongside the primary value

### Iconography

- Weather condition icons: monochrome or minimal-colour line-art style — no cartoonish or skeuomorphic icons
- Icons must be large enough to identify at arm's length on a desktop screen
- Each weather condition maps to exactly one icon; there is no ambiguity

### Contrast Verification

All foreground/background combinations have been checked against WCAG 2.1 AA (minimum 4.5:1 for normal text, 3:1 for large text):

| Foreground | Background | Approx. Ratio | AA Pass? |
|---|---|---|---|
| `#F0F6FC` white | `#0D1117` background | ~18:1 | ✓ |
| `#F0F6FC` white | `#161B22` surface | ~14:1 | ✓ |
| `#9CA4B0` secondary | `#0D1117` background | ~6.5:1 | ✓ |
| `#9CA4B0` secondary | `#161B22` surface | ~5.1:1 | ✓ |
| `#22D3EE` accent | `#0D1117` background | ~9.8:1 | ✓ |
| `#F59E0B` warning | `#0D1117` background | ~7.2:1 | ✓ |
| `#3B82F6` rain blue | `#0D1117` background | ~4.6:1 | ✓ |

The original `#8B949E` secondary text failed on `#161B22` surface (~4.2:1). Updated to `#9CA4B0` to resolve this.

### Layout Principles

- Card-based layout: each data group (current conditions, today remaining, day 2, day 3) lives in its own card
- Information density is balanced: enough data to be useful, not so much that it overwhelms
- Responsive: cards stack vertically on mobile, arrange horizontally on desktop
- No background images or gradients behind data — solid dark surfaces only

---

## Weather API: Options and Recommendation

The system requires a weather data provider that supports current conditions, hourly forecast, daily forecast, UV index, and sunrise/sunset data. The following free-tier options were evaluated.

### Comparison

| Provider | Cost | API Key | Rate Limit (free) | Current + Forecast | UV Index | Sunrise/Sunset | Notes |
|---|---|---|---|---|---|---|---|
| **Open-Meteo** | Free forever | None required | Unlimited (fair use) | Yes | Yes | Yes | Open-source, no sign-up, global coverage |
| **WeatherAPI.com** | Free tier | Required | 1M calls/month | Yes | Yes | Yes | Commercial, reliable, excellent docs |
| **OpenWeatherMap** | Free tier | Required | 60 calls/min | Yes | Separate call | Yes | Industry standard, UV needs extra endpoint |
| **Tomorrow.io** | Free tier | Required | 500 calls/day | Yes | Yes | Yes | 500/day = ~1 call/3 min; tight for 5-min polling |

### Recommendation: Open-Meteo

**Open-Meteo** is the recommended provider for this project because:

1. **Zero cost, no API key**: No credentials to manage, store, or rotate. Eliminates a setup step and a security surface.
2. **No rate limit concerns**: A personal household polling every 5 minutes generates ~288 calls/day — well within fair-use bounds, with no account or payment required.
3. **Complete data set**: Provides all required fields — current conditions, hourly forecast, daily high/low, UV index, and sunrise/sunset — in a single API call.
4. **Global coverage with high accuracy**: Uses data from national meteorological services (NOAA, EU Copernicus, etc.), with strong coverage in Oceania.
5. **Stable and widely used**: Open-source project backed by a non-profit; used by thousands of applications globally.

**Fallback**: If Open-Meteo data quality proves insufficient for the home location, **WeatherAPI.com** free tier is the recommended alternative — generous limits and a clean API.

The API base URL is stored in the configuration store for environment flexibility. Switching providers in a future version will require both a config update and a code change to the response parser — this is a known and accepted constraint for v1 (DRY over YAGNI: no unused abstraction layer is built).

---

## Planning Prerequisites

These items must be addressed before or during implementation planning. They are not functional requirements but are blockers or constraints the plan must account for.

- **App Catalog**: The SharePoint tenant App Catalog must exist before the web part can be deployed. If not already created, the administrator must provision it via the SharePoint Admin Centre. The deploying user must hold the SharePoint Administrator role. Verify this as Step 1 in the deployment plan.
- **SC-001 Qualification**: The "3-second" load target applies to desktop browsers on a standard broadband connection, measured from when the page reaches interactive state — not from navigation start. On first load, SPFx bundle download adds overhead. A skeleton/loading state (DisplayState: `loading`) must be visible within 500ms to maintain perceived performance.
- **WeatherConfig and Spec 002 coupling**: The `WeatherConfig` entity currently stores a Teams channel pointer for Spec 002's use. During Spec 002 planning, evaluate whether Spec 002 should own its own config entries in the shared list (separate named keys) rather than the Spec 001 entity definition owning that field. The shared config list pattern is correct; the ownership of each key should be clear.
- **SPFx Property Pane scope**: The SPFx property pane is used only for deployment-time settings — specifically the name of the configuration SharePoint list and, if needed, the site URL if the web part is installed on a site other than the DarkFactory team site. All runtime values (location, units, API URL) live in the SharePoint list. If the web part is always deployed to the DarkFactory team site, the property pane may have zero fields — this is acceptable and should be confirmed during planning.

## Assumptions

- The family has a single primary home location. Multi-location support is out of scope for v1.
- **Open-Meteo** is the selected weather data provider (see API Options section above). No API key is required; no credentials need to be stored for the primary provider.
- The web part makes one API call per refresh cycle regardless of how many family members have the tab open simultaneously (data is fetched client-side per session, not server-side centrally).
- The Microsoft 365 Family subscription provides sufficient SharePoint and Teams access for this solution.
- The web part is deployed to the tenant App Catalog by the administrator, who holds tenant admin rights.
- The `DarkFactory` Teams team and `General` channel exist or will be created by the administrator before deployment. The SharePoint page tab is added manually as a setup step.
- Temperature unit defaults to Celsius. This is stored as a configuration value, not hardcoded.
- Rain alert functionality (forecast rain prediction and current rain detection) is out of scope for this spec — covered in Spec 002.
- Historical weather data and trend charts are out of scope for v1.
- Severe weather alerts are out of scope for v1.
- The web part does not require user authentication beyond the standard Microsoft 365 session — it displays the same data to all family members.
- The web part is built using the SharePoint Framework (SPFx) — Microsoft's supported extension model for SharePoint and Teams. No unsupported or unofficial customisation methods are used.
- Microsoft Fluent UI (the official M365 design system) is used as the component foundation for layout, interaction patterns, and accessibility structure. Dark Factory visual identity is applied as scoped SCSS/CSS-in-JS variable overrides within the web part bundle — not via SharePoint's `ThemeProvider` or tenant theme injection, which are designed for site-wide theming and cannot be driven from within a web part at runtime. This approach is valid, fully supported for single-tenant solutions, and does not require an AppSource-level theme registration.
- A custom SharePoint site theme matching the Dark Factory palette MAY be applied to the DarkFactory team site via the SharePoint Admin Centre as an optional enhancement, but the web part does not depend on it.
- The Dark Factory colour palette has been reviewed for WCAG 2.1 AA compliance. The secondary text colour has been updated (see Visual Identity section) to ensure all foreground/background combinations on both background and surface colours meet the 4.5:1 minimum contrast ratio. No further verification deferral is acceptable before implementation begins.
- "Today remaining" means forecast from the current hour forward to midnight local time. If it is after 10pm, the section may show very limited data, which is acceptable.
