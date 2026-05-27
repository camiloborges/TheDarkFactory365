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

## Extending the weather plugin

Replace the stub returns in `Plugins/WeatherPlugin.cs` with real HTTP calls. Open-Meteo is free and doesn't require an API key:

```csharp
// Free, no API key needed: https://open-meteo.com/
var url = $"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,weathercode";
var data = await _httpClient.GetFromJsonAsync<OpenMeteoResponse>(url, ct);
```

## Key patterns demonstrated

- **SK plugin registration** — `kernel.Plugins.AddFromObject(weatherPlugin, "Weather")`
- **AutoInvokeKernelFunctions** — LLM decides when to call tools, SK invokes them automatically
- **Multi-turn chat history** — persisted in conversation-scoped turn state across turns
- **Streaming response** — `QueueInformativeUpdateAsync` + `QueueTextChunk` + `EndStreamAsync`
- **Dependency injection** — kernel, plugin, and agent all registered in DI
