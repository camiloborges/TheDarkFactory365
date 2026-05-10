import { CacheService } from '../../src/webparts/darkFactoryWeather/services/CacheService';
import { IWeatherReading } from '../../src/webparts/darkFactoryWeather/models/IWeatherReading';
import { IForecastPeriod } from '../../src/webparts/darkFactoryWeather/models/IForecastPeriod';

const makeMockReading = (): IWeatherReading => ({
  temperature: 22,
  feelsLike: 20,
  humidity: 65,
  uvIndex: 3,
  windSpeed: 15,
  windDirection: 180,
  weatherCode: 1,
  conditionLabel: 'Mainly clear',
  isRain: false,
  observedAt: new Date('2026-05-11T10:00:00'),
  sunrise: '07:00',
  sunset: '17:30',
  uvIndexMax: 4
});

const makeMockPeriod = (): IForecastPeriod => ({
  name: 'Afternoon',
  isToday: true,
  tempMin: 18,
  tempMax: 24,
  weatherCode: 1,
  conditionLabel: 'Mainly clear',
  isRain: false,
  precipitationMm: 0
});

describe('CacheService', () => {
  let service: CacheService;

  beforeEach(() => {
    localStorage.clear();
    service = new CacheService();
  });

  describe('save and load round-trip', () => {
    it('load returns the saved data', () => {
      const reading = makeMockReading();
      const periods = [makeMockPeriod()];
      const forecastDays: IForecastPeriod[] = [];

      service.save(reading, periods, forecastDays);
      const loaded = service.load();

      expect(loaded).not.toBeNull();
      expect(loaded!.reading.temperature).toBe(22);
      expect(loaded!.reading.conditionLabel).toBe('Mainly clear');
      expect(loaded!.periods).toHaveLength(1);
      expect(loaded!.periods[0].name).toBe('Afternoon');
    });
  });

  describe('load when nothing saved', () => {
    it('returns null when cache is empty', () => {
      expect(service.load()).toBeNull();
    });
  });

  describe('isStale', () => {
    it('returns false for data less than 30 minutes old', () => {
      const recent = new Date(Date.now() - 20 * 60 * 1000);
      expect(service.isStale(recent)).toBe(false);
    });

    it('returns true for data exactly 30 minutes old', () => {
      const thirtyMinsAgo = new Date(Date.now() - 30 * 60 * 1000);
      expect(service.isStale(thirtyMinsAgo)).toBe(true);
    });

    it('returns true for data older than 30 minutes', () => {
      const old = new Date(Date.now() - 60 * 60 * 1000);
      expect(service.isStale(old)).toBe(true);
    });
  });

  describe('QuotaExceededError handling', () => {
    it('handles QuotaExceededError silently and load returns null', () => {
      const setItemSpy = jest.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
        throw new DOMException('QuotaExceededError', 'QuotaExceededError');
      });

      expect(() => service.save(makeMockReading(), [], [])).not.toThrow();

      setItemSpy.mockRestore();
      expect(service.load()).toBeNull();
    });
  });

  describe('when localStorage is unavailable', () => {
    it('load returns null when localStorage throws', () => {
      const getItemSpy = jest.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
        throw new Error('localStorage unavailable');
      });

      expect(service.load()).toBeNull();
      getItemSpy.mockRestore();
    });
  });
});
