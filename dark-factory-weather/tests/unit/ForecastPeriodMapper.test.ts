import { mapTodayPeriods, mapForecastDays } from '../../src/webparts/darkFactoryWeather/mappers/ForecastPeriodMapper';

function addDaysToDateStr(dateStr: string, days: number): string {
  const [y, m, d] = dateStr.split('-').map(Number);
  const date = new Date(y, m - 1, d + days);
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

function makeHourlyData(dateStr: string) {
  const times: string[] = [];
  const temps: number[] = [];
  const codes: number[] = [];
  const precip: number[] = [];

  for (let day = 0; day < 3; day++) {
    const dayStr = addDaysToDateStr(dateStr, day);

    for (let h = 0; h < 24; h++) {
      times.push(`${dayStr}T${String(h).padStart(2, '0')}:00`);
      temps.push(15 + h * 0.3);
      codes.push(h >= 12 && h <= 15 ? 61 : 1); // rain in afternoon only
      precip.push(h >= 12 && h <= 15 ? 0.5 : 0);
    }
  }

  return {
    time: times,
    temperature_2m: temps,
    apparent_temperature: temps.map(t => t - 2),
    weather_code: codes,
    precipitation: precip
  };
}

const TEST_DATE = '2026-05-11';

function makeLocalDate(dateStr: string, hour: number, minute: number = 0): Date {
  const [y, m, d] = dateStr.split('-').map(Number);
  return new Date(y, m - 1, d, hour, minute);
}

describe('mapTodayPeriods', () => {
  it('at 14:00 returns Afternoon, Evening, Tonight only', () => {
    const now = makeLocalDate(TEST_DATE, 14);
    const hourly = makeHourlyData(TEST_DATE);
    const periods = mapTodayPeriods(hourly, now);

    const names = periods.map(p => p.name);
    expect(names).not.toContain('Morning');
    expect(names).toContain('Afternoon');
    expect(names).toContain('Evening');
    expect(names).toContain('Tonight');
  });

  it('at 22:00 returns only Tonight', () => {
    const now = makeLocalDate(TEST_DATE, 22);
    const hourly = makeHourlyData(TEST_DATE);
    const periods = mapTodayPeriods(hourly, now);

    const names = periods.map(p => p.name);
    expect(names).toEqual(['Tonight']);
  });

  it('at 00:30 returns all 4 periods', () => {
    const now = makeLocalDate(TEST_DATE, 0, 30);
    const hourly = makeHourlyData(TEST_DATE);
    const periods = mapTodayPeriods(hourly, now);

    const names = periods.map(p => p.name);
    expect(names).toContain('Morning');
    expect(names).toContain('Afternoon');
    expect(names).toContain('Evening');
    expect(names).toContain('Tonight');
  });

  it('aggregates precipitation correctly', () => {
    const now = makeLocalDate(TEST_DATE, 0);
    const hourly = makeHourlyData(TEST_DATE);
    const periods = mapTodayPeriods(hourly, now);

    const afternoon = periods.find(p => p.name === 'Afternoon');
    expect(afternoon).toBeDefined();
    // Afternoon 12-17, codes 61 at 12,13,14,15 each 0.5mm = 2.0mm
    expect(afternoon!.precipitationMm).toBeCloseTo(2.0);
  });

  it('uses most severe WMO code as condition', () => {
    const now = makeLocalDate(TEST_DATE, 0);
    const hourly = makeHourlyData(TEST_DATE);
    const periods = mapTodayPeriods(hourly, now);

    const afternoon = periods.find(p => p.name === 'Afternoon');
    expect(afternoon).toBeDefined();
    expect(afternoon!.weatherCode).toBe(61);
    expect(afternoon!.isRain).toBe(true);
  });

  it('aggregates temperature min and max correctly', () => {
    const now = makeLocalDate(TEST_DATE, 0);
    const hourly = makeHourlyData(TEST_DATE);
    const periods = mapTodayPeriods(hourly, now);

    const morning = periods.find(p => p.name === 'Morning');
    expect(morning).toBeDefined();
    expect(morning!.tempMin).toBeLessThanOrEqual(morning!.tempMax);
  });

  it('marks all today periods with isToday true', () => {
    const now = makeLocalDate(TEST_DATE, 0);
    const hourly = makeHourlyData(TEST_DATE);
    const periods = mapTodayPeriods(hourly, now);

    periods.forEach(p => expect(p.isToday).toBe(true));
  });
});

describe('mapForecastDays', () => {
  const daily = {
    time: ['2026-05-11', '2026-05-12', '2026-05-13'],
    weather_code: [1, 61, 3],
    temperature_2m_max: [24, 18, 22],
    temperature_2m_min: [14, 12, 15],
    sunrise: ['2026-05-11T07:00', '2026-05-12T07:01', '2026-05-13T07:02'],
    sunset: ['2026-05-11T17:30', '2026-05-12T17:29', '2026-05-13T17:28'],
    uv_index_max: [4, 2, 3]
  };

  it('returns 2 forecast days', () => {
    const result = mapForecastDays(daily, makeLocalDate(TEST_DATE, 10));
    expect(result).toHaveLength(2);
  });

  it('first day is named Tomorrow', () => {
    const result = mapForecastDays(daily, makeLocalDate(TEST_DATE, 10));
    expect(result[0].name).toBe('Tomorrow');
  });

  it('second day has correct temperature range', () => {
    const result = mapForecastDays(daily, makeLocalDate(TEST_DATE, 10));
    expect(result[1].tempMax).toBe(22);
    expect(result[1].tempMin).toBe(15);
  });

  it('day with code 61 has isRain true', () => {
    const result = mapForecastDays(daily, makeLocalDate(TEST_DATE, 10));
    expect(result[0].isRain).toBe(true);
  });

  it('marks all forecast days with isToday false', () => {
    const result = mapForecastDays(daily, makeLocalDate(TEST_DATE, 10));
    result.forEach(d => expect(d.isToday).toBe(false));
  });
});
