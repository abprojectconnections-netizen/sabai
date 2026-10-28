import { INITIAL_COMMENTS, INITIAL_COUPONS, INITIAL_POSTS, seedBookings, seedEvents, seedNotifications, seedReviews, seedWalletTransactions } from '../data/fixtures';
import { ApiError } from './errors';

const sleep = (ms) => (ms > 0 ? new Promise((r) => setTimeout(r, ms)) : Promise.resolve());
const clone = (v) => (typeof structuredClone === 'function' ? structuredClone(v) : JSON.parse(JSON.stringify(v)));

/**
 * In-memory repository for DEV and offline demos. Mirrors the validation rules of the Go API
 * (email contains "@", password >= 8 chars on register, trip name required) so UI behaviour matches.
 * Data is synthetic; it is never copied into BETA or PRODUCTION.
 *
 * @param {{ latencyMs?: number, failLoad?: boolean }} [options]
 * @returns {import('./contract').AppRepository}
 */
export function createMockRepository({ latencyMs = 0, failLoad = false } = {}) {
  let tripCounter = 0;
  let session = null;
  const trips = [];
  const issue = (email, displayName) => {
    session = { accessToken: 'mock-token', tokenType: 'Bearer', user: { id: 'mock-user', email, displayName } };
    return clone(session);
  };

  return {
    mode: 'mock',
    async loadAccountSnapshot() {
      await sleep(latencyMs);
      if (failLoad) throw new ApiError({ code: 'NETWORK_ERROR', message: 'mock load failure' });
      return {
        coupons: clone(INITIAL_COUPONS),
        bookings: seedBookings(),
        walletBalance: 4250,
        walletTransactions: seedWalletTransactions(),
        notifications: seedNotifications(),
        reviews: seedReviews(),
        supportTickets: [],
        events: seedEvents(),
        community: { posts: clone(INITIAL_POSTS), comments: clone(INITIAL_COMMENTS) },
      };
    },
    auth: {
      async login({ email, password }) {
        await sleep(latencyMs);
        if (!email || !password) throw new ApiError({ code: 'VALIDATION_ERROR', message: 'email and password are required', status: 400 });
        return issue(email, email.split('@')[0]);
      },
      async register({ email, password, displayName }) {
        await sleep(latencyMs);
        if (!String(email).includes('@') || String(password).length < 8) {
          throw new ApiError({ code: 'VALIDATION_ERROR', message: 'email and a password of at least 8 characters are required', status: 400 });
        }
        return issue(email, displayName || '');
      },
      logout() { session = null; },
    },
    trips: {
      async list() { await sleep(latencyMs); return clone(trips); },
      async create({ name, destinationId = '', startDate = '', endDate = '' }) {
        await sleep(latencyMs);
        if (!name) throw new ApiError({ code: 'VALIDATION_ERROR', message: 'trip name is required', status: 400 });
        tripCounter += 1;
        const trip = { id: `mock-trip-${tripCounter}`, name, destinationId, startDate, endDate, status: 'DRAFT', createdAt: new Date().toISOString() };
        trips.push(trip);
        return clone(trip);
      },
    },
  };
}
