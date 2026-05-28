// Plugins/ActivityAssessmentPlugin.cs
// KernelFunction that assesses outdoor activity suitability given weather conditions.
// Calls Open-Meteo geocoding + forecast APIs, then uses GPT with a structured prompt
// to return { risk: Safe|Caution|Unsafe, reason }.
using System.ComponentModel;
using System.Text.Json;
using Microsoft.SemanticKernel;
using Microsoft.SemanticKernel.ChatCompletion;
using Microsoft.SemanticKernel.Connectors.OpenAI;

namespace SkWeatherAgent.Plugins;

public class ActivityAssessmentPlugin
{
    private readonly WeatherPlugin _weatherPlugin;
    private readonly IChatCompletionService _chatService;

    // Inject IChatCompletionService directly — avoids singleton Kernel dependency.
    // IChatCompletionService is stateless and safe to hold as a singleton.
    public ActivityAssessmentPlugin(WeatherPlugin weatherPlugin, IChatCompletionService chatService)
    {
        _weatherPlugin = weatherPlugin;
        _chatService   = chatService;
    }

    [KernelFunction("assess_activity")]
    [Description("Assess whether an outdoor activity is safe given the weather forecast at the location and time")]
    public async Task<ActivityAssessmentResult> AssessActivityAsync(
        [Description("Type of outdoor activity, e.g. 'Trail Run', 'Cycling'")] string activity,
        [Description("City name for the activity location, e.g. 'Wellington'")] string location,
        [Description("Planned activity date and time in ISO 8601 format, e.g. '2026-05-29T08:00:00'")] string datetime,
        CancellationToken cancellationToken = default)
    {
        // ── Step 1: Resolve location to coordinates ───────────────────────────
        var (lat, lon, resolvedName) = await _weatherPlugin.ResolveLocationAsync(location, cancellationToken);

        // ── Step 2: Fetch forecast ─────────────────────────────────────────────
        var forecast = await _weatherPlugin.FetchForecastAsync(lat, lon, cancellationToken);

        // ── Step 3: Select the hourly slot nearest to requested datetime ───────
        var requestedTime = DateTimeOffset.Parse(datetime);
        var hourly  = forecast.GetProperty("hourly");
        var times   = hourly.GetProperty("time").EnumerateArray().Select(t => t.GetString()!).ToArray();
        var temps   = hourly.GetProperty("temperature_2m").EnumerateArray().Select(v => v.GetDouble()).ToArray();
        var codes   = hourly.GetProperty("weathercode").EnumerateArray().Select(v => v.GetInt32()).ToArray();
        var precips = hourly.GetProperty("precipitation_probability").EnumerateArray().Select(v => v.GetInt32()).ToArray();
        var winds   = hourly.GetProperty("windspeed_10m").EnumerateArray().Select(v => v.GetDouble()).ToArray();

        var (slotIndex, _) = times
            .Select((t, i) => (i, Math.Abs((DateTimeOffset.Parse(t) - requestedTime).TotalMinutes)))
            .OrderBy(x => x.Item2)
            .First();

        var slotTemp    = temps[slotIndex];
        var slotCode    = codes[slotIndex];
        var slotPrecip  = precips[slotIndex];
        var slotWind    = winds[slotIndex];
        var slotDesc    = WeatherPlugin.DescribeWeatherCode(slotCode);

        // ── Step 4: Ask GPT to reason about suitability ────────────────────────
        var prompt = $"""
            You are an outdoor activity safety advisor. Assess whether the planned activity is safe.

            Activity: {activity}
            Location: {resolvedName}
            Requested time: {requestedTime:yyyy-MM-dd HH:mm}
            Forecast at that time:
              Temperature: {slotTemp}°C
              Conditions: {slotDesc} (WMO code {slotCode})
              Wind speed: {slotWind} km/h
              Precipitation probability: {slotPrecip}%

            Respond with JSON only — no markdown, no explanation outside the JSON:
            {{
              "risk": "Safe" | "Caution" | "Unsafe",
              "reason": "<one or two sentences explaining the verdict, referencing the specific conditions>"
            }}

            Rules:
            - Safe: conditions are suitable with no significant hazard
            - Caution: conditions are marginal — activity possible but with precautions noted in reason
            - Unsafe: conditions pose a meaningful risk to health or safety for this activity
            """;

        var history = new ChatHistory();
        history.AddUserMessage(prompt);

        var settings = new OpenAIPromptExecutionSettings
        {
            ResponseFormat = "json_object"
        };

        var response = await _chatService.GetChatMessageContentAsync(history, settings, cancellationToken: cancellationToken);
        var content = response.Content ?? throw new InvalidOperationException("assessment_failed: GPT returned empty content.");

        // ── Step 5: Parse structured response ─────────────────────────────────
        using var doc = JsonDocument.Parse(content);
        var root = doc.RootElement;

        if (!root.TryGetProperty("risk", out var riskProp) || !root.TryGetProperty("reason", out var reasonProp))
            throw new InvalidOperationException("assessment_failed: GPT response missing 'risk' or 'reason' fields.");

        var risk = riskProp.GetString()!;
        if (risk is not ("Safe" or "Caution" or "Unsafe"))
            throw new InvalidOperationException($"assessment_failed: GPT returned unexpected risk value '{risk}'.");

        return new ActivityAssessmentResult(risk, reasonProp.GetString()!);
    }
}

public record ActivityAssessmentResult(string Risk, string Reason);
