import { IWeatherReading } from '../models/IWeatherReading';
import { IForecastPeriod } from '../models/IForecastPeriod';

const CACHE_KEY = 'df_weather_cache_v1';
const STALE_THRESHOLD_MS = 30 * 60 * 1000;

export interface CachedWeatherData {
  reading: IWeatherReading;
  periods: IForecastPeriod[];
  forecastDays: IForecastPeriod[];
  timestamp: Date;
}

interface SerializedCache {
  reading: IWeatherReading;
  periods: IForecastPeriod[];
  forecastDays: IForecastPeriod[];
  timestampIso: string;
}

export class CacheService {
  public save(reading: IWeatherReading, periods: IForecastPeriod[], forecastDays: IForecastPeriod[]): void {
    try {
      const payload: SerializedCache = {
        reading,
        periods,
        forecastDays,
        timestampIso: new Date().toISOString()
      };
      localStorage.setItem(CACHE_KEY, JSON.stringify(payload));
    } catch {
      // QuotaExceededError or localStorage unavailable — fail silently
    }
  }

  public load(): CachedWeatherData | null {
    try {
      const raw = localStorage.getItem(CACHE_KEY);
      if (!raw) return null;
      const parsed: SerializedCache = JSON.parse(raw);
      return {
        reading: parsed.reading,
        periods: parsed.periods,
        forecastDays: parsed.forecastDays,
        timestamp: new Date(parsed.timestampIso)
      };
    } catch {
      return null;
    }
  }

  public isStale(timestamp: Date): boolean {
    return Date.now() - timestamp.getTime() >= STALE_THRESHOLD_MS;
  }
}
