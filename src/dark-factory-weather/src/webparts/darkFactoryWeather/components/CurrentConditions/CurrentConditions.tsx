import * as React from 'react';
import { Stack, Text } from '@fluentui/react';
import { IWeatherReading } from '../../models/IWeatherReading';

export interface ICurrentConditionsProps {
  reading: IWeatherReading;
}

function degreesToCompass(degrees: number): string {
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return dirs[Math.round(degrees / 45) % 8];
}

function formatTime(timeStr: string): string {
  if (!timeStr || timeStr === '--:--') return timeStr;
  // timeStr may be "07:00" or "2026-05-11T07:00"
  return timeStr.length > 5 ? timeStr.slice(-5) : timeStr;
}

export const CurrentConditions: React.FC<ICurrentConditionsProps> = ({ reading }) => {
  const compassDir = degreesToCompass(reading.windDirection);
  const conditionColor = reading.isRain ? 'var(--df-rain)' : 'var(--df-accent)';
  const tempUnit = '°C';

  return (
    <div
      style={{ background: 'var(--df-surface)', border: '1px solid var(--df-border)', borderRadius: 6, padding: 16 }}
      data-testid="current-conditions"
    >
      <Stack tokens={{ childrenGap: 12 }}>
        {/* Temperature */}
        <Stack horizontal tokens={{ childrenGap: 16 }} verticalAlign="baseline">
          <Text
            variant="superLarge"
            aria-label={`${reading.temperature} degrees Celsius`}
            styles={{ root: { color: 'var(--df-text-primary)', fontWeight: 700, lineHeight: 1 } }}
          >
            {Math.round(reading.temperature)}{tempUnit}
          </Text>
          <Text
            styles={{ root: { color: 'var(--df-text-secondary)' } }}
            aria-label={`Feels like ${reading.feelsLike} degrees Celsius`}
          >
            Feels like {Math.round(reading.feelsLike)}{tempUnit}
          </Text>
        </Stack>

        {/* Condition */}
        <Text
          variant="medium"
          styles={{ root: { color: conditionColor, fontWeight: 500 } }}
          aria-label={`Condition: ${reading.conditionLabel}`}
        >
          {reading.conditionLabel}
        </Text>

        {/* Wind and Humidity */}
        <Stack horizontal tokens={{ childrenGap: 24 }} wrap>
          <Text
            styles={{ root: { color: 'var(--df-text-secondary)' } }}
            aria-label={`Wind: ${reading.windSpeed} kilometres per hour, ${compassDir}`}
          >
            Wind {Math.round(reading.windSpeed)} km/h {compassDir}
          </Text>
          <Text
            styles={{ root: { color: 'var(--df-text-secondary)' } }}
            aria-label={`Humidity: ${reading.humidity} percent`}
          >
            Humidity {reading.humidity}%
          </Text>
          {reading.uvIndex !== null && (
            <Text
              styles={{ root: { color: 'var(--df-text-secondary)' } }}
              aria-label={`UV index: ${reading.uvIndex}`}
            >
              UV {reading.uvIndex}
            </Text>
          )}
        </Stack>

        {/* Sunrise and Sunset */}
        <Stack horizontal tokens={{ childrenGap: 24 }}>
          <Text
            styles={{ root: { color: 'var(--df-text-secondary)' } }}
            aria-label={`Sunrise at ${formatTime(reading.sunrise)}`}
          >
            <span aria-hidden="true">↑ </span>{formatTime(reading.sunrise)}
          </Text>
          <Text
            styles={{ root: { color: 'var(--df-text-secondary)' } }}
            aria-label={`Sunset at ${formatTime(reading.sunset)}`}
          >
            <span aria-hidden="true">↓ </span>{formatTime(reading.sunset)}
          </Text>
        </Stack>
      </Stack>
    </div>
  );
};
