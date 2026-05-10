export interface IWeatherReading {
  temperature: number;
  feelsLike: number;
  humidity: number;
  uvIndex: number | null;
  windSpeed: number;
  windDirection: number;
  weatherCode: number;
  conditionLabel: string;
  isRain: boolean;
  observedAt: Date;
  sunrise: string;
  sunset: string;
  uvIndexMax: number | null;
}
