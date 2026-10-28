import { describe, expect, it } from 'vitest';
import { ConfigError, parseConfig } from '../../src/config/env';

const problemsOf = (env) => { try { parseConfig(env); return []; } catch (e) { expect(e).toBeInstanceOf(ConfigError); return e.problems; } };

describe('environment configuration', () => {
  it('defaults DEV to the mock API', () => {
    expect(parseConfig({})).toMatchObject({ appEnv: 'development', apiMode: 'mock', apiBaseUrl: '', isProduction: false });
  });
  it('accepts a valid BETA configuration and trims trailing slashes', () => {
    const c = parseConfig({ VITE_APP_ENV: 'beta', VITE_API_MODE: 'beta', VITE_API_BASE_URL: 'https://beta.example.com/api/v1/', VITE_BUILD_ID: 'abc123' });
    expect(c).toMatchObject({ appEnv: 'beta', apiMode: 'beta', apiBaseUrl: 'https://beta.example.com/api/v1', buildId: 'abc123' });
  });
  it('accepts a valid PRODUCTION configuration', () => {
    const c = parseConfig({ VITE_APP_ENV: 'production', VITE_API_MODE: 'production', VITE_API_BASE_URL: 'https://api.example.com/api/v1' });
    expect(c.isProduction).toBe(true);
  });
  it('derives the environment from the Vite mode when VITE_APP_ENV is missing, so a production build cannot start as DEV', () => {
    expect(problemsOf({ MODE: 'production' }).join(' ')).toContain('VITE_API_MODE');
    expect(problemsOf({ MODE: 'beta' }).join(' ')).toContain('VITE_API_MODE');
  });
  it('refuses to run PRODUCTION on mock data', () => {
    expect(problemsOf({ VITE_APP_ENV: 'production', VITE_API_MODE: 'mock' }).join(' ')).toContain('mock');
  });
  it('requires https and a non-local host in PRODUCTION', () => {
    const base = { VITE_APP_ENV: 'production', VITE_API_MODE: 'production' };
    expect(problemsOf({ ...base, VITE_API_BASE_URL: 'http://api.example.com' }).join(' ')).toContain('https');
    expect(problemsOf({ ...base, VITE_API_BASE_URL: 'https://localhost:8082/api/v1' }).join(' ')).toContain('localhost');
    expect(problemsOf({ ...base }).join(' ')).toContain('VITE_API_BASE_URL is required');
  });
  it('never lets DEV or BETA target the production API', () => {
    expect(problemsOf({ VITE_APP_ENV: 'beta', VITE_API_MODE: 'production', VITE_API_BASE_URL: 'https://api.example.com' }).join(' ')).toContain('never target the production API');
    expect(problemsOf({ VITE_APP_ENV: 'development', VITE_API_MODE: 'production', VITE_API_BASE_URL: 'https://api.example.com' }).join(' ')).toContain('never target the production API');
  });
  it('rejects unknown values and malformed URLs', () => {
    expect(problemsOf({ VITE_APP_ENV: 'staging' }).join(' ')).toContain('VITE_APP_ENV');
    expect(problemsOf({ VITE_API_MODE: 'fake' }).join(' ')).toContain('VITE_API_MODE');
    expect(problemsOf({ VITE_APP_ENV: 'beta', VITE_API_MODE: 'beta', VITE_API_BASE_URL: 'not a url' }).join(' ')).toContain('not a valid');
    expect(problemsOf({ VITE_APP_ENV: 'beta', VITE_API_MODE: 'beta', VITE_API_BASE_URL: 'ftp://x.example.com' }).join(' ')).toContain('not a valid');
  });
  it('allows a local API URL in DEV', () => {
    expect(parseConfig({ VITE_API_MODE: 'beta', VITE_API_BASE_URL: 'http://localhost:8082/api/v1' }).apiBaseUrl).toBe('http://localhost:8082/api/v1');
  });
});
