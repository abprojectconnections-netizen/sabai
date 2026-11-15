import { emptyAccountSnapshot, validateTrip } from './contract';
import { ApiError } from './errors';
import { toBooking, toListing, toNotification, toReview, toWalletTransaction } from './mappers';

const newRequestId = () => (globalThis.crypto && typeof globalThis.crypto.randomUUID === 'function' ? globalThis.crypto.randomUUID() : `req-${Date.now()}-${Math.random().toString(16).slice(2)}`);

/**
 * REST repository for BETA and PRODUCTION. Implements the endpoints that exist in backend/docs/openapi.yaml:
 *   POST /auth/register, POST /auth/login,
 *   GET /bookings, /wallet, /wallet/transactions, /notifications, /reviews/mine,
 *   GET/POST /trips, GET/PATCH/DELETE /trips/{id}, POST /trips/{id}/activities, DELETE /trips/{id}/activities/{activityId}
 * loadAccountSnapshot reads GET /bookings, /wallet, /wallet/transactions, /notifications and /reviews/mine.
 * Response envelope: { data?, error?: { code, message }, request_id }.
 *
 * The access token is kept in memory only (never localStorage). Authorization is enforced by the server.
 * NOT VERIFIED against a running backend in this repository's CI (see docs/05-known-limitations.md);
 * behaviour is covered by contract tests with a fake fetch.
 *
 * @param {{ baseUrl: string, mode: 'beta'|'production', fetchImpl?: typeof fetch, timeoutMs?: number, onUnauthorized?: () => void }} options
 * @returns {import('./contract').AppRepository}
 */
export function createHttpRepository({ baseUrl, mode, fetchImpl, timeoutMs = 10000, onUnauthorized, sleepImpl, pollTries = 8, pollMs = 1000 }) {
  let accessToken = '';
  const refundKeys = new Map();
  const attemptKeys = new Map(); // one Idempotency-Key per (item, date, quantity) attempt, cleared once the booking exists
  const wait = sleepImpl || ((ms) => new Promise((r) => setTimeout(r, ms)));
  const doFetch = (...args) => (fetchImpl || globalThis.fetch)(...args);

  async function request(path, { method = 'GET', body, auth = false, headers: extra = {} } = {}) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    const requestId = newRequestId();
    const headers = { Accept: 'application/json', 'X-Request-ID': requestId, ...extra };
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
    if (response.ok && response.status === 204) return null;
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
  const tripPath = (id) => `/trips/${encodeURIComponent(id)}`;
  const toTrip = (t) => {
    const trip = { id: t.id, name: t.name, destinationId: t.destination_id || '', startDate: t.start_date || '', endDate: t.end_date || '', status: t.status || 'DRAFT', createdAt: t.created_at || '' };
    if (!validateTrip(trip)) throw new ApiError({ code: 'BAD_RESPONSE', message: 'trip payload is invalid' });
    if (Array.isArray(t.days)) {
      trip.days = t.days.map((d) => ({
        id: d.id, date: d.date, dayNumber: d.day_number,
        activities: (d.activities || []).map((a) => ({ id: a.id, title: a.title, destinationId: a.destination_id || '', startsAt: a.starts_at || '', endsAt: a.ends_at || '' })),
      }));
    }
    return trip;
  };

  return {
    mode,
    /**
     * Built from the real endpoints (bookings, wallet, notifications, reviews). Everything without an endpoint yet
     * (coupons, support tickets, calendar events, community) starts empty: mock data is never injected here.
     */
    async loadAccountSnapshot() {
      const list = async (path) => {
        const d = await request(path, { auth: true });
        if (!Array.isArray(d)) throw new ApiError({ code: 'BAD_RESPONSE', message: `${path} must return an array` });
        return d;
      };
      const [bookings, wallet, ledger, notifications, reviews, catalog] = await Promise.all([
        list('/bookings'), request('/wallet', { auth: true }), list('/wallet/transactions'), list('/notifications'), list('/reviews/mine'), list('/catalog/items?limit=100'),
      ]);
      if (!wallet || typeof wallet.available_balance !== 'string') throw new ApiError({ code: 'BAD_RESPONSE', message: 'wallet payload is invalid' });
      return {
        ...emptyAccountSnapshot(),
        bookings: bookings.map(toBooking),
        walletBalance: Number(wallet.available_balance) || 0,
        walletTransactions: ledger.map(toWalletTransaction),
        notifications: notifications.map(toNotification),
        reviews: reviews.map(toReview),
        listings: catalog.map(toListing),
      };
    },
    auth: {
      async login({ email, password }) { return toSession(await request('/auth/login', { method: 'POST', body: { email, password } })); },
      async register({ email, password, displayName }) { return toSession(await request('/auth/register', { method: 'POST', body: { email, password, display_name: displayName } })); },
      logout() { accessToken = ''; },
    },
    checkout: {
      supported: true,
      /**
       * Create the booking, open a payment intent and wait for the SERVER to report the result. The client sends ids, a date, a
       * quantity and a method only: price, discounts and totals are computed and returned by the server.
       * In non-production environments with the mock provider, a simulated provider event is delivered through the real webhook path;
       * in production the booking stays PENDING_PAYMENT until the real provider confirms (the UI shows the QR and waits).
       */
      async pay({ inventoryItemId, serviceDate, quantity = 1, method = 'PROMPTPAY_QR' }) {
        const attempt = `${inventoryItemId}|${serviceDate}|${quantity}`;
        if (!attemptKeys.has(attempt)) attemptKeys.set(attempt, newRequestId());
        const key = attemptKeys.get(attempt);
        const b = await request('/bookings', { method: 'POST', auth: true, headers: { 'Idempotency-Key': `web-bk-${key}` }, body: { items: [{ inventory_item_id: inventoryItemId, service_date: serviceDate, quantity }] } });
        if (!b || typeof b.id !== 'string') throw new ApiError({ code: 'BAD_RESPONSE', message: 'booking payload is invalid' });
        const intent = await request('/payments/intents', { method: 'POST', auth: true, headers: { 'Idempotency-Key': `web-pi-${key}` }, body: { booking_id: b.id, method } });
        if (!intent || typeof intent.payment_reference !== 'string') throw new ApiError({ code: 'BAD_RESPONSE', message: 'payment payload is invalid' });
        if (mode !== 'production') {
          // Development simulator; absent (404) when the server runs a real provider or production. Failing here only leaves the booking unpaid.
          try { await request('/dev/payments/simulate', { method: 'POST', auth: true, body: { payment_reference: intent.payment_reference } }); } catch (e) { if (e.code !== 'NOT_FOUND') throw e; }
        }
        let detail = null;
        for (let i = 0; i < pollTries; i += 1) {
          detail = await request(`/bookings/${b.id}`, { auth: true });
          if (detail.status !== 'PENDING_PAYMENT') break;
          if (i < pollTries - 1) await wait(pollMs);
        }
        attemptKeys.delete(attempt);
        return { bookingId: b.id, bookingCode: detail.booking_code, status: detail.status, payableTotal: Number(detail.payable_total) || 0, qrPayload: intent.qr_payload || '' };
      },
    },
    refunds: {
      /** One Idempotency-Key per booking for this session, so a retry after a timeout can never create a second refund. */
      async request({ bookingId, method = 'ORIGINAL_METHOD' }) {
        if (!refundKeys.has(bookingId)) refundKeys.set(bookingId, `web-refund-${bookingId}-${newRequestId()}`);
        const r = await request('/refunds', { method: 'POST', auth: true, headers: { 'Idempotency-Key': refundKeys.get(bookingId) }, body: { booking_id: bookingId, method } });
        if (!r || typeof r.id !== 'string') throw new ApiError({ code: 'BAD_RESPONSE', message: 'refund payload is invalid' });
        return { id: r.id, status: r.status, calculatedAmount: Number(r.calculated_amount) || 0, autoApproved: !!r.auto_approved };
      },
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
      async get(id) { return toTrip(await request(tripPath(id), { auth: true })); },
      /** Only the fields present in `patch` are changed; empty start/end date clears the date. */
      async update(id, patch) {
        const body = {};
        if (patch.name !== undefined) body.name = patch.name;
        if (patch.destinationId !== undefined) body.destination_id = patch.destinationId;
        if (patch.startDate !== undefined) body.start_date = patch.startDate;
        if (patch.endDate !== undefined) body.end_date = patch.endDate;
        if (patch.status !== undefined) body.status = patch.status;
        return toTrip(await request(tripPath(id), { method: 'PATCH', auth: true, body }));
      },
      async remove(id) { await request(tripPath(id), { method: 'DELETE', auth: true }); },
      async addActivity(tripId, { title, date, startTime = '', endTime = '', destinationId = '' }) {
        const a = await request(`${tripPath(tripId)}/activities`, { method: 'POST', auth: true, body: { title, date, start_time: startTime, end_time: endTime, destination_id: destinationId } });
        if (!a || typeof a.id !== 'string') throw new ApiError({ code: 'BAD_RESPONSE', message: 'activity payload is invalid' });
        return { id: a.id, title: a.title, destinationId: a.destination_id || '', startsAt: a.starts_at || '', endsAt: a.ends_at || '' };
      },
      async removeActivity(tripId, activityId) { await request(`${tripPath(tripId)}/activities/${encodeURIComponent(activityId)}`, { method: 'DELETE', auth: true }); },
    },
  };
}
