import { getWeatherCode } from '../../src/webparts/darkFactoryWeather/mappers/WeatherCodeMapper';

describe('getWeatherCode', () => {
  describe('rain detection', () => {
    it.each([51, 53, 55, 61, 63, 65, 67])('code %i (drizzle/rain) returns isRain true', (code) => {
      expect(getWeatherCode(code).isRain).toBe(true);
    });

    it.each([80, 81, 82])('code %i (rain showers) returns isRain true', (code) => {
      expect(getWeatherCode(code).isRain).toBe(true);
    });

    it.each([95, 96, 99])('code %i (thunderstorm) returns isRain true', (code) => {
      expect(getWeatherCode(code).isRain).toBe(true);
    });
  });

  describe('non-rain codes', () => {
    it('code 0 (clear sky) returns isRain false', () => {
      expect(getWeatherCode(0).isRain).toBe(false);
    });

    it.each([1, 2, 3])('code %i (partly cloudy) returns isRain false', (code) => {
      expect(getWeatherCode(code).isRain).toBe(false);
    });

    it.each([45, 48])('code %i (fog) returns isRain false', (code) => {
      expect(getWeatherCode(code).isRain).toBe(false);
    });

    it.each([71, 73, 75, 77])('code %i (snow) returns isRain false', (code) => {
      expect(getWeatherCode(code).isRain).toBe(false);
    });
  });

  describe('labels', () => {
    it('code 0 returns a non-empty label', () => {
      expect(getWeatherCode(0).label.length).toBeGreaterThan(0);
    });

    it('code 95 returns a label containing "Thunderstorm"', () => {
      expect(getWeatherCode(95).label).toMatch(/thunderstorm/i);
    });
  });

  describe('unknown codes', () => {
    it('returns safe default label and isRain false for unknown code 999', () => {
      const result = getWeatherCode(999);
      expect(result.isRain).toBe(false);
      expect(result.label.length).toBeGreaterThan(0);
    });

    it('returns safe default for negative code', () => {
      const result = getWeatherCode(-1);
      expect(result.isRain).toBe(false);
    });
  });
});
