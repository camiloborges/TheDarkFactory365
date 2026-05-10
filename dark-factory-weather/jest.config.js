/** @type {import('jest').Config} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'jest-environment-jsdom',
  roots: ['<rootDir>/tests'],
  setupFiles: ['<rootDir>/tests/setupFetchMock.js'],
  setupFilesAfterEnv: ['<rootDir>/tests/setup.ts'],
  moduleNameMapper: {
    '@models/(.*)': '<rootDir>/src/webparts/darkFactoryWeather/models/$1',
    '@services/(.*)': '<rootDir>/src/webparts/darkFactoryWeather/services/$1',
    '@mappers/(.*)': '<rootDir>/src/webparts/darkFactoryWeather/mappers/$1',
    '@hooks/(.*)': '<rootDir>/src/webparts/darkFactoryWeather/hooks/$1',
    '@components/(.*)': '<rootDir>/src/webparts/darkFactoryWeather/components/$1',
    '\\.module\\.scss$': '<rootDir>/tests/__mocks__/styleMock.js',
    '\\.scss$': '<rootDir>/tests/__mocks__/styleMock.js'
  },
  transform: {
    '^.+\\.tsx?$': ['ts-jest', {
      tsconfig: {
        jsx: 'react',
        esModuleInterop: true,
        skipLibCheck: true,
        types: ['jest', 'node'],
        lib: ['es2020', 'dom'],
        target: 'ES2020',
        module: 'commonjs',
        paths: {
          '@models/*': ['src/webparts/darkFactoryWeather/models/*'],
          '@services/*': ['src/webparts/darkFactoryWeather/services/*'],
          '@mappers/*': ['src/webparts/darkFactoryWeather/mappers/*'],
          '@hooks/*': ['src/webparts/darkFactoryWeather/hooks/*'],
          '@components/*': ['src/webparts/darkFactoryWeather/components/*']
        },
        baseUrl: '.'
      }
    }]
  },
  testMatch: ['**/*.test.ts', '**/*.test.tsx'],
  collectCoverageFrom: [
    'src/**/*.{ts,tsx}',
    '!src/**/*.d.ts'
  ]
};
