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
  let activityCounter = 0;
  const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;
  const TRIP_STATUSES = ['DRAFT', 'PLANNED', 'ONGOING', 'COMPLETED', 'CANCELLED'];
  const validation = (message) => new ApiError({ code: 'VALIDATION_ERROR', message, status: 400 });
  const notFound = () => new ApiError({ code: 'NOT_FOUND', message: 'trip not found', status: 404 });
  const find = (id) => { const t = trips.find((x) => x.id === id); if (!t) throw notFound(); return t; };
  // Mirrors backend/internal/trip validation so mock and real behave the same.
  const cleanTrip = ({ name, destinationId = '', startDate = '', endDate = '' }) => {
    const n = (name || '').trim();
    if (!n) throw validation('trip name is required');
    if (n.length > 200) throw validation('trip name must be at most 200 characters');
    if (destinationId.length > 36) throw validation('destination_id must be at most 36 characters');
    if ((startDate && !ISO_DATE.test(startDate)) || (endDate && !ISO_DATE.test(endDate))) throw validation('dates must be YYYY-MM-DD');
    if (startDate && endDate) {
      if (endDate < startDate) throw validation('end_date must not be before start_date');
      if ((Date.parse(endDate) - Date.parse(startDate)) / 86400000 + 1 > 60) throw validation('a trip can span at most 60 days');
    }
    return { name: n, destinationId, startDate, endDate };
  };
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
      async list() { await sleep(latencyMs); return clone(trips.map(({ days, ...t }) => t)); },
      async create({ name, destinationId = '', startDate = '', endDate = '' }) {
        await sleep(latencyMs);
        const clean = cleanTrip({ name, destinationId, startDate, endDate });
        tripCounter += 1;
        const trip = { id: `mock-trip-${tripCounter}`, ...clean, status: 'DRAFT', createdAt: new Date().toISOString(), days: [] };
        trips.push(trip);
        const { days, ...out } = trip;
        return clone(out);
      },
      async get(id) { await sleep(latencyMs); return clone(find(id)); },
      async update(id, patch) {
        await sleep(latencyMs);
        const trip = find(id);
        const clean = cleanTrip({ ...trip, ...patch });
        if (patch.status !== undefined && !TRIP_STATUSES.includes(patch.status)) throw validation('invalid trip status');
        Object.assign(trip, clean, patch.status !== undefined ? { status: patch.status } : {});
        return clone(trip);
      },
      async remove(id) { await sleep(latencyMs); find(id); trips.splice(trips.findIndex((t) => t.id === id), 1); },
      async addActivity(tripId, { title, date, startTime = '', endTime = '', destinationId = '' }) {
        await sleep(latencyMs);
        const trip = find(tripId);
        if (!title || !title.trim()) throw validation('activity title is required');
        if (!ISO_DATE.test(date || '')) throw validation('date must be YYYY-MM-DD');
        if ((trip.startDate && date < trip.startDate) || (trip.endDate && date > trip.endDate)) throw validation('date is outside the trip dates');
        if (endTime && !startTime) throw validation('start_time is required when end_time is set');
        if (startTime && endTime && endTime < startTime) throw validation('end_time must not be before start_time');
        let day = trip.days.find((d) => d.date === date);
        if (!day) {
          day = { id: `mock-day-${date}`, date, dayNumber: trip.startDate ? Math.round((Date.parse(date) - Date.parse(trip.startDate)) / 86400000) + 1 : trip.days.length + 1, activities: [] };
          trip.days.push(day);
          trip.days.sort((a, b) => a.date.localeCompare(b.date));
        }
        activityCounter += 1;
        const activity = { id: `mock-activity-${activityCounter}`, title: title.trim(), destinationId, startsAt: startTime ? `${date}T${startTime}:00.000000Z` : '', endsAt: endTime ? `${date}T${endTime}:00.000000Z` : '' };
        day.activities.push(activity);
        return clone(activity);
      },
      async removeActivity(tripId, activityId) {
        await sleep(latencyMs);
        const trip = find(tripId);
        const day = trip.days.find((d) => d.activities.some((a) => a.id === activityId));
        if (!day) throw new ApiError({ code: 'NOT_FOUND', message: 'trip not found', status: 404 });
        day.activities = day.activities.filter((a) => a.id !== activityId);
      },
    },
  };
}
