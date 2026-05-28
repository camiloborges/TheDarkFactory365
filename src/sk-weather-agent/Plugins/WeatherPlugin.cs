// Plugins/WeatherPlugin.cs
// Wired to Open-Meteo free APIs — no API key required.
// Uses the Geocoding API to resolve city names to coordinates,
// then the Forecast API for current conditions and 3-day forecasts.
using System.ComponentModel;
using System.Text.Json;
using Microsoft.SemanticKernel;

namespace SkWeatherAgent.Plugins;

public class WeatherPlugin
{
    private readonly HttpClient _http;

    public WeatherPlugin(IHttpClientFactory httpClientFactory)
    {
        _http = httpClientFactory.CreateClient();
    }

    // ── Public KernelFunctions ────────────────────────────────────────────────

    [KernelFunction]
    [Description("Get the current weather conditions for a city")]
    public async Task<string> GetCurrentWeather(
        [Description("The city name, e.g. 'Wellington'")] string city,
        CancellationToken cancellationToken = default)
    {
        var (lat, lon, resolvedName) = await ResolveLocationAsync(city, cancellationToken);
        var forecast = await FetchForecastAsync(lat, lon, cancellationToken);

        var temp     = forecast.GetProperty("current").GetProperty("temperature_2m").GetDouble();
        var code     = forecast.GetProperty("current").GetProperty("weathercode").GetInt32();
        var wind     = forecast.GetProperty("current").GetProperty("windspeed_10m").GetDouble();
        var precip   = forecast.GetProperty("current").GetProperty("precipitation").GetDouble();
        var humidity = forecast.GetProperty("current").GetProperty("relative_humidity_2m").GetInt32();

        return $"{resolvedName}: {temp}°C, {DescribeWeatherCode(code)}, " +
               $"wind {wind} km/h, precipitation {precip} mm, humidity {humidity}%";
    }

    [KernelFunction]
    [Description("Get a 3-day weather forecast for a city")]
    public async Task<string> GetForecast(
        [Description("The city name")] string city,
        CancellationToken cancellationToken = default)
    {
        var (lat, lon, resolvedName) = await ResolveLocationAsync(city, cancellationToken);
        var forecast = await FetchForecastAsync(lat, lon, cancellationToken);

        var hourly = forecast.GetProperty("hourly");
        var times  = hourly.GetProperty("time").EnumerateArray().Select(t => t.GetString()!).ToArray();
        var temps  = hourly.GetProperty("temperature_2m").EnumerateArray().Select(t => t.GetDouble()).ToArray();
        var codes  = hourly.GetProperty("weathercode").EnumerateArray().Select(c => c.GetInt32()).ToArray();
        var winds  = hourly.GetProperty("windspeed_10m").EnumerateArray().Select(w => w.GetDouble()).ToArray();

        // Summarise each of the next 3 noon slots (index where time ends in "T12:00")
        var noonSlots = times
            .Select((t, i) => (t, i))
            .Where(x => x.t.EndsWith("T12:00"))
            .Take(3)
            .ToArray();

        if (noonSlots.Length == 0)
            return $"{resolvedName} 3-day forecast: no noon forecast slots available in response.";

        var summary = string.Join(" · ", noonSlots.Select(slot =>
        {
            var date = slot.t[..10];
            return $"{date}: {temps[slot.i]:F0}°C {DescribeWeatherCode(codes[slot.i])}, wind {winds[slot.i]:F0} km/h";
        }));

        return $"{resolvedName} 3-day forecast: {summary}";
    }

    // ── Internal helpers (also used by ActivityAssessmentPlugin) ─────────────

    internal async Task<(double Lat, double Lon, string Name)> ResolveLocationAsync(
        string city, CancellationToken cancellationToken)
    {
        var url = $"https://geocoding-api.open-meteo.com/v1/search?name={Uri.EscapeDataString(city)}&count=1&language=en&format=json";
        var json = await _http.GetStringAsync(url, cancellationToken);
        using var doc = JsonDocument.Parse(json);

        if (!doc.RootElement.TryGetProperty("results", out var results) || results.GetArrayLength() == 0)
            throw new InvalidOperationException($"geocoding_failed: Could not resolve '{city}' to coordinates.");

        var first = results[0];
        return (
            first.GetProperty("latitude").GetDouble(),
            first.GetProperty("longitude").GetDouble(),
            first.GetProperty("name").GetString()!
        );
    }

    internal async Task<JsonElement> FetchForecastAsync(
        double lat, double lon, CancellationToken cancellationToken)
    {
        var url = $"https://api.open-meteo.com/v1/forecast" +
                  $"?latitude={lat}&longitude={lon}" +
                  $"&current=temperature_2m,weathercode,windspeed_10m,precipitation,relative_humidity_2m" +
                  $"&hourly=temperature_2m,weathercode,precipitation_probability,windspeed_10m" +
                  $"&forecast_days=3&timezone=auto";

        var json = await _http.GetStringAsync(url, cancellationToken);
        return JsonDocument.Parse(json).RootElement.Clone();
    }

    internal static string DescribeWeatherCode(int code) => code switch
    {
        0              => "Clear sky",
        1              => "Mainly clear",
        2              => "Partly cloudy",
        3              => "Overcast",
        45 or 48       => "Fog",
        >= 51 and <= 57 => "Drizzle",
        >= 61 and <= 67 => "Rain",
        >= 71 and <= 77 => "Snow",
        >= 80 and <= 82 => "Rain showers",
        85 or 86       => "Snow showers",
        95             => "Thunderstorm",
        96 or 99       => "Thunderstorm with hail",
        _              => $"Unknown conditions (WMO {code})"
    };
}
