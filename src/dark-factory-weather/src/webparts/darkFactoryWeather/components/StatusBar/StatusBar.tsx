import * as React from 'react';
import { Text } from '@fluentui/react';
import { DisplayState } from '../../models/DisplayState';

export interface IStatusBarProps {
  state: DisplayState;
  lastUpdated: Date | null;
  missingKeys?: string[];
  isStale?: boolean;
}

function formatTime(date: Date): string {
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

export const StatusBar: React.FC<IStatusBarProps> = ({ state, lastUpdated, missingKeys = [], isStale }) => {
  if (state === DisplayState.SetupRequired) {
    return (
      <div
        role="alert"
        style={{
          background: 'rgba(245,158,11,0.1)',
          border: '1px solid var(--df-warning)',
          borderRadius: 4,
          padding: '8px 12px'
        }}
      >
        <Text styles={{ root: { color: 'var(--df-warning)' } }}>
          Configuration incomplete — missing keys: {missingKeys.join(', ')}.
        </Text>
      </div>
    );
  }

  if (state === DisplayState.Error && !lastUpdated) {
    return (
      <div role="status" aria-live="polite" style={{ padding: '4px 0' }}>
        <Text styles={{ root: { color: 'var(--df-warning)', fontSize: 12 } }}>
          Unable to load weather data.
        </Text>
      </div>
    );
  }

  if (!lastUpdated) return null;

  const timeStr = formatTime(lastUpdated);

  if (isStale || state === DisplayState.Cached) {
    return (
      <div role="status" aria-live="polite" style={{ padding: '4px 0' }}>
        <Text styles={{ root: { color: 'var(--df-warning)', fontSize: 12 } }}>
          <span aria-hidden="true">⚠ </span>
          {isStale
            ? `Data may be outdated — last updated ${timeStr}`
            : `Showing cached data — last updated ${timeStr}`}
        </Text>
      </div>
    );
  }

  return (
    <div role="status" aria-live="polite" style={{ padding: '4px 0' }}>
      <Text styles={{ root: { color: 'var(--df-text-secondary)', fontSize: 12 } }}>
        Updated {timeStr}
      </Text>
    </div>
  );
};
