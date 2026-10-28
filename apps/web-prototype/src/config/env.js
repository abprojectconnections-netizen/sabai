/**
 * Runtime configuration (DEV / BETA / PRODUCTION).
 *
 * Rules (see docs/04-environments-and-release.md):
 *  - DEV may use the mock repository or a BETA API, never production.
 *  - BETA may use the mock repository or a BETA API, never production.
 *  - PRODUCTION must use the production API over https, never the mock repository or localhost.
 * Invalid configuration fails safely: the app shows a ConfigError screen instead of starting.
 * The client-side flag is NOT a security boundary — authorization is enforced by the backend.
 */

export const APP_ENVS = ['development', 'beta', 'production'];
export const API_MODES = ['mock', 'beta', 'production'];

export class ConfigError extends Error {
  constructor(problems) {
    super(`Invalid configuration:\n- ${problems.join('\n- ')}`);
    this.name = 'ConfigError';
    this.problems = problems;
  }
}

const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1', '::1', '[::1]', '0.0.0.0']);

function envFromMode(mode) {
  if (mode === 'production') return 'production';
  if (mode === 'beta') return 'beta';
  return 'development';
}

/** @param {Record<string, string | undefined>} env  import.meta.env-like object */
export function parseConfig(env = {}) {
  const problems = [];
  const appEnv = (env.VITE_APP_ENV || envFromMode(env.MODE)).trim();
  if (!APP_ENVS.includes(appEnv)) problems.push(`VITE_APP_ENV must be one of ${APP_ENVS.join(', ')} (got "${appEnv}")`);

  // Only DEV defaults to mock. BETA and PRODUCTION must choose explicitly so a missing variable cannot silently select mock data.
  const apiMode = (env.VITE_API_MODE || (appEnv === 'development' ? 'mock' : '')).trim();
  if (!API_MODES.includes(apiMode)) problems.push(`VITE_API_MODE must be one of ${API_MODES.join(', ')} (got "${apiMode || 'unset'}")`);

  let apiBaseUrl = '';
  if (apiMode && apiMode !== 'mock') {
    const raw = (env.VITE_API_BASE_URL || '').trim();
    if (!raw) {
      problems.push(`VITE_API_BASE_URL is required when VITE_API_MODE=${apiMode}`);
    } else {
      try {
        const url = new URL(raw);
        if (!['http:', 'https:'].includes(url.protocol)) throw new Error('protocol');
        apiBaseUrl = raw.replace(/\/+$/, '');
        if (appEnv === 'production') {
          if (url.protocol !== 'https:') problems.push('Production API URL must use https');
          if (LOCAL_HOSTS.has(url.hostname)) problems.push('Production API URL must not point at localhost');
        }
      } catch {
        problems.push(`VITE_API_BASE_URL is not a valid http(s) URL (got "${raw}")`);
      }
    }
  }

  if (appEnv === 'production' && apiMode === 'mock') problems.push('Production must not run with the mock API');
  if (appEnv === 'production' && apiMode === 'beta') problems.push('Production must use VITE_API_MODE=production');
  if (appEnv !== 'production' && apiMode === 'production') problems.push(`${appEnv} must never target the production API`);

  if (problems.length) throw new ConfigError(problems);

  return Object.freeze({
    appEnv,
    apiMode,
    apiBaseUrl,
    version: env.VITE_APP_VERSION || (typeof __APP_VERSION__ !== 'undefined' ? __APP_VERSION__ : '0.0.0'),
    buildId: (env.VITE_BUILD_ID || '').trim() || 'local',
    isProduction: appEnv === 'production',
  });
}

export function loadConfig() {
  return parseConfig(import.meta.env);
}
