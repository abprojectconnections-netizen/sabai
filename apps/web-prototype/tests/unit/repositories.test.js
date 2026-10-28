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
  it('never injects mock data: BETA/PRODUCTION accounts start empty', async () => {
    const snap = await http(fakeFetch(json(200, { data: [], request_id: 'r' }))).loadAccountSnapshot();
    expect(snap).toEqual(emptyAccountSnapshot());
    expect(validateAccountSnapshot(snap)).toEqual([]);
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
