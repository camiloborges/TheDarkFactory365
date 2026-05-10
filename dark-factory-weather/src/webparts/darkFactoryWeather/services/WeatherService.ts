import { IWeatherConfig } from '../models/IWeatherConfig';
import { IWeatherReading } from '../models/IWeatherReading';
import { IForecastPeriod } from '../models/IForecastPeriod';
import { getWeatherCode } from '../mappers/WeatherCodeMapper';
import { mapTodayPeriods, mapForecastDays } from '../mappers/ForecastPeriodMapper';

export class WeatherFetchError extends Error {
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
    this.name = 'WeatherFetchError';
  }
}

interface OpenMeteoCurrent {
  time: string;
  temperature_2m: number;
  apparent_temperature: number;
  relative_humidity_2m: number;
  weather_code: number;
  wind_speed_10m: number;
  wind_direction_10m: number;
  uv_index: number;
}

interface OpenMeteoHourly {
  time: string[];
  temperature_2m: number[];
  apparent_temperature: number[];
  weather_code: number[];
  precipitation: number[];
}

interface OpenMeteoDaily {
  time: string[];
  weather_code: number[];
  temperature_2m_max: number[];
  temperature_2m_min: number[];
  sunrise: string[];
  sunset: string[];
  uv_index_max: number[];
}

interface OpenMeteoResponse {
  latitude: number;
  longitude: number;
  timezone: string;
  current: OpenMeteoCurrent;
  hourly: OpenMeteoHourly;
  daily: OpenMeteoDaily;
}

export class WeatherService {
  public async fetch(config: IWeatherConfig): Promise<{
    reading: IWeatherReading;
    periods: IForecastPeriod[];
    forecastDays: IForecastPeriod[];
  }> {
    const params = new URLSearchParams({
      latitude: String(config.location.latitude),
      longitude: String(config.location.longitude),
      timezone: config.location.timezone,
      current: 'temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m,uv_index',
      hourly: 'temperature_2m,apparent_temperature,weather_code,precipitation',
      daily: 'weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max',
      forecast_days: '3',
      wind_speed_unit: 'kmh'
    });

    if (config.temperatureUnit === 'fahrenheit') {
      params.set('temperature_unit', 'fahrenheit');
    }

    const url = `${config.apiBaseUrl}?${params.toString()}`;

    let response: Response;
    try {
      response = await fetch(url);
    } catch (err) {
      throw new WeatherFetchError('Network error fetching weather data', err);
    }

    if (!response.ok) {
      throw new WeatherFetchError(`Weather API returned HTTP ${response.status}`);
    }

    let data: OpenMeteoResponse;
    try {
      data = await response.json();
    } catch (err) {
      throw new WeatherFetchError('Failed to parse weather API response', err);
    }

    const { current, hourly, daily } = data;
    const codeInfo = getWeatherCode(current.weather_code);

    const reading: IWeatherReading = {
      temperature: current.temperature_2m,
      feelsLike: current.apparent_temperature,
      humidity: current.relative_humidity_2m,
      uvIndex: current.uv_index ?? null,
      windSpeed: current.wind_speed_10m,
      windDirection: current.wind_direction_10m,
      weatherCode: current.weather_code,
      conditionLabel: codeInfo.label,
      isRain: codeInfo.isRain,
      observedAt: new Date(current.time),
      sunrise: daily.sunrise[0] ? daily.sunrise[0].slice(-5) : '--:--',
      sunset: daily.sunset[0] ? daily.sunset[0].slice(-5) : '--:--',
      uvIndexMax: daily.uv_index_max[0] ?? null
    };

    const now = new Date();
    const periods = mapTodayPeriods(hourly, now);
    const forecastDaysResult = mapForecastDays(daily, now);

    return { reading, periods, forecastDays: forecastDaysResult };
  }
}
