import { ConfigService, ConfigError } from '../../src/webparts/darkFactoryWeather/services/ConfigService';

function makeSpHttpClient(responseMap: Record<string, string | null>) {
  return {
    get: jest.fn().mockImplementation(() => {
      // Return all matching items in one response (single REST call pattern)
      const items = Object.entries(responseMap)
        .filter(([, v]) => v !== null)
        .map(([k, v]) => ({ Title: k, DFValue: v as string }));

      return Promise.resolve({
        ok: true,
        json: () => Promise.resolve({ value: items })
      });
    })
  };
}

const BASE_CONFIG: Record<string, string> = {
  'Weather.Latitude': '-36.8509',
  'Weather.Longitude': '174.7645',
  'Weather.Timezone': 'Pacific/Auckland',
  'Weather.LocationName': 'Home',
  'Weather.ApiBaseUrl': 'https://api.open-meteo.com/v1/forecast',
  'Weather.City': 'Auckland',
  'Weather.TemperatureUnit': 'celsius',
  'Weather.RefreshIntervalMinutes': '5'
};

describe('ConfigService', () => {
  describe('when all 8 keys are present', () => {
    it('assembles correct IWeatherConfig with parsed floats and integers', async () => {
      const client = makeSpHttpClient(BASE_CONFIG);
      const service = new ConfigService(client as any, 'https://site.sharepoint.com/sites/Test');
      const config = await service.getConfig();

      expect(config.location.latitude).toBe(-36.8509);
      expect(config.location.longitude).toBe(174.7645);
      expect(config.location.timezone).toBe('Pacific/Auckland');
      expect(config.location.displayName).toBe('Home');
      expect(config.location.city).toBe('Auckland');
      expect(config.apiBaseUrl).toBe('https://api.open-meteo.com/v1/forecast');
      expect(config.temperatureUnit).toBe('celsius');
      expect(config.refreshIntervalMinutes).toBe(5);
    });

    it('uses a single REST call for all keys', async () => {
      const client = makeSpHttpClient(BASE_CONFIG);
      const service = new ConfigService(client as any, 'https://site.sharepoint.com/sites/Test');
      await service.getConfig();

      expect(client.get).toHaveBeenCalledTimes(1);
    });
  });

  describe('when a required key is missing', () => {
    it('throws ConfigError listing the missing key', async () => {
      const { 'Weather.Latitude': _removed, ...rest } = BASE_CONFIG;
      const client = makeSpHttpClient(rest);
      const service = new ConfigService(client as any, 'https://site.sharepoint.com/sites/Test');

      await expect(service.getConfig()).rejects.toThrow(ConfigError);
      await expect(service.getConfig()).rejects.toMatchObject({
        missingKeys: expect.arrayContaining(['Weather.Latitude'])
      });
    });

    it('throws ConfigError when multiple required keys are missing', async () => {
      const { 'Weather.Latitude': _lat, 'Weather.Longitude': _lon, ...rest } = BASE_CONFIG;
      const client = makeSpHttpClient(rest);
      const service = new ConfigService(client as any, 'https://site.sharepoint.com/sites/Test');

      await expect(service.getConfig()).rejects.toThrow(ConfigError);
    });
  });

  describe('when Weather.Latitude is non-numeric', () => {
    it('throws ConfigError', async () => {
      const client = makeSpHttpClient({ ...BASE_CONFIG, 'Weather.Latitude': 'not-a-number' });
      const service = new ConfigService(client as any, 'https://site.sharepoint.com/sites/Test');

      await expect(service.getConfig()).rejects.toThrow(ConfigError);
      await expect(service.getConfig()).rejects.toMatchObject({
        missingKeys: expect.arrayContaining(['Weather.Latitude'])
      });
    });
  });

  describe('when optional keys are absent', () => {
    it('uses default celsius for TemperatureUnit', async () => {
      const { 'Weather.TemperatureUnit': _removed, ...rest } = BASE_CONFIG;
      const client = makeSpHttpClient(rest);
      const service = new ConfigService(client as any, 'https://site.sharepoint.com/sites/Test');
      const config = await service.getConfig();

      expect(config.temperatureUnit).toBe('celsius');
    });

    it('uses default 5 for RefreshIntervalMinutes', async () => {
      const { 'Weather.RefreshIntervalMinutes': _removed, ...rest } = BASE_CONFIG;
      const client = makeSpHttpClient(rest);
      const service = new ConfigService(client as any, 'https://site.sharepoint.com/sites/Test');
      const config = await service.getConfig();

      expect(config.refreshIntervalMinutes).toBe(5);
    });

    it('uses empty string for City', async () => {
      const { 'Weather.City': _removed, ...rest } = BASE_CONFIG;
      const client = makeSpHttpClient(rest);
      const service = new ConfigService(client as any, 'https://site.sharepoint.com/sites/Test');
      const config = await service.getConfig();

      expect(config.location.city).toBe('');
    });
  });

  describe('when RefreshIntervalMinutes is invalid', () => {
    it('falls back to default of 5 when non-numeric', async () => {
      const client = makeSpHttpClient({ ...BASE_CONFIG, 'Weather.RefreshIntervalMinutes': 'abc' });
      const service = new ConfigService(client as any, 'https://site.sharepoint.com/sites/Test');
      const config = await service.getConfig();

      expect(config.refreshIntervalMinutes).toBe(5);
    });

    it('falls back to default of 5 when zero', async () => {
      const client = makeSpHttpClient({ ...BASE_CONFIG, 'Weather.RefreshIntervalMinutes': '0' });
      const service = new ConfigService(client as any, 'https://site.sharepoint.com/sites/Test');
      const config = await service.getConfig();

      expect(config.refreshIntervalMinutes).toBe(5);
    });
  });

  describe('when temperatureUnit is fahrenheit', () => {
    it('returns fahrenheit', async () => {
      const client = makeSpHttpClient({ ...BASE_CONFIG, 'Weather.TemperatureUnit': 'fahrenheit' });
      const service = new ConfigService(client as any, 'https://site.sharepoint.com/sites/Test');
      const config = await service.getConfig();

      expect(config.temperatureUnit).toBe('fahrenheit');
    });
  });

  describe('list name sanitization', () => {
    it('strips single quotes from list name to prevent OData injection', async () => {
      const client = makeSpHttpClient(BASE_CONFIG);
      const service = new ConfigService(client as any, 'https://site.sharepoint.com/sites/Test', "DarkFactory-Settings'--");
      await service.getConfig().catch(() => { /* ignore config errors */ });

      const calledUrl = (client.get.mock.calls[0][0] as string);
      expect(calledUrl).not.toContain("'--");
    });
  });
});
