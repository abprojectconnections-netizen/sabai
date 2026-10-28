import { emptyAccountSnapshot, validateTrip } from './contract';
import { ApiError } from './errors';

const newRequestId = () => (globalThis.crypto && typeof globalThis.crypto.randomUUID === 'function' ? globalThis.crypto.randomUUID() : `req-${Date.now()}-${Math.random().toString(16).slice(2)}`);

/**
 * REST repository for BETA and PRODUCTION. Implements the endpoints that exist in backend/docs/openapi.yaml:
 *   POST /auth/register, POST /auth/login, GET /trips, POST /trips
 * Response envelope: { data?, error?: { code, message }, request_id }.
 *
 * The access token is kept in memory only (never localStorage). Authorization is enforced by the server.
 * NOT VERIFIED against a running backend in this repository's CI (see docs/05-known-limitations.md);
 * behaviour is covered by contract tests with a fake fetch.
 *
 * @param {{ baseUrl: string, mode: 'beta'|'production', fetchImpl?: typeof fetch, timeoutMs?: number, onUnauthorized?: () => void }} options
 * @returns {import('./contract').AppRepository}
 */
export function createHttpRepository({ baseUrl, mode, fetchImpl, timeoutMs = 10000, onUnauthorized }) {
  let accessToken = '';
  const doFetch = (...args) => (fetchImpl || globalThis.fetch)(...args);

  async function request(path, { method = 'GET', body, auth = false } = {}) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    const requestId = newRequestId();
    const headers = { Accept: 'application/json', 'X-Request-ID': requestId };
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    if (auth && accessToken) headers.Authorization = `Bearer ${accessToken}`;
    let response;
    try {
      response = await doFetch(`${baseUrl}${path}`, { method, headers, body: body === undefined ? undefined : JSON.stringify(body), signal: controller.signal });
    } catch (e) {
      throw new ApiError({ code: e && e.name === 'AbortError' ? 'TIMEOUT' : 'NETWORK_ERROR', message: 'request failed', requestId });
    } finally {
      clearTimeout(timer);
    }
    let payload = null;
    try { payload = await response.json(); } catch { payload = null; }
    const rid = (payload && payload.request_id) || response.headers?.get?.('X-Request-ID') || requestId;
    if (!response.ok) {
      const err = payload && payload.error;
      if (response.status === 401 && auth && typeof onUnauthorized === 'function') onUnauthorized();
      throw new ApiError({ code: (err && err.code) || (response.status >= 500 ? 'INTERNAL_ERROR' : 'HTTP_ERROR'), message: (err && err.message) || `HTTP ${response.status}`, status: response.status, requestId: rid });
    }
    if (!payload || payload.data === undefined) throw new ApiError({ code: 'BAD_RESPONSE', message: 'response is missing data', status: response.status, requestId: rid });
    return payload.data;
  }

  const toSession = (data) => {
    if (!data || typeof data.access_token !== 'string' || !data.access_token) throw new ApiError({ code: 'BAD_RESPONSE', message: 'response is missing access_token' });
    accessToken = data.access_token;
    const u = data.user;
    return { accessToken, tokenType: data.token_type || 'Bearer', ...(u ? { user: { id: u.id, email: u.email, displayName: u.display_name } } : {}) };
  };
  const toTrip = (t) => {
    const trip = { id: t.id, name: t.name, destinationId: t.destination_id || '', startDate: t.start_date || '', endDate: t.end_date || '', status: t.status || 'DRAFT', createdAt: t.created_at || '' };
    if (!validateTrip(trip)) throw new ApiError({ code: 'BAD_RESPONSE', message: 'trip payload is invalid' });
    return trip;
  };

  return {
    mode,
    // No snapshot endpoint exists yet: a new BETA/PRODUCTION account starts empty. Mock data is never injected here.
    async loadAccountSnapshot() { return emptyAccountSnapshot(); },
    auth: {
      async login({ email, password }) { return toSession(await request('/auth/login', { method: 'POST', body: { email, password } })); },
      async register({ email, password, displayName }) { return toSession(await request('/auth/register', { method: 'POST', body: { email, password, display_name: displayName } })); },
      logout() { accessToken = ''; },
    },
    trips: {
      async list() {
        const data = await request('/trips', { auth: true });
        if (!Array.isArray(data)) throw new ApiError({ code: 'BAD_RESPONSE', message: 'trips must be an array' });
        return data.map(toTrip);
      },
      async create({ name, destinationId = '', startDate = '', endDate = '' }) {
        return toTrip(await request('/trips', { method: 'POST', auth: true, body: { name, destination_id: destinationId, start_date: startDate, end_date: endDate } }));
      },
    },
  };
}
