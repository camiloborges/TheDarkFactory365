export type PeriodName = 'Morning' | 'Afternoon' | 'Evening' | 'Tonight';
export type DayName = 'Tomorrow' | 'Monday' | 'Tuesday' | 'Wednesday' | 'Thursday' | 'Friday' | 'Saturday' | 'Sunday';

export interface IForecastPeriod {
  name: PeriodName | DayName;
  isToday: boolean;
  tempMin: number;
  tempMax: number;
  weatherCode: number;
  conditionLabel: string;
  isRain: boolean;
  precipitationMm: number;
}
