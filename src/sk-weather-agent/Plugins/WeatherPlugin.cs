// Plugins/WeatherPlugin.cs
// Stub plugin — replace with a real weather API call (e.g. OpenWeatherMap, Open-Meteo)
using System.ComponentModel;
using Microsoft.SemanticKernel;

namespace SkWeatherAgent.Plugins;

public class WeatherPlugin
{
    [KernelFunction]
    [Description("Get the current weather conditions for a city")]
    public string GetCurrentWeather(
        [Description("The city name, e.g. 'Wellington'")] string city)
    {
        // TODO: replace with real HTTP call, e.g.:
        //   var response = await _httpClient.GetFromJsonAsync<WeatherResponse>(
        //       $"https://api.openweathermap.org/data/2.5/weather?q={city}&appid={_apiKey}");
        return city.ToLower() switch
        {
            "wellington" => "Wellington: 12°C, partly cloudy, wind 25 km/h NW",
            "auckland"   => "Auckland: 18°C, sunny",
            "christchurch" => "Christchurch: 8°C, frost clearing",
            _            => $"{city}: weather data unavailable (stub — wire up a real API)"
        };
    }

    [KernelFunction]
    [Description("Get a 3-day weather forecast for a city")]
    public string GetForecast(
        [Description("The city name")] string city)
    {
        // TODO: replace with real forecast API call
        return $"{city} 3-day forecast (stub): " +
               $"Tomorrow 14°C cloudy · Day 2 16°C sunny · Day 3 12°C rain";
    }
}
