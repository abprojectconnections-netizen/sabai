import { assertRepository } from './contract';
import { createHttpRepository } from './httpRepository';
import { createMockRepository } from './mockRepository';

/**
 * Configuration-based dependency injection: the UI never branches on "mock mode".
 * @param {ReturnType<import('../config/env').parseConfig>} config
 * @param {{ fetchImpl?: typeof fetch, onUnauthorized?: () => void }} [deps]
 */
export function createRepository(config, deps = {}) {
  if (config.apiMode === 'mock') return assertRepository(createMockRepository());
  return assertRepository(createHttpRepository({ baseUrl: config.apiBaseUrl, mode: config.apiMode, ...deps }));
}

export { ApiError, describeApiErrorTh } from './errors';
