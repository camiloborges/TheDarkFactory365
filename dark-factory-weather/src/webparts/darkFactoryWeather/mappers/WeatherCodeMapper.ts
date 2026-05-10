interface WeatherCodeEntry {
  label: string;
  isRain: boolean;
}

const WMO_CODE_MAP: Record<number, WeatherCodeEntry> = {
  0:  { label: 'Clear sky',                  isRain: false },
  1:  { label: 'Mainly clear',               isRain: false },
  2:  { label: 'Partly cloudy',              isRain: false },
  3:  { label: 'Overcast',                   isRain: false },
  45: { label: 'Fog',                        isRain: false },
  48: { label: 'Depositing rime fog',        isRain: false },
  51: { label: 'Light drizzle',             isRain: true  },
  53: { label: 'Moderate drizzle',          isRain: true  },
  55: { label: 'Dense drizzle',             isRain: true  },
  56: { label: 'Freezing drizzle',          isRain: true  },
  57: { label: 'Heavy freezing drizzle',    isRain: true  },
  61: { label: 'Slight rain',               isRain: true  },
  63: { label: 'Moderate rain',             isRain: true  },
  65: { label: 'Heavy rain',               isRain: true  },
  66: { label: 'Freezing rain',             isRain: true  },
  67: { label: 'Heavy freezing rain',      isRain: true  },
  71: { label: 'Slight snow',               isRain: false },
  73: { label: 'Moderate snow',             isRain: false },
  75: { label: 'Heavy snow',               isRain: false },
  77: { label: 'Snow grains',               isRain: false },
  80: { label: 'Slight rain showers',       isRain: true  },
  81: { label: 'Moderate rain showers',     isRain: true  },
  82: { label: 'Violent rain showers',      isRain: true  },
  85: { label: 'Slight snow showers',       isRain: false },
  86: { label: 'Heavy snow showers',        isRain: false },
  95: { label: 'Thunderstorm',              isRain: true  },
  96: { label: 'Thunderstorm with hail',    isRain: true  },
  99: { label: 'Thunderstorm with heavy hail', isRain: true }
};

const DEFAULT_ENTRY: WeatherCodeEntry = { label: 'Unknown conditions', isRain: false };

export function getWeatherCode(code: number): WeatherCodeEntry {
  return WMO_CODE_MAP[code] ?? DEFAULT_ENTRY;
}
