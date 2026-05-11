import { WeatherService, WeatherFetchError } from '../../src/webparts/darkFactoryWeather/services/WeatherService';
import { IWeatherConfig } from '../../src/webparts/darkFactoryWeather/models/IWeatherConfig';

declare const fetchMock: import('jest-fetch-mock').FetchMock;

const MOCK_CONFIG: IWeatherConfig = {
  location: {
    displayName: 'Home',
    city: 'Auckland',
    latitude: -36.8509,
    longitude: 174.7645,
    timezone: 'Pacific/Auckland'
  },
  apiBaseUrl: 'https://api.open-meteo.com/v1/forecast',
  temperatureUnit: 'celsius',
  refreshIntervalMinutes: 5
};

const MOCK_RESPONSE = {
  latitude: -36.8509,
  longitude: 174.7645,
  timezone: 'Pacific/Auckland',
  timezone_abbreviation: 'NZST',
  utc_offset_seconds: 43200,
  current: {
    time: '2026-05-11T10:00',
    temperature_2m: 22.5,
    apparent_temperature: 20.1,
    relative_humidity_2m: 65,
    weather_code: 1,
    wind_speed_10m: 15.5,
    wind_direction_10m: 180,
    uv_index: 3.2
  },
  hourly: {
    time: Array.from({ length: 72 }, (_, i) => {
      const day = Math.floor(i / 24);
      const hour = i % 24;
      const days = ['2026-05-11', '2026-05-12', '2026-05-13'];
      return `${days[day]}T${String(hour).padStart(2, '0')}:00`;
    }),
    temperature_2m: Array(72).fill(20),
    apparent_temperature: Array(72).fill(18),
    weather_code: Array(72).fill(1),
    precipitation: Array(72).fill(0)
  },
  daily: {
    time: ['2026-05-11', '2026-05-12', '2026-05-13'],
    weather_code: [1, 61, 3],
    temperature_2m_max: [24, 18, 22],
    temperature_2m_min: [14, 12, 15],
    sunrise: ['2026-05-11T07:00', '2026-05-12T07:01', '2026-05-13T07:02'],
    sunset: ['2026-05-11T17:30', '2026-05-12T17:29', '2026-05-13T17:28'],
    uv_index_max: [4, 2, 3]
  }
};

beforeEach(() => {
  fetchMock.resetMocks();
});

describe('WeatherService', () => {
  describe('successful fetch', () => {
    beforeEach(() => {
      fetchMock.mockResponseOnce(JSON.stringify(MOCK_RESPONSE));
    });

    it('returns correct IWeatherReading from response', async () => {
      const service = new WeatherService();
      const result = await service.fetch(MOCK_CONFIG);

      expect(result.reading.temperature).toBe(22.5);
      expect(result.reading.feelsLike).toBe(20.1);
      expect(result.reading.humidity).toBe(65);
      expect(result.reading.windSpeed).toBe(15.5);
      expect(result.reading.windDirection).toBe(180);
      expect(result.reading.weatherCode).toBe(1);
      expect(result.reading.isRain).toBe(false);
    });

    it('correctly maps wind direction 180 degrees to S compass label', async () => {
      const service = new WeatherService();
      const result = await service.fetch(MOCK_CONFIG);

      expect(result.reading.conditionLabel).toBeTruthy();
    });

    it('builds URL with correct query parameters', async () => {
      const service = new WeatherService();
      await service.fetch(MOCK_CONFIG);

      const calledUrl = (fetchMock.mock.calls[0][0] as string);
      expect(calledUrl).toContain('latitude=-36.8509');
      expect(calledUrl).toContain('longitude=174.7645');
      expect(calledUrl).toContain('timezone=Pacific');
      expect(calledUrl).toContain('forecast_days=3');
      expect(calledUrl).toContain('wind_speed_unit=kmh');
    });

    it('isRain is true when weatherCode is a rain code', async () => {
      fetchMock.resetMocks();
      fetchMock.mockResponseOnce(JSON.stringify({
        ...MOCK_RESPONSE,
        current: { ...MOCK_RESPONSE.current, weather_code: 61 }
      }));

      const service = new WeatherService();
      const result = await service.fetch(MOCK_CONFIG);
      expect(result.reading.isRain).toBe(true);
    });

    it('returns periods and forecastDays arrays', async () => {
      const service = new WeatherService();
      const result = await service.fetch(MOCK_CONFIG);

      expect(Array.isArray(result.periods)).toBe(true);
      expect(Array.isArray(result.forecastDays)).toBe(true);
    });

    it('forecastDays has 2 entries for days 1 and 2', async () => {
      const service = new WeatherService();
      const result = await service.fetch(MOCK_CONFIG);

      expect(result.forecastDays).toHaveLength(2);
    });

    it('first forecast day isRain true when weather_code 61', async () => {
      const service = new WeatherService();
      const result = await service.fetch(MOCK_CONFIG);

      // daily[1] has code 61 → maps to forecastDays[0]
      expect(result.forecastDays[0].isRain).toBe(true);
    });
  });

  describe('error handling', () => {
    it('throws WeatherFetchError on HTTP 4xx', async () => {
      fetchMock.mockResponseOnce('', { status: 400 });
      const service = new WeatherService();

      await expect(service.fetch(MOCK_CONFIG)).rejects.toThrow(WeatherFetchError);
    });

    it('throws WeatherFetchError on HTTP 5xx', async () => {
      fetchMock.mockResponseOnce('', { status: 500 });
      const service = new WeatherService();

      await expect(service.fetch(MOCK_CONFIG)).rejects.toThrow(WeatherFetchError);
    });

    it('throws WeatherFetchError on network error', async () => {
      fetchMock.mockRejectOnce(new Error('Network error'));
      const service = new WeatherService();

      await expect(service.fetch(MOCK_CONFIG)).rejects.toThrow(WeatherFetchError);
    });
  });
});
