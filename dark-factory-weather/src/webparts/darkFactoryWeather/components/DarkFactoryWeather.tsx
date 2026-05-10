import * as React from 'react';
import { Spinner, SpinnerSize, Stack, Text } from '@fluentui/react';
import { DisplayState } from '../models/DisplayState';
import { IWeatherReading } from '../models/IWeatherReading';
import { IForecastPeriod } from '../models/IForecastPeriod';
import { IWeatherConfig } from '../models/IWeatherConfig';
import { ConfigService, ConfigError } from '../services/ConfigService';
import { WeatherService, WeatherFetchError } from '../services/WeatherService';
import { CacheService } from '../services/CacheService';
import { useAutoRefresh } from '../hooks/useAutoRefresh';
import { CurrentConditions } from './CurrentConditions/CurrentConditions';
import { ForecastStrip } from './ForecastStrip/ForecastStrip';
import { ForecastDays } from './ForecastDays/ForecastDays';
import { StatusBar } from './StatusBar/StatusBar';
import styles from './DarkFactoryWeather.module.scss';

export interface IDarkFactoryWeatherProps {
  configService: ConfigService;
  siteUrl: string;
  isTeams?: boolean;
}

interface IWeatherState {
  displayState: DisplayState;
  weatherData: IWeatherReading | null;
  periods: IForecastPeriod[];
  forecastDays: IForecastPeriod[];
  lastUpdated: Date | null;
  missingKeys: string[];
  config: IWeatherConfig | null;
  refreshEnabled: boolean;
}

export const DarkFactoryWeather: React.FC<IDarkFactoryWeatherProps> = ({ configService, isTeams }) => {
  // Services are per-instance (not module-level singletons) to avoid state sharing across multiple web part instances
  const weatherServiceRef = React.useRef(new WeatherService());
  const cacheServiceRef = React.useRef(new CacheService());

  const [state, setState] = React.useState<IWeatherState>({
    displayState: DisplayState.Loading,
    weatherData: null,
    periods: [],
    forecastDays: [],
    lastUpdated: null,
    missingKeys: [],
    config: null,
    refreshEnabled: false
  });

  const loadWeather = React.useCallback(async (cfg: IWeatherConfig): Promise<void> => {
    try {
      const result = await weatherServiceRef.current.fetch(cfg);
      cacheServiceRef.current.save(result.reading, result.periods, result.forecastDays);
      setState(prev => ({
        ...prev,
        displayState: DisplayState.Live,
        weatherData: result.reading,
        periods: result.periods,
        forecastDays: result.forecastDays,
        lastUpdated: new Date()
      }));
    } catch (err) {
      if (err instanceof WeatherFetchError) {
        const cached = cacheServiceRef.current.load();
        if (cached) {
          setState(prev => ({
            ...prev,
            displayState: DisplayState.Cached,
            weatherData: cached.reading,
            periods: cached.periods,
            forecastDays: cached.forecastDays,
            lastUpdated: cached.timestamp
          }));
        } else {
          setState(prev => ({ ...prev, displayState: DisplayState.Error }));
        }
      }
    }
  }, []);

  // configRef allows onRefresh to always see the latest config without re-initialising the interval
  const configRef = React.useRef<IWeatherConfig | null>(null);
  configRef.current = state.config;

  const onRefresh = React.useCallback(async (): Promise<void> => {
    if (configRef.current) {
      await loadWeather(configRef.current);
    }
  }, [loadWeather]);

  const intervalMs = (state.config?.refreshIntervalMinutes ?? 5) * 60 * 1000;
  useAutoRefresh(state.refreshEnabled ? onRefresh : async () => { /* no-op until config loaded */ }, intervalMs);

  React.useEffect(() => {
    const init = async (): Promise<void> => {
      try {
        const cfg = await configService.getConfig();
        setState(prev => ({ ...prev, config: cfg }));
        await loadWeather(cfg);
        setState(prev => ({ ...prev, refreshEnabled: true }));
      } catch (err) {
        if (err instanceof ConfigError) {
          setState(prev => ({
            ...prev,
            displayState: DisplayState.SetupRequired,
            missingKeys: err.missingKeys
          }));
        } else {
          setState(prev => ({ ...prev, displayState: DisplayState.Error }));
        }
      }
    };
    void init();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const isStale = state.lastUpdated ? cacheServiceRef.current.isStale(state.lastUpdated) : false;

  // Escalate Cached + stale to visually distinct warning; Live + stale = shouldn't happen but handled
  const effectiveDisplayState: DisplayState = (() => {
    if (state.displayState === DisplayState.Live && isStale) return DisplayState.Cached;
    return state.displayState;
  })();

  const containerStyle: React.CSSProperties = {
    padding: isTeams ? '8px' : '16px'
  };

  return (
    <div
      className={styles.container}
      style={containerStyle}
      role="region"
      aria-label="Dark Factory Weather"
    >
      {state.displayState === DisplayState.Loading && (
        <div className={styles.loadingContainer} role="status" aria-label="Loading weather data">
          <Spinner size={SpinnerSize.medium} label="Loading weather..." />
        </div>
      )}

      {state.displayState === DisplayState.SetupRequired && (
        <div className={styles.warningBanner} role="alert">
          <Stack tokens={{ childrenGap: 8 }}>
            <Text variant="mediumPlus" styles={{ root: { color: 'var(--df-warning)', fontWeight: 600 } }}>
              Configuration required
            </Text>
            <Text styles={{ root: { color: 'var(--df-text-primary)' } }}>
              The following config keys are missing from the DarkFactory-Settings list:
            </Text>
            <ul style={{ margin: '4px 0', paddingLeft: '20px', color: 'var(--df-text-primary)' }}>
              {state.missingKeys.map(k => <li key={k}>{k}</li>)}
            </ul>
          </Stack>
        </div>
      )}

      {state.displayState === DisplayState.Error && !state.weatherData && (
        <div className={styles.warningBanner} role="alert">
          <Text styles={{ root: { color: 'var(--df-warning)' } }}>
            Unable to load weather data. Please try again later.
          </Text>
        </div>
      )}

      {(state.displayState === DisplayState.Live ||
        state.displayState === DisplayState.Cached ||
        state.displayState === DisplayState.Error) && state.weatherData && (
        <Stack tokens={{ childrenGap: 16 }}>
          <StatusBar
            state={effectiveDisplayState}
            lastUpdated={state.lastUpdated}
            missingKeys={state.missingKeys}
            isStale={isStale}
          />
          <CurrentConditions reading={state.weatherData} />
          <ForecastStrip periods={state.periods} />
          <ForecastDays days={state.forecastDays} />
        </Stack>
      )}
    </div>
  );
};
