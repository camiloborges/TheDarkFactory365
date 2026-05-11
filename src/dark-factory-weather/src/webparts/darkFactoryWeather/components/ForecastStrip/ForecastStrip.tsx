import * as React from 'react';
import { Stack, Text } from '@fluentui/react';
import { IForecastPeriod } from '../../models/IForecastPeriod';
import styles from '../DarkFactoryWeather.module.scss';

export interface IForecastStripProps {
  periods: IForecastPeriod[];
}

export const ForecastStrip: React.FC<IForecastStripProps> = ({ periods }) => {
  if (periods.length === 0) return null;

  return (
    <div data-testid="forecast-strip">
      <Text
        variant="small"
        styles={{ root: { color: 'var(--df-text-secondary)', marginBottom: 8, display: 'block' } }}
      >
        Today
      </Text>
      <Stack horizontal tokens={{ childrenGap: 8 }} wrap className={styles.forecastRow}>
        {periods.map(period => (
          <div
            key={period.name}
            role="group"
            aria-label={`${period.name}: ${period.conditionLabel}, ${Math.round(period.tempMin)} to ${Math.round(period.tempMax)} degrees`}
            className={styles.forecastCard}
            style={{
              background: 'var(--df-surface)',
              border: `1px solid var(--df-border)`,
              borderLeft: period.isRain ? `3px solid var(--df-rain)` : `1px solid var(--df-border)`,
              borderRadius: 6,
              padding: '10px 14px',
              minWidth: 100,
              flex: '1 1 auto'
            }}
          >
            <Stack tokens={{ childrenGap: 4 }}>
              <Text variant="small" styles={{ root: { color: 'var(--df-text-secondary)' } }}>
                {period.name}
              </Text>
              <Text variant="small" styles={{ root: { color: 'var(--df-text-primary)', fontWeight: 500 } }}>
                {period.conditionLabel}
              </Text>
              <Text variant="small" styles={{ root: { color: 'var(--df-text-secondary)' } }}>
                {Math.round(period.tempMin)}–{Math.round(period.tempMax)}°C
              </Text>
            </Stack>
          </div>
        ))}
      </Stack>
    </div>
  );
};
