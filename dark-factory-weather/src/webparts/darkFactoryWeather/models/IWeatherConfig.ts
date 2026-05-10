import { IHomeLocation } from './IHomeLocation';

export interface IWeatherConfig {
  location: IHomeLocation;
  apiBaseUrl: string;
  temperatureUnit: 'celsius' | 'fahrenheit';
  refreshIntervalMinutes: number;
}
