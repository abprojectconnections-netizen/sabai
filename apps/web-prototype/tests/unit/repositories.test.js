import { afterEach, describe, expect, it, vi } from 'vitest';
import { assertRepository, emptyAccountSnapshot, validateAccountSnapshot } from '../../src/repositories/contract';
import { ApiError, describeApiErrorTh } from '../../src/repositories/errors';
import { createHttpRepository } from '../../src/repositories/httpRepository';
import { createRepository } from '../../src/repositories';
import { createMockRepository } from '../../src/repositories/mockRepository';

afterEach(() => vi.useRealTimers());

const json = (status, body, headers = {}) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json', ...headers } });
const fakeFetch = (...responses) => {
  const calls = [];
  const queue = [...responses];
  const fn = vi.fn(async (url, init) => {
    calls.push({ url, init });
    const next = queue.length > 1 ? queue.shift() : queue[0];
    if (next instanceof Error) throw next;
    return typeof next === 'function' ? next(url, init) : next.clone();
  });
  fn.calls = calls;
  return fn;
};
const http = (fetchImpl, extra = {}) => createHttpRepository({ baseUrl: 'https://api.test/api/v1', mode: 'beta', fetchImpl, ...extra });

describe('mock repository', () => {
  it('satisfies the repository contract and returns a valid snapshot', async () => {
    const repo = assertRepository(createMockRepository());
    const snap = await repo.loadAccountSnapshot();
    expect(validateAccountSnapshot(snap)).toEqual([]);
    expect(snap.bookings.length).toBeGreaterThan(0);
  });
  it('hands out independent copies so one session cannot corrupt the next', async () => {
    const repo = createMockRepository();
    const a = await repo.loadAccountSnapshot();
    a.bookings.length = 0;
    a.community.posts.length = 0;
    const b = await repo.loadAccountSnapshot();
    expect(b.bookings.length).toBeGreaterThan(0);
    expect(b.community.posts.length).toBeGreaterThan(0);
  });
  it('can simulate a load failure for error-state testing', async () => {
    await expect(createMockRepository({ failLoad: true }).loadAccountSnapshot()).rejects.toMatchObject({ code: 'NETWORK_ERROR' });
  });
  it('mirrors the backend validation rules', async () => {
    const { auth, trips } = createMockRepository();
    await expect(auth.login({ email: '', password: '' })).rejects.toMatchObject({ code: 'VALIDATION_ERROR', status: 400 });
    await expect(auth.register({ email: 'no-at', password: 'longenough', displayName: 'x' })).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
    await expect(auth.register({ email: 'a@b.co', password: 'short', displayName: 'x' })).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
    await expect(auth.login({ email: 'a@b.co', password: 'pw' })).resolves.toMatchObject({ tokenType: 'Bearer' });
    await expect(trips.create({ name: '' })).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
    const t = await trips.create({ name: 'ทริปทดสอบ', destinationId: 'chiangmai' });
    expect(t).toMatchObject({ name: 'ทริปทดสอบ', status: 'DRAFT' });
    expect(await trips.list()).toHaveLength(1);
  });
});

describe('http repository (contract tests with a fake fetch)', () => {
  it('logs in, stores the token in memory and sends it on authenticated calls only', async () => {
    const f = fakeFetch(json(200, { data: { access_token: 'tok-1', token_type: 'Bearer' }, request_id: 'r1' }), json(200, { data: [], request_id: 'r2' }));
    const repo = http(f);
    const session = await repo.auth.login({ email: 'a@b.co', password: 'password1' });
    expect(session).toEqual({ accessToken: 'tok-1', tokenType: 'Bearer' });
    expect(f.calls[0].url).toBe('https://api.test/api/v1/auth/login');
    expect(JSON.parse(f.calls[0].init.body)).toEqual({ email: 'a@b.co', password: 'password1' });
    expect(f.calls[0].init.headers.Authorization).toBeUndefined();
    expect(f.calls[0].init.headers['X-Request-ID']).toBeTruthy();
    await repo.trips.list();
    expect(f.calls[1].init.headers.Authorization).toBe('Bearer tok-1');
  });
  it('maps register input and response to the API field names', async () => {
    const f = fakeFetch(json(201, { data: { user: { id: 'u1', email: 'a@b.co', display_name: 'สมชาย ใจดี' }, access_token: 't', token_type: 'Bearer' }, request_id: 'r' }));
    const s = await http(f).auth.register({ email: 'a@b.co', password: 'password1', displayName: 'สมชาย ใจดี' });
    expect(JSON.parse(f.calls[0].init.body)).toEqual({ email: 'a@b.co', password: 'password1', display_name: 'สมชาย ใจดี' });
    expect(s.user).toEqual({ id: 'u1', email: 'a@b.co', displayName: 'สมชาย ใจดี' });
  });
  it('creates trips with snake_case fields and maps the response', async () => {
    const f = fakeFetch(json(201, { data: { access_token: 't' }, request_id: 'r' }), json(201, { data: { id: 'uuid-1', name: 'ทริปเชียงใหม่ 3 วัน', destination_id: 'chiangmai', start_date: '', end_date: '', status: 'DRAFT', created_at: '2026-10-28T00:00:00Z' }, request_id: 'r' }));
    const repo = http(f);
    await repo.auth.login({ email: 'a@b.co', password: 'password1' });
    const trip = await repo.trips.create({ name: 'ทริปเชียงใหม่ 3 วัน', destinationId: 'chiangmai' });
    expect(JSON.parse(f.calls[1].init.body)).toEqual({ name: 'ทริปเชียงใหม่ 3 วัน', destination_id: 'chiangmai', start_date: '', end_date: '' });
    expect(trip).toEqual({ id: 'uuid-1', name: 'ทริปเชียงใหม่ 3 วัน', destinationId: 'chiangmai', startDate: '', endDate: '', status: 'DRAFT', createdAt: '2026-10-28T00:00:00Z' });
  });
  it('surfaces the error envelope (code, message, request id)', async () => {
    const f = fakeFetch(json(400, { error: { code: 'VALIDATION_ERROR', message: 'email and password are required' }, request_id: 'req-9' }));
    await expect(http(f).auth.login({ email: '', password: '' })).rejects.toMatchObject({ name: 'ApiError', code: 'VALIDATION_ERROR', status: 400, requestId: 'req-9', message: 'email and password are required' });
  });
  it('maps 401 to UNAUTHORIZED and notifies the app on authenticated calls', async () => {
    const onUnauthorized = vi.fn();
    const f = fakeFetch(json(200, { data: { access_token: 't' }, request_id: 'r' }), json(401, { error: { code: 'UNAUTHORIZED', message: 'invalid credentials' }, request_id: 'r' }));
    const repo = http(f, { onUnauthorized });
    await repo.auth.login({ email: 'a@b.co', password: 'password1' });
    await expect(repo.trips.list()).rejects.toMatchObject({ code: 'UNAUTHORIZED' });
    expect(onUnauthorized).toHaveBeenCalledTimes(1);
  });
  it('does not call onUnauthorized for a failed login', async () => {
    const onUnauthorized = vi.fn();
    const f = fakeFetch(json(401, { error: { code: 'UNAUTHORIZED', message: 'invalid credentials' }, request_id: 'r' }));
    await expect(http(f, { onUnauthorized }).auth.login({ email: 'a@b.co', password: 'bad' })).rejects.toMatchObject({ code: 'UNAUTHORIZED' });
    expect(onUnauthorized).not.toHaveBeenCalled();
  });
  it('maps network failures and server errors', async () => {
    await expect(http(fakeFetch(new TypeError('failed to fetch'))).auth.login({ email: 'a', password: 'b' })).rejects.toMatchObject({ code: 'NETWORK_ERROR' });
    await expect(http(fakeFetch(json(500, { error: { code: 'INTERNAL_ERROR', message: 'an unexpected error occurred' }, request_id: 'r' }))).auth.login({ email: 'a', password: 'b' })).rejects.toMatchObject({ code: 'INTERNAL_ERROR', status: 500 });
    await expect(http(fakeFetch(new Response('<html>bad gateway</html>', { status: 502 }))).auth.login({ email: 'a', password: 'b' })).rejects.toMatchObject({ code: 'INTERNAL_ERROR', status: 502 });
  });
  it('times out hung requests', async () => {
    vi.useFakeTimers();
    const hung = vi.fn((url, init) => new Promise((_, reject) => init.signal.addEventListener('abort', () => reject(Object.assign(new Error('aborted'), { name: 'AbortError' })))));
    const p = http(hung, { timeoutMs: 500 }).auth.login({ email: 'a', password: 'b' });
    const assertion = expect(p).rejects.toMatchObject({ code: 'TIMEOUT' });
    await vi.advanceTimersByTimeAsync(600);
    await assertion;
  });
  it('rejects malformed success payloads instead of passing them to the UI', async () => {
    await expect(http(fakeFetch(json(200, { request_id: 'r' }))).auth.login({ email: 'a', password: 'b' })).rejects.toMatchObject({ code: 'BAD_RESPONSE' });
    await expect(http(fakeFetch(json(200, { data: {}, request_id: 'r' }))).auth.login({ email: 'a', password: 'b' })).rejects.toMatchObject({ code: 'BAD_RESPONSE' });
    await expect(http(fakeFetch(json(200, { data: { access_token: '' }, request_id: 'r' }))).auth.login({ email: 'a', password: 'b' })).rejects.toMatchObject({ code: 'BAD_RESPONSE' });
    await expect(http(fakeFetch(json(200, { data: { id: 1 }, request_id: 'r' }))).trips.list()).rejects.toMatchObject({ code: 'BAD_RESPONSE' });
    await expect(http(fakeFetch(json(201, { data: { id: '', name: '' }, request_id: 'r' }))).trips.create({ name: 'x' })).rejects.toMatchObject({ code: 'BAD_RESPONSE' });
  });
  it('forgets the token on logout', async () => {
    const f = fakeFetch(json(200, { data: { access_token: 'tok' }, request_id: 'r' }), json(200, { data: [], request_id: 'r' }));
    const repo = http(f);
    await repo.auth.login({ email: 'a@b.co', password: 'password1' });
    repo.auth.logout();
    await repo.trips.list();
    expect(f.calls[1].init.headers.Authorization).toBeUndefined();
  });
  const routes = (over = {}) => (url) => {
    const path = new URL(url).pathname.replace('/api/v1', '');
    const base = { '/bookings': [], '/wallet': { available_balance: '0.00', pending_balance: '0.00', currency: 'THB', balance_type: 'REFUND_CREDIT' }, '/wallet/transactions': [], '/notifications': [], '/reviews/mine': [], '/catalog/items': [] };
    const data = path in over ? over[path] : base[path];
    return data === undefined ? json(404, { error: { code: 'NOT_FOUND', message: 'x' }, request_id: 'r' }) : json(200, { data, request_id: 'r' });
  };
  it('sends a refund as a request with a stable Idempotency-Key and never sends an amount', async () => {
    const f = fakeFetch(json(201, { data: { id: 'rf1', status: 'APPROVED', calculated_amount: '1950.00', auto_approved: true }, request_id: 'r' }));
    const repo = http(f);
    const a = await repo.refunds.request({ bookingId: 'b1' });
    await repo.refunds.request({ bookingId: 'b1' });
    expect(a).toEqual({ id: 'rf1', status: 'APPROVED', calculatedAmount: 1950, autoApproved: true });
    const [c1, c2] = f.calls;
    expect(c1.url).toBe('https://api.test/api/v1/refunds');
    expect(JSON.parse(c1.init.body)).toEqual({ booking_id: 'b1', method: 'ORIGINAL_METHOD' });
    expect(c1.init.headers['Idempotency-Key']).toBeTruthy();
    expect(c2.init.headers['Idempotency-Key']).toBe(c1.init.headers['Idempotency-Key']);
  });
  it('explains refund failures in Thai without leaking server text', async () => {
    const f = fakeFetch(json(409, { error: { code: 'CONFLICT', message: 'booking is not refundable: internal detail' }, request_id: 'r' }));
    const err = await http(f).refunds.request({ bookingId: 'b1' }).catch((e) => e);
    expect(err.code).toBe('CONFLICT');
    expect(describeApiErrorTh(err)).not.toContain('internal detail');
    expect(describeApiErrorTh({ code: 'FINANCIAL_TRANSACTIONS_DISABLED' })).toContain('ยังไม่เปิดใช้งาน');
  });
  it('mock refunds only record the request', async () => {
    expect(await createMockRepository().refunds.request({ bookingId: 'b1' })).toMatchObject({ status: 'REQUESTED', calculatedAmount: 0, autoApproved: false });
  });
  const checkoutFetch = ({ simulate = 'ok', statuses = ['CONFIRMED'] } = {}) => {
    const seen = [];
    let polls = 0;
    const f = (url, init) => {
      const path = new URL(url).pathname.replace('/api/v1', '');
      seen.push({ path, init });
      if (path === '/bookings') return json(201, { data: { id: 'bk1' }, request_id: 'r' });
      if (path === '/payments/intents') return json(201, { data: { payment_reference: 'PAY1', qr_payload: 'QR' }, request_id: 'r' });
      if (path === '/dev/payments/simulate') return simulate === 'ok' ? json(200, { data: { result: 'APPLIED' }, request_id: 'r' }) : json(404, { error: { code: 'NOT_FOUND', message: 'x' }, request_id: 'r' });
      if (path === '/bookings/bk1') { const s = statuses[Math.min(polls, statuses.length - 1)]; polls += 1; return json(200, { data: { id: 'bk1', booking_code: 'SB1', status: s, payable_total: '1950.00' }, request_id: 'r' }); }
      return json(404, { error: { code: 'NOT_FOUND', message: 'x' }, request_id: 'r' });
    };
    f.seen = seen;
    return f;
  };
  const checkoutRepo = (f, mode = 'beta') => createHttpRepository({ baseUrl: 'https://api.test', mode, fetchImpl: f, sleepImpl: async () => {}, pollTries: 3 });
  it('checks out through the server: sends ids only, uses idempotency keys, returns the server total', async () => {
    const f = checkoutFetch();
    const r = await checkoutRepo(f).checkout.pay({ inventoryItemId: 'i1', serviceDate: '2026-12-01', method: 'PROMPTPAY_QR' });
    expect(r).toEqual({ bookingId: 'bk1', bookingCode: 'SB1', status: 'CONFIRMED', payableTotal: 1950, qrPayload: 'QR' });
    const [bk, pi] = f.seen;
    expect(JSON.parse(bk.init.body)).toEqual({ items: [{ inventory_item_id: 'i1', service_date: '2026-12-01', quantity: 1 }] });
    expect(JSON.parse(pi.init.body)).toEqual({ booking_id: 'bk1', method: 'PROMPTPAY_QR' });
    expect(bk.init.headers['Idempotency-Key']).toMatch(/^web-bk-/);
    expect(pi.init.headers['Idempotency-Key']).toMatch(/^web-pi-/);
    expect(JSON.stringify(f.seen.map((s) => s.init.body))).not.toMatch(/price|amount|total/i);
  });
  it('waits for the provider: polls until the server leaves PENDING_PAYMENT, and reports pending if it never does', async () => {
    const ok = await checkoutRepo(checkoutFetch({ statuses: ['PENDING_PAYMENT', 'PENDING_PAYMENT', 'CONFIRMED'] })).checkout.pay({ inventoryItemId: 'i1', serviceDate: '2026-12-01' });
    expect(ok.status).toBe('CONFIRMED');
    const stuck = await checkoutRepo(checkoutFetch({ statuses: ['PENDING_PAYMENT'] })).checkout.pay({ inventoryItemId: 'i1', serviceDate: '2026-12-01' });
    expect(stuck.status).toBe('PENDING_PAYMENT');
  });
  it('never calls the payment simulator in production, and tolerates its absence elsewhere', async () => {
    const prod = checkoutFetch();
    await checkoutRepo(prod, 'production').checkout.pay({ inventoryItemId: 'i1', serviceDate: '2026-12-01' });
    expect(prod.seen.some((s) => s.path.startsWith('/dev/'))).toBe(false);
    const noSim = await checkoutRepo(checkoutFetch({ simulate: 'missing', statuses: ['PENDING_PAYMENT'] })).checkout.pay({ inventoryItemId: 'i1', serviceDate: '2026-12-01' });
    expect(noSim.status).toBe('PENDING_PAYMENT');
  });
  it('reuses the booking Idempotency-Key when an attempt is retried after a failure', async () => {
    let fail = true;
    const base = checkoutFetch();
    const f = (url, init) => (new URL(url).pathname.endsWith('/payments/intents') && fail ? (fail = false, json(503, { error: { code: 'FINANCIAL_TRANSACTIONS_DISABLED', message: 'x' }, request_id: 'r' })) : base(url, init));
    const repo = checkoutRepo(f);
    await expect(repo.checkout.pay({ inventoryItemId: 'i1', serviceDate: '2026-12-01' })).rejects.toMatchObject({ code: 'FINANCIAL_TRANSACTIONS_DISABLED' });
    await repo.checkout.pay({ inventoryItemId: 'i1', serviceDate: '2026-12-01' });
    const keys = base.seen.filter((s) => s.path === '/bookings').map((s) => s.init.headers['Idempotency-Key']);
    expect(keys).toHaveLength(2);
    expect(keys[0]).toBe(keys[1]);
  });
  it('mock checkout is explicitly unsupported so the UI keeps its local simulation', async () => {
    const repo = createMockRepository();
    expect(repo.checkout.supported).toBe(false);
    await expect(repo.checkout.pay({})).rejects.toMatchObject({ code: 'NOT_SUPPORTED' });
  });
  it('never injects mock data: a new BETA/PRODUCTION account starts empty', async () => {
    const snap = await http(fakeFetch(routes())).loadAccountSnapshot();
    expect(snap).toEqual(emptyAccountSnapshot());
    expect(validateAccountSnapshot(snap)).toEqual([]);
  });
  it('builds the snapshot from the real endpoints and keeps money as server-provided figures', async () => {
    const f = fakeFetch(routes({
      '/bookings': [{ id: 'b1', booking_code: 'SB1', title: 'ทัวร์เกาะ', status: 'PENDING_PAYMENT', payable_total: '1950.00', payment_status: null, created_at: '2026-11-10T09:00:00Z' }],
      '/wallet': { available_balance: '300.00', pending_balance: '0.00', currency: 'THB', balance_type: 'REFUND_CREDIT' },
      '/wallet/transactions': [{ id: 'w1', type: 'REFUND_CREDIT', credit_amount: '300.00', debit_amount: '0.00', created_at: '2026-11-11T09:00:00Z' }],
      '/notifications': [{ id: 'n1', type: 'booking', title: 'หัวข้อ', body: 'ข้อความ', read: false, created_at: '2026-11-11T09:00:00Z' }],
      '/reviews/mine': [{ id: 'r1', subject_type: 'HOTEL', subject_id: 'h1', rating: 4.5, body: 'ดี', created_at: '2026-11-09T09:00:00Z', mine: true }],
      '/catalog/items': [{ id: 'i1', title: 'ทัวร์เกาะ', category: 'TOUR', partner_name: 'ตัวอย่างทัวร์', from_price: '1200.00', next_available_date: '2026-12-01' }],
    }));
    const snap = await http(f).loadAccountSnapshot();
    expect(validateAccountSnapshot(snap)).toEqual([]);
    expect(snap.bookings[0]).toMatchObject({ id: 'b1', number: 'SB1', title: 'ทัวร์เกาะ', amount: 1950, status: 'pending', serverStatus: 'PENDING_PAYMENT' });
    expect(snap.walletBalance).toBe(300);
    expect(snap.walletTransactions[0]).toMatchObject({ type: 'in', amount: 300 });
    expect(snap.notifications[0]).toMatchObject({ id: 'n1', message: 'ข้อความ', read: false });
    expect(snap.reviews[0]).toMatchObject({ itemType: 'hotel', rating: 4.5, comment: 'ดี' });
    expect(snap.listings[0]).toMatchObject({ id: 'i1', inventoryItemId: 'i1', type: 'attraction', name: 'ทัวร์เกาะ', price: 1200, serviceDate: '2026-12-01' });
    expect(f.calls.every((c) => c.init.method === 'GET')).toBe(true);
  });
  it('fails the whole load (no half-empty account) when an endpoint breaks or returns the wrong shape', async () => {
    await expect(http(fakeFetch(routes({ '/wallet/transactions': undefined }))).loadAccountSnapshot()).rejects.toMatchObject({ code: 'NOT_FOUND' });
    await expect(http(fakeFetch(routes({ '/wallet': [] }))).loadAccountSnapshot()).rejects.toMatchObject({ code: 'BAD_RESPONSE' });
    await expect(http(fakeFetch(routes({ '/bookings': {} }))).loadAccountSnapshot()).rejects.toMatchObject({ code: 'BAD_RESPONSE' });
  });
});

describe('repository factory and helpers', () => {
  it('selects the implementation from configuration', () => {
    expect(createRepository({ apiMode: 'mock' }).mode).toBe('mock');
    expect(createRepository({ apiMode: 'beta', apiBaseUrl: 'https://beta.test' }).mode).toBe('beta');
    expect(createRepository({ apiMode: 'production', apiBaseUrl: 'https://api.test' }).mode).toBe('production');
  });
  it('rejects incomplete repositories', () => {
    expect(() => assertRepository({})).toThrow(/loadAccountSnapshot/);
    expect(() => assertRepository({ loadAccountSnapshot() {}, auth: {}, trips: {} })).toThrow(/auth\.login/);
  });
  it('validates snapshots structurally', () => {
    expect(validateAccountSnapshot(null)).not.toEqual([]);
    expect(validateAccountSnapshot({ ...emptyAccountSnapshot(), bookings: 'x', walletBalance: NaN })).toHaveLength(2);
  });
  it('shows Thai user messages without leaking server internals', () => {
    expect(describeApiErrorTh(new ApiError({ code: 'UNAUTHORIZED', message: 'invalid credentials' }))).toBe('อีเมลหรือรหัสผ่านไม่ถูกต้อง');
    expect(describeApiErrorTh(new ApiError({ code: 'INTERNAL_ERROR', message: 'sql: connection refused to 10.0.0.5' }))).not.toContain('10.0.0.5');
    expect(describeApiErrorTh(undefined)).toContain('ไม่คาดคิด');
  });
});

describe('trips: full lifecycle against the backend contract', () => {
  const tripJson = { id: 'uuid-1', name: 'ทริป', destination_id: 'chiangmai', start_date: '2026-10-25', end_date: '2026-10-27', status: 'PLANNED', created_at: '2026-10-28T00:00:00.000000Z' };
  const loggedIn = (...responses) => {
    const f = fakeFetch(json(200, { data: { access_token: 'tok' }, request_id: 'r' }), ...responses);
    const repo = http(f);
    return repo.auth.login({ email: 'a@b.co', password: 'password1' }).then(() => ({ repo, f }));
  };

  it('gets a trip with its itinerary mapped to camelCase', async () => {
    const { repo, f } = await loggedIn(json(200, { data: { ...tripJson, days: [{ id: 'd1', date: '2026-10-25', day_number: 1, activities: [{ id: 'a1', title: 'วัด', destination_id: '', starts_at: '2026-10-25T09:00:00.000000Z', ends_at: '' }] }] }, request_id: 'r' }));
    const trip = await repo.trips.get('uuid-1');
    expect(f.calls[1].url).toBe('https://api.test/api/v1/trips/uuid-1');
    expect(trip.days).toEqual([{ id: 'd1', date: '2026-10-25', dayNumber: 1, activities: [{ id: 'a1', title: 'วัด', destinationId: '', startsAt: '2026-10-25T09:00:00.000000Z', endsAt: '' }] }]);
  });
  it('sends only the fields that changed when updating', async () => {
    const { repo, f } = await loggedIn(json(200, { data: tripJson, request_id: 'r' }));
    await repo.trips.update('uuid-1', { name: 'ใหม่', startDate: '' });
    expect(f.calls[1].init.method).toBe('PATCH');
    expect(JSON.parse(f.calls[1].init.body)).toEqual({ name: 'ใหม่', start_date: '' });
  });
  it('treats 204 No Content as success for deletes and encodes ids', async () => {
    const { repo, f } = await loggedIn(new Response(null, { status: 204 }), new Response(null, { status: 204 }));
    await expect(repo.trips.remove('a/b')).resolves.toBeUndefined();
    await expect(repo.trips.removeActivity('t1', 'a1')).resolves.toBeUndefined();
    expect(f.calls[1].url).toBe('https://api.test/api/v1/trips/a%2Fb');
    expect(f.calls[2].url).toBe('https://api.test/api/v1/trips/t1/activities/a1');
    expect(f.calls[2].init.method).toBe('DELETE');
  });
  it('adds an activity with snake_case fields', async () => {
    const { repo, f } = await loggedIn(json(201, { data: { id: 'a9', title: 'ดอยสุเทพ', destination_id: '', starts_at: '2026-10-26T09:30:00.000000Z', ends_at: '' }, request_id: 'r' }));
    const a = await repo.trips.addActivity('t1', { title: 'ดอยสุเทพ', date: '2026-10-26', startTime: '09:30' });
    expect(JSON.parse(f.calls[1].init.body)).toEqual({ title: 'ดอยสุเทพ', date: '2026-10-26', start_time: '09:30', end_time: '', destination_id: '' });
    expect(a).toMatchObject({ id: 'a9', startsAt: '2026-10-26T09:30:00.000000Z' });
  });
  it('maps 404 and 400 from the trips endpoints', async () => {
    const { repo } = await loggedIn(json(404, { error: { code: 'NOT_FOUND', message: 'trip not found' }, request_id: 'r' }), json(400, { error: { code: 'VALIDATION_ERROR', message: 'date is outside the trip dates' }, request_id: 'r' }));
    await expect(repo.trips.get('x')).rejects.toMatchObject({ code: 'NOT_FOUND', status: 404 });
    await expect(repo.trips.addActivity('t', { title: 'x', date: '2030-01-01' })).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
  });
});

describe('mock trips behave like the backend', () => {
  it('supports the whole lifecycle with the same validation rules', async () => {
    const { trips } = createMockRepository();
    const t = await trips.create({ name: ' ทริป ', destinationId: 'chiangmai', startDate: '2026-10-25', endDate: '2026-10-27' });
    expect(t.name).toBe('ทริป');
    await expect(trips.create({ name: '' })).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
    await expect(trips.create({ name: 'x', startDate: '2026-10-27', endDate: '2026-10-25' })).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
    await expect(trips.addActivity(t.id, { title: 'x', date: '2026-11-30' })).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
    const a = await trips.addActivity(t.id, { title: 'ดอยสุเทพ', date: '2026-10-26', startTime: '09:30' });
    const full = await trips.get(t.id);
    expect(full.days).toHaveLength(1);
    expect(full.days[0]).toMatchObject({ date: '2026-10-26', dayNumber: 2 });
    expect((await trips.list())[0].days).toBeUndefined();
    await trips.removeActivity(t.id, a.id);
    expect((await trips.get(t.id)).days[0].activities).toHaveLength(0);
    expect(await trips.update(t.id, { status: 'PLANNED', startDate: '' })).toMatchObject({ status: 'PLANNED', startDate: '' });
    await expect(trips.update(t.id, { status: 'NOPE' })).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
    await trips.remove(t.id);
    await expect(trips.get(t.id)).rejects.toMatchObject({ code: 'NOT_FOUND', status: 404 });
  });
});
