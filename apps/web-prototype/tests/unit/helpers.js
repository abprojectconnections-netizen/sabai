import { genFlights, flightRouteFor } from '../../src/domain/flights';
import { buildItinerary } from '../../src/domain/itinerary';

/** A deterministic booked plan: Chiang Mai, 25–27 Oct 2026. */
export function samplePlan(overrides = {}) {
  const route = flightRouteFor('เชียงใหม่');
  const outbound = genFlights(route, '2026-10-25').find((f) => f.code === 'FD' && f.dep === '06:15');
  const ret = genFlights({ ...route, origin: route.dest, dest: route.origin }, '2026-10-27').find((f) => f.code === 'TG');
  return {
    id: 'b-test', number: 'SB000001', destination: 'เชียงใหม่', days: 3, travelers: 2,
    startDate: '2026-10-25', endDate: '2026-10-27', outbound, ret, skipFlights: false,
    itinerary: buildItinerary({ destinationName: 'เชียงใหม่', days: 3, budget: 10000, styles: [] }),
    ...overrides,
  };
}
