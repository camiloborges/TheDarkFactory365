# Research: Outdoor Activity Weather Advisor

**Feature**: 005-activity-weather-advisor
**Branch**: `005-activity-weather-advisor`
**Date**: 2026-05-28

---

## Decision 1 — SK Agent Hosting: Azure Container Apps

**Decision**: Host `src/sk-weather-agent/` on Azure Container Apps (ACA) Consumption plan.

**Rationale**: ACA Consumption is already the established pattern for containerised workloads in this project (Spec 003 resource group `rg-darkfactory`). It supports scale-to-zero (zero cost when idle), HTTPS ingress with a stable FQDN, and Managed Identity for downstream Azure resource access. The .NET 8 minimal API host runs as a standard container image with no additional scaffolding.

**Alternatives considered**:
- Azure App Service (Basic B1): Always-on, higher monthly cost (~$13/month) vs scale-to-zero. Rejected for a demo project.
- Azure Functions (Isolated Worker): Would require HTTP trigger wrapping around the SK kernel invocation. Adds indirection without benefit for a long-lived chat agent that maintains state via MemoryStorage. Rejected.
- Self-hosted / ngrok tunnel: Not repeatable, not suitable for Logic App caller. Rejected.

---

## Decision 2 — Open-Meteo Geocoding: Free Geocoding API

**Decision**: Resolve city-name strings to lat/lon using the Open-Meteo Geocoding API before calling the forecast endpoint.

**Rationale**: Open-Meteo's forecast endpoint requires `latitude` and `longitude` query parameters. The canvas app captures a plain city name string. The Open-Meteo Geocoding API (`https://geocoding-api.open-meteo.com/v1/search?name={name}&count=1&language=en&format=json`) is free, requires no API key, and returns structured results including `latitude`, `longitude`, `name`, `country`, and `timezone`. A single HTTP call before the forecast call is sufficient for this use case.

**Forecast URL pattern** (from README):
```
https://api.open-meteo.com/v1/forecast
  ?latitude={lat}
  &longitude={lon}
  &current=temperature_2m,weathercode,windspeed_10m,precipitation,relative_humidity_2m
  &hourly=temperature_2m,weathercode,precipitation_probability,windspeed_10m
  &forecast_days=3
  &timezone=auto
```

**WMO Weather Code reference** (used by `ActivityAssessmentPlugin` prompt):

| Code range | Meaning |
|---|---|
| 0 | Clear sky |
| 1–3 | Mainly clear / partly cloudy / overcast |
| 45, 48 | Fog |
| 51–67 | Drizzle / rain |
| 71–77 | Snow |
| 80–82 | Rain showers |
| 85–86 | Snow showers |
| 95 | Thunderstorm |
| 96, 99 | Thunderstorm with hail |

**Alternatives considered**:
- OpenWeatherMap: requires API key, free tier limited to 1000 calls/day. Rejected in favour of no-key solution.
- Bing Maps Geocoding: requires Azure Maps subscription. Overkill. Rejected.

---

## Decision 3 — ActivityAssessmentPlugin: Structured Output via JSON Mode

**Decision**: The `ActivityAssessmentPlugin` requests structured JSON output from GPT using `ResponseFormat = ChatResponseFormat.CreateJsonSchemaFormat(...)` (Semantic Kernel 1.x) rather than free-text parsing with regex.

**Rationale**: JSON schema-constrained output guarantees the `{ risk, reason }` shape is always returned and avoids brittle regex parsing. The `risk` field is constrained to the enum `["Safe", "Caution", "Unsafe"]`. If the model returns an unexpected shape, the plugin throws a `KernelException` which the endpoint maps to HTTP 502.

**Prompt design**:
```
You are an outdoor activity safety advisor. Given the weather conditions and a planned activity,
assess whether the activity is safe to proceed.

Activity: {activity}
Location: {location} (resolved)
Requested datetime: {datetime}
Current/forecast conditions at that time:
  Temperature: {temp_c}°C
  Weather: {weather_description} (WMO code {code})
  Wind: {wind_kmh} km/h
  Precipitation: {precip_mm} mm
  Humidity: {humidity}%

Respond with JSON only:
{
  "risk": "Safe" | "Caution" | "Unsafe",
  "reason": "<one or two sentences explaining the verdict, referencing the specific conditions>"
}

Rules:
- Safe: conditions are suitable for this activity with no significant hazard
- Caution: conditions are marginal — activity possible but with precautions noted in reason
- Unsafe: conditions pose a meaningful risk to health or safety for this activity
```

**Alternatives considered**:
- Free-text response + regex extraction: Fragile, fails on model variation. Rejected.
- Tool-call / function-calling loop: Overkill for a single-turn structured response. Rejected.

---

## Decision 4 — POST /api/assess-activity: Bypass Bot Framework Routing

**Decision**: The `POST /api/assess-activity` endpoint is registered as a plain `app.MapPost(...)` minimal API endpoint in `Program.cs`, alongside the existing `app.MapAgentApplicationEndpoints(...)`. It does not go through Bot Framework activity serialisation.

**Rationale**: The Bot Framework activity pipeline expects a specific `Activity` JSON shape with `type`, `from`, `recipient`, etc. Logic App / Power Automate call this endpoint with a simple `{ activity, location, datetime }` JSON body. Routing this through the agent's `OnActivity` handler would require constructing fake Bot Framework activities — adding complexity for no benefit. The minimal API endpoint is clean, self-documenting, and independently testable with `curl`.

**Authentication**: For the initial deployment, the ACA ingress is restricted to calls from within the same virtual network (Logic App Consumption uses public outbound IPs — an API key header `X-Api-Key` is validated via `appsettings.json`). Key is stored in Logic App parameters and PA environment variables — not hardcoded.

---

## Decision 5 — NuGet Version Pinning

**Decision**: Pin all packages in `SkWeatherAgent.csproj` to the latest stable versions at plan date (2026-05-28).

**Pinned versions**:
| Package | Version |
|---|---|
| `Microsoft.Agents.Hosting.AspNetCore` | `1.1.0` |
| `Microsoft.SemanticKernel` | `1.29.0` |
| `Microsoft.SemanticKernel.Connectors.AzureOpenAI` | `1.29.0` |
| `Microsoft.SemanticKernel.Connectors.OpenAI` | `1.29.0` |

**Rationale**: Floating `Version="*"` references cause non-deterministic CI builds — a NuGet restore on different dates may pull different patch versions, breaking the GHA pipeline (Spec 004 pattern). Explicit pinning makes the build reproducible and makes version bumps intentional and reviewable.

---

## Decision 6 — Logic App (Option A): Consumption Plan, Existing Resource Group

**Decision**: Deploy the Option A Logic App as an additional Consumption workflow in the existing `rg-darkfactory` resource group, named `la-darkfactory-activity-advisor`.

**Rationale**: Consumption plan has zero fixed cost, pay-per-execution (~$0.000025/action). The existing `rg-darkfactory` already has a Logic App (from Spec 002) — reusing the resource group avoids additional IAM, vnet, and monitoring setup. SharePoint trigger uses the existing SharePoint connection authorised in Spec 002 — the connection is shared and already authorised.

**Trigger**: SharePoint `When an item is created` on site `{SP_SITE_URL}`, list `DarkFactory-ActivityRequests`.

**Actions**:
1. Read `ActivityAdvisor.AgentEndpoint` from `DarkFactory-Settings` list (HTTP GET, or hardcoded parameter — see contract).
2. HTTP POST to `{AgentEndpoint}/api/assess-activity` with body `{ activity, location, datetime }` and header `X-Api-Key: @{parameters('ActivityAdvisorApiKey')}`.
3. Parse JSON response `{ risk, reason }`.
4. Update SP list item: `RiskLevel = risk`, `AssessmentReason = reason`, `Status = "Complete"`.
5. On HTTP action failure: Update SP list item `Status = "Error"`.

---

## Decision 7 — Power Automate (Option B): Premium HTTP Connector, UNTESTED

**Decision**: Implement Option B as a Power Automate cloud flow using the HTTP connector (Premium). Ships as checked-in YAML. Marked `[UNTESTED]` — requires PA Premium environment for end-to-end validation.

**Rationale**: Functionally identical to Option A but uses PA's HTTP connector instead of Logic Apps' built-in HTTP action. The value is demonstrating both orchestration engines side-by-side for portfolio purposes. The YAML is syntactically correct but cannot be validated without a live Premium environment.

**Flow structure**: Same trigger/action pattern as Option A, expressed as Power Automate YAML.

---

## Decision 8 — Teams Notification: Standard Power Automate Connectors Only

**Decision**: The Teams notification flow uses only standard Power Automate connectors: SharePoint (`When an item is modified`, filter on `Status eq 'Complete'`) and Teams (`Post a message in a chat or channel` or `Post message in a channel`).

**Rationale**: Standard connectors only — no Premium licence required for this path. Accessible on M365 Business Basic without additional cost.

**Adaptive card design**: Text message with emoji risk indicator (🟢/🟡/🔴) so verdict is scannable at a glance. Uses PA dynamic content for Activity, Location, RiskLevel, AssessmentReason, and a link to the SP list item.

---

## Decision 9 — Canvas App: Power Apps Standard SharePoint Connector

**Decision**: The Power Apps canvas app uses the standard SharePoint connector to read/write `DarkFactory-ActivityRequests`. No premium connectors are required.

**Screens**:
1. **Submit screen**: Form with Activity (dropdown: Trail Run, Cycling, Swimming, Hiking, Other), Location (text input), RequestedDateTime (date/time picker). Submit button → `Patch()` to SP list with Status = "Pending".
2. **Results panel** (below form): Gallery showing the current user's last 5 requests with their Status, RiskLevel, and AssessmentReason.

**Note**: The canvas app is documented as a YAML export (Power Apps YAML format). It cannot be compiled and run without a Power Apps environment.

---

## Resolved Unknowns Summary

| Unknown | Resolution |
|---|---|
| RISK-001: PA Premium available? | YES — Option B ships as working YAML (untested) |
| Agent hosting platform | Azure Container Apps (Consumption), `rg-darkfactory` |
| Open-Meteo geocoding | Free Geocoding API, no key required |
| ActivityAssessmentPlugin output format | JSON schema mode, `{ risk, reason }` |
| NuGet version pinning strategy | Pin to latest stable at plan date, listed above |
| `/api/assess-activity` authentication | X-Api-Key header (stored in LA params / PA env vars) |
| Canvas app connectivity | Standard SharePoint connector (no premium) |
