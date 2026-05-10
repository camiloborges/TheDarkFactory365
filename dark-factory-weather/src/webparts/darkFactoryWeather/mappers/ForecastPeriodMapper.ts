import { IForecastPeriod, PeriodName, DayName } from '../models/IForecastPeriod';
import { getWeatherCode } from './WeatherCodeMapper';

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

const PERIODS: Array<{ name: PeriodName; startHour: number; endHour: number }> = [
  { name: 'Morning',   startHour: 6,  endHour: 11 },
  { name: 'Afternoon', startHour: 12, endHour: 17 },
  { name: 'Evening',   startHour: 18, endHour: 20 },
  { name: 'Tonight',   startHour: 21, endHour: 23 }
];

const DAY_NAMES: DayName[] = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

function toLocalDateStr(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function mapTodayPeriods(hourly: OpenMeteoHourly, now: Date): IForecastPeriod[] {
  const todayStr = toLocalDateStr(now);
  const currentHour = now.getHours();

  const results: IForecastPeriod[] = [];

  for (const period of PERIODS) {
    // Skip periods that are entirely in the past
    if (period.endHour < currentHour) continue;

    const periodHours: number[] = [];
    for (let h = period.startHour; h <= period.endHour; h++) {
      const timeStr = `${todayStr}T${String(h).padStart(2, '0')}:00`;
      const idx = hourly.time.indexOf(timeStr);
      if (idx !== -1) periodHours.push(idx);
    }

    if (periodHours.length === 0) continue;

    const temps = periodHours.map(i => hourly.temperature_2m[i]);
    const codes = periodHours.map(i => hourly.weather_code[i]);
    const precip = periodHours.map(i => hourly.precipitation[i]);

    const maxCode = codes.reduce((a, b) => (a > b ? a : b), 0);
    const codeInfo = getWeatherCode(maxCode);

    results.push({
      name: period.name,
      isToday: true,
      tempMin: Math.min(...temps),
      tempMax: Math.max(...temps),
      weatherCode: maxCode,
      conditionLabel: codeInfo.label,
      isRain: codeInfo.isRain,
      precipitationMm: precip.reduce((a, b) => a + b, 0)
    });
  }

  return results;
}

export function mapForecastDays(daily: OpenMeteoDaily, now: Date): IForecastPeriod[] {
  const results: IForecastPeriod[] = [];

  // indices 1 and 2 are the two forecast days
  for (let i = 1; i <= 2; i++) {
    if (!daily.time[i]) break;

    const dayDate = new Date(daily.time[i] + 'T00:00:00');
    const dayOfWeek = dayDate.getDay();
    const diffDays = i; // relative to today
    const name: DayName = diffDays === 1 ? 'Tomorrow' : DAY_NAMES[dayOfWeek];

    const code = daily.weather_code[i] ?? 0;
    const codeInfo = getWeatherCode(code);

    results.push({
      name,
      isToday: false,
      tempMin: daily.temperature_2m_min[i] ?? 0,
      tempMax: daily.temperature_2m_max[i] ?? 0,
      weatherCode: code,
      conditionLabel: codeInfo.label,
      isRain: codeInfo.isRain,
      precipitationMm: 0
    });
  }

  return results;
}
