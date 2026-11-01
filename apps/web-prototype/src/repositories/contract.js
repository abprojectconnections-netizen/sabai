/**
 * Repository contract — the only way the UI talks to data sources.
 *
 * Implementations: mockRepository (DEV/offline demo), httpRepository (BETA and PRODUCTION, REST).
 * The HTTP contract mirrors backend/docs/openapi.yaml of this repository (Phase 1: /auth/register,
 * /auth/login, /trips). Endpoints that do not exist yet are NOT invented here; the matching UI data
 * stays local state and is tracked in docs/05-known-limitations.md.
 *
 * @typedef {{ accessToken: string, tokenType: string, user?: { id: string, email: string, displayName: string } }} Session
 * @typedef {{ id: string, name: string, destinationId: string, startDate: string, endDate: string, status: string, createdAt: string }} Trip
 * @typedef {Object} AccountSnapshot
 * @property {Array<object>} coupons
 * @property {Array<object>} bookings
 * @property {number} walletBalance
 * @property {Array<object>} walletTransactions
 * @property {Array<object>} notifications
 * @property {Array<object>} reviews
 * @property {Array<object>} supportTickets
 * @property {Array<object>} events
 * @property {{ posts: Array<object>, comments: Record<string, Array<object>> }} community
 *
 * @typedef {Object} AppRepository
 * @property {'mock'|'beta'|'production'} mode
 * @property {() => Promise<AccountSnapshot>} loadAccountSnapshot
 * @property {{ login(input: { email: string, password: string }): Promise<Session>,
 *             register(input: { email: string, password: string, displayName: string }): Promise<Session>,
 *             logout(): void }} auth
 * @property {{ list(): Promise<Trip[]>,
 *             create(input: { name: string, destinationId?: string, startDate?: string, endDate?: string }): Promise<Trip>,
 *             get(id: string): Promise<Trip>,
 *             update(id: string, patch: { name?: string, destinationId?: string, startDate?: string, endDate?: string, status?: string }): Promise<Trip>,
 *             remove(id: string): Promise<void>,
 *             addActivity(tripId: string, input: { title: string, date: string, startTime?: string, endTime?: string, destinationId?: string }): Promise<object>,
 *             removeActivity(tripId: string, activityId: string): Promise<void> }} trips
 */

export const SNAPSHOT_KEYS = ['coupons', 'bookings', 'walletBalance', 'walletTransactions', 'notifications', 'reviews', 'supportTickets', 'events', 'community'];

/** Brand-new account: nothing booked, nothing in the wallet. Used for BETA/PRODUCTION until their endpoints exist. */
export function emptyAccountSnapshot() {
  return {
    coupons: [], bookings: [], walletBalance: 0, walletTransactions: [], notifications: [], reviews: [], supportTickets: [], events: [],
    community: { posts: [], comments: {} },
  };
}

/** Structural validation used by contract tests and by the HTTP repository before data reaches the UI. */
export function validateAccountSnapshot(snapshot) {
  const problems = [];
  if (!snapshot || typeof snapshot !== 'object') return ['snapshot must be an object'];
  ['coupons', 'bookings', 'walletTransactions', 'notifications', 'reviews', 'supportTickets', 'events'].forEach((k) => {
    if (!Array.isArray(snapshot[k])) problems.push(`${k} must be an array`);
  });
  if (typeof snapshot.walletBalance !== 'number' || Number.isNaN(snapshot.walletBalance)) problems.push('walletBalance must be a number');
  const c = snapshot.community;
  if (!c || !Array.isArray(c.posts) || typeof c.comments !== 'object' || c.comments === null) problems.push('community must be { posts: [], comments: {} }');
  return problems;
}

export function validateTrip(trip) {
  return trip && typeof trip.id === 'string' && trip.id && typeof trip.name === 'string';
}

export function assertRepository(repo) {
  const missing = [];
  if (!repo || typeof repo.loadAccountSnapshot !== 'function') missing.push('loadAccountSnapshot');
  ['login', 'register', 'logout'].forEach((m) => { if (!repo || !repo.auth || typeof repo.auth[m] !== 'function') missing.push(`auth.${m}`); });
  ['list', 'create', 'get', 'update', 'remove', 'addActivity', 'removeActivity'].forEach((m) => { if (!repo || !repo.trips || typeof repo.trips[m] !== 'function') missing.push(`trips.${m}`); });
  if (missing.length) throw new Error(`Repository is missing: ${missing.join(', ')}`);
  return repo;
}
