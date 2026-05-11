import * as React from 'react';
import { Stack, Text } from '@fluentui/react';
import { IForecastPeriod } from '../../models/IForecastPeriod';
import styles from '../DarkFactoryWeather.module.scss';

export interface IForecastDaysProps {
  days: IForecastPeriod[];
}

export const ForecastDays: React.FC<IForecastDaysProps> = ({ days }) => {
  if (days.length === 0) return null;

  return (
    <div data-testid="forecast-days">
      <Text
        variant="small"
        styles={{ root: { color: 'var(--df-text-secondary)', marginBottom: 8, display: 'block' } }}
      >
        Forecast
      </Text>
      <Stack horizontal tokens={{ childrenGap: 8 }} wrap className={styles.forecastRow}>
        {days.map(day => (
          <div
            key={day.name}
            role="group"
            aria-label={`${day.name}: ${day.conditionLabel}, ${Math.round(day.tempMin)} to ${Math.round(day.tempMax)} degrees`}
            className={styles.forecastCard}
            style={{
              background: 'var(--df-surface)',
              border: `1px solid var(--df-border)`,
              borderLeft: day.isRain ? `3px solid var(--df-rain)` : `1px solid var(--df-border)`,
              borderRadius: 6,
              padding: '10px 14px',
              minWidth: 120,
              flex: '1 1 auto'
            }}
          >
            <Stack tokens={{ childrenGap: 4 }}>
              <Text variant="small" styles={{ root: { color: 'var(--df-text-primary)', fontWeight: 600 } }}>
                {day.name}
              </Text>
              <Text variant="small" styles={{ root: { color: 'var(--df-text-primary)' } }}>
                {day.conditionLabel}
              </Text>
              <Text variant="small" styles={{ root: { color: 'var(--df-text-secondary)' } }}>
                {Math.round(day.tempMin)}–{Math.round(day.tempMax)}°C
              </Text>
            </Stack>
          </div>
        ))}
      </Stack>
    </div>
  );
};
