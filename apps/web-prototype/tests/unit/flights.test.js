import { describe, expect, it } from 'vitest';
import { toMins } from '../../src/domain/dates';
import { AIRLINES, SORTS, flightRouteFor, flightSummary, genFlights } from '../../src/domain/flights';

describe('flight simulation', () => {
  it('routes from Bangkok, except Bangkok itself which departs from Chiang Mai', () => {
    expect(flightRouteFor('ภูเก็ต')).toMatchObject({ origin: { code: 'BKK' }, dest: { code: 'HKT' } });
    expect(flightRouteFor('กรุงเทพฯ')).toMatchObject({ origin: { code: 'CNX' }, dest: { code: 'BKK' } });
    expect(flightRouteFor('ปาย').dest.code).toBe('CNX');
    expect(flightRouteFor('เมืองที่ไม่รู้จัก').dest.code).toBe('DST');
  });
  it('is deterministic for the same route and date', () => {
    const route = flightRouteFor('ภูเก็ต');
    expect(genFlights(route, '2026-11-02')).toEqual(genFlights(route, '2026-11-02'));
  });
  it('offers every airline departure with valid, unique flights', () => {
    const list = genFlights(flightRouteFor('เชียงใหม่'), '2026-11-04');
    expect(list).toHaveLength(AIRLINES.reduce((n, a) => n + a.deps.length, 0));
    expect(new Set(list.map((f) => f.id)).size).toBe(list.length);
    list.forEach((f) => {
      expect(toMins(f.arr)).toBeGreaterThan(toMins(f.dep));
      expect(f.price).toBeGreaterThan(0);
      expect(f.price % 10).toBe(0);
      expect(f.from).toBe('BKK');
      expect(f.to).toBe('CNX');
    });
    expect(new Set(list.map((f) => f.code))).toEqual(new Set(AIRLINES.map((a) => a.code)));
  });
  it('prices low-cost carriers below full-service carriers on average', () => {
    const list = genFlights(flightRouteFor('เกาะสมุย'), '2026-11-04');
    const avg = (code) => { const xs = list.filter((f) => f.code === code); return xs.reduce((s, f) => s + f.price, 0) / xs.length; };
    expect(avg('FD')).toBeLessThan(avg('TG'));
    expect(avg('SL')).toBeLessThan(avg('PG'));
  });
  it('sorts by price, speed and earliest departure', () => {
    const list = genFlights(flightRouteFor('กระบี่'), '2026-11-04');
    const by = (id) => [...list].sort(SORTS.find((s) => s.id === id).fn);
    expect(by('price')[0].price).toBe(Math.min(...list.map((f) => f.price)));
    expect(by('fast')[0].mins).toBe(Math.min(...list.map((f) => f.mins)));
    expect(by('early')[0].dep).toBe(list.map((f) => f.dep).sort()[0]);
  });
  it('summarises a flight for sharing', () => {
    const f = genFlights(flightRouteFor('เชียงใหม่'), '2026-11-04')[0];
    expect(flightSummary(f)).toContain(f.number);
    expect(flightSummary(f)).toContain('BKK→CNX');
  });
});
