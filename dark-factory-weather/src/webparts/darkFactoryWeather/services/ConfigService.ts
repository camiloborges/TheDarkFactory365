import { IWeatherConfig } from '../models/IWeatherConfig';
import { IHomeLocation } from '../models/IHomeLocation';

export interface IHttpResponse {
  ok: boolean;
  json(): Promise<unknown>;
}

export interface IHttpClient {
  get(url: string, config?: unknown): Promise<IHttpResponse>;
}

export class ConfigError extends Error {
  public readonly missingKeys: string[];

  constructor(missingKeys: string[]) {
    super(`Missing required config keys: ${missingKeys.join(', ')}`);
    this.name = 'ConfigError';
    this.missingKeys = missingKeys;
  }
}

interface IListItemResponse {
  value: Array<{ Title: string; DFValue: string }>;
}

const REQUIRED_KEYS = [
  'Weather.Latitude',
  'Weather.Longitude',
  'Weather.Timezone',
  'Weather.LocationName',
  'Weather.ApiBaseUrl'
];

const OPTIONAL_DEFAULTS: Record<string, string> = {
  'Weather.City': '',
  'Weather.TemperatureUnit': 'celsius',
  'Weather.RefreshIntervalMinutes': '5'
};

const ALL_KEYS = [...REQUIRED_KEYS, ...Object.keys(OPTIONAL_DEFAULTS)];

export class ConfigService {
  private readonly spHttpClient: IHttpClient;
  private readonly siteUrl: string;
  private readonly listName: string;

  constructor(spHttpClient: IHttpClient, siteUrl: string, listName: string = 'DarkFactory-Settings') {
    this.spHttpClient = spHttpClient;
    this.siteUrl = siteUrl;
    this.listName = this.sanitizeListName(listName);
  }

  private sanitizeListName(name: string): string {
    return name.replace(/['"]/g, '').trim();
  }

  public async getConfig(): Promise<IWeatherConfig> {
    const configMap = await this.fetchAllKeys();

    // Apply optional defaults for missing optional keys
    for (const [key, defaultVal] of Object.entries(OPTIONAL_DEFAULTS)) {
      if (!configMap.has(key)) {
        configMap.set(key, defaultVal);
      }
    }

    // Validate required keys
    const missingKeys = REQUIRED_KEYS.filter(k => !configMap.has(k) || !configMap.get(k));
    if (missingKeys.length > 0) {
      throw new ConfigError(missingKeys);
    }

    // Validate coordinate formats
    const lat = parseFloat(configMap.get('Weather.Latitude')!);
    const lon = parseFloat(configMap.get('Weather.Longitude')!);
    if (isNaN(lat) || isNaN(lon)) {
      const invalidCoordKeys: string[] = [];
      if (isNaN(lat)) invalidCoordKeys.push('Weather.Latitude');
      if (isNaN(lon)) invalidCoordKeys.push('Weather.Longitude');
      throw new ConfigError(invalidCoordKeys);
    }

    // Validate refresh interval
    const rawInterval = configMap.get('Weather.RefreshIntervalMinutes')!;
    let refreshIntervalMinutes = parseInt(rawInterval, 10);
    if (isNaN(refreshIntervalMinutes) || refreshIntervalMinutes < 1) {
      refreshIntervalMinutes = 5;
    }

    const tempUnit = configMap.get('Weather.TemperatureUnit') as 'celsius' | 'fahrenheit';

    const location: IHomeLocation = {
      displayName: configMap.get('Weather.LocationName')!,
      city: configMap.get('Weather.City')!,
      latitude: lat,
      longitude: lon,
      timezone: configMap.get('Weather.Timezone')!
    };

    return {
      location,
      apiBaseUrl: configMap.get('Weather.ApiBaseUrl')!,
      temperatureUnit: (tempUnit === 'fahrenheit') ? 'fahrenheit' : 'celsius',
      refreshIntervalMinutes
    };
  }

  private async fetchAllKeys(): Promise<Map<string, string>> {
    const filterParts = ALL_KEYS.map(k => `Title eq '${encodeURIComponent(k)}'`).join(' or ');
    const url = `${this.siteUrl}/_api/web/lists/getbytitle('${encodeURIComponent(this.listName)}')/items?$filter=${filterParts}&$select=Title,DFValue&$top=${ALL_KEYS.length + 1}`;

    const response = await this.spHttpClient.get(url);
    if (!response.ok) {
      return new Map();
    }

    const data = await response.json() as IListItemResponse;
    const configMap = new Map<string, string>();

    if (data.value) {
      for (const item of data.value) {
        if (item.Title && item.DFValue) {
          configMap.set(item.Title, item.DFValue);
        }
      }
    }

    return configMap;
  }
}
