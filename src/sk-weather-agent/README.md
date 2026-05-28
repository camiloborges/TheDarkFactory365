# SK Weather Agent — Agents SDK + Semantic Kernel (.NET 8)

Demonstrates integrating Semantic Kernel (SK) orchestration with the Microsoft 365 Agents SDK. The agent:
- Maintains multi-turn chat history across conversation turns in state
- Uses SK's `AutoInvokeKernelFunctions` to automatically call a `WeatherPlugin` when the LLM decides to
- Streams an informative update before the final response
- Supports both Azure OpenAI and OpenAI as the backing model

## Prerequisites

- [.NET 8 SDK](https://dotnet.microsoft.com/download)
- Azure OpenAI resource (or OpenAI API key) — model `gpt-4o-mini` or newer recommended
- npm (for the test tool)

## Project structure

```
SkWeatherAgent.csproj       — project file, NuGet dependencies
Program.cs                  — web host, SK setup, AI service registration
WeatherAgent.cs             — AgentApplication with SK orchestration, chat history
Plugins/WeatherPlugin.cs    — KernelFunction stubs (replace with real API)
appsettings.json            — AIServices config (Azure OpenAI or OpenAI)
appsettings.Development.json
Properties/launchSettings.json
```

## Configure

Fill in `appsettings.json` (or use user secrets / environment variables):

**Azure OpenAI:**
```json
"AIServices": {
  "UseAzureOpenAI": true,
  "AzureOpenAI": {
    "DeploymentName": "gpt-4o-mini",
    "Endpoint": "https://your-resource.openai.azure.com/",
    "ApiKey": "your-key"
  }
}
```

**OpenAI:**
```json
"AIServices": {
  "UseAzureOpenAI": false,
  "OpenAI": {
    "ModelId": "gpt-4o-mini",
    "ApiKey": "sk-..."
  }
}
```

## Run locally

```bash
dotnet run
# → Now listening on: http://localhost:3978
```

## Test with M365 Agents Playground

```bash
npm install -g @microsoft/teams-app-test-tool
teamsapptester
```

Try: "What's the weather in Wellington?" or "Give me a 3-day forecast for Auckland."

## POST /api/assess-activity — Activity Weather Advisor endpoint

Added as part of Spec 005. A plain minimal API endpoint that bypasses Bot Framework routing.

**Requires `ActivityAdvisor:ApiKey` in `appsettings.json`** (or user secrets). In `Development` the key check is bypassed.

```bash
# Set the API key (local dev — use user-secrets, not appsettings)
dotnet user-secrets set "ActivityAdvisor:ApiKey" "dev-key-123"

# Test the endpoint
curl -X POST http://localhost:3978/api/assess-activity \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: dev-key-123" \
  -d '{"activity":"Trail Run","location":"Wellington","datetime":"2026-05-29T08:00:00"}'
```

Response:
```json
{ "risk": "Caution", "reason": "Wind speeds of 45 km/h are forecast at 08:00 — exposed ridgelines should be avoided." }
```

Error (unknown city):
```json
{ "error": "geocoding_failed", "message": "Could not resolve 'Atlantis' to coordinates." }
```

## Extending the weather plugin

`WeatherPlugin.cs` now uses real Open-Meteo HTTP calls — no stubs. The plugin calls the Geocoding API to resolve city names to lat/lon before calling the Forecast API. See `contracts/open-meteo-api.md` for the full URL patterns.

`ActivityAssessmentPlugin.cs` uses `WeatherPlugin`'s internal helpers (`ResolveLocationAsync`, `FetchForecastAsync`) to get conditions, selects the hourly slot nearest to the requested datetime, and calls GPT with a structured prompt to produce `{ risk, reason }`.

## Key patterns demonstrated

- **SK plugin registration** — `kernel.Plugins.AddFromObject(weatherPlugin, "Weather")`
- **AutoInvokeKernelFunctions** — LLM decides when to call tools, SK invokes them automatically
- **Multi-turn chat history** — persisted in conversation-scoped turn state across turns
- **Streaming response** — `QueueInformativeUpdateAsync` + `QueueTextChunk` + `EndStreamAsync`
- **Dependency injection** — kernel, plugin, and agent all registered in DI
