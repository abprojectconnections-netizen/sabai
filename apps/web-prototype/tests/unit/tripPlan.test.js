import { describe, expect, it } from 'vitest';
import { addDaysISO } from '../../src/domain/dates';
import { agendaFor, bandFor, checklistFor, findConflicts, setupPricing, summarizePlan } from '../../src/domain/tripPlan';
import { samplePlan } from './helpers';

describe('trip plan logic', () => {
  it('builds a checklist with due dates relative to the trip', () => {
    const items = checklistFor(samplePlan());
    const due = Object.fromEntries(items.map((i) => [i.id, i.due]));
    expect(due.docs).toBe('2026-10-18');
    expect(due.checkin).toBe('2026-10-24');
    expect(due.expense).toBe('2026-10-28');
    expect(new Set(items.map((i) => i.key)).size).toBe(items.length);
  });
  it('omits online check-in when the traveller already has tickets', () => {
    expect(checklistFor(samplePlan({ skipFlights: true, outbound: null, ret: null })).some((i) => i.id === 'checkin')).toBe(false);
  });
  it('builds a time-ordered agenda for departure day', () => {
    const entries = agendaFor('2026-10-25', [samplePlan()], [{ id: 'e1', title: 'โทรหาลูกค้า', date: '2026-10-25', time: '05:00', kind: 'client' }]);
    expect(entries[0].kind).toBe('trip'); // all-day first
    const times = entries.filter((e) => e.time).map((e) => e.time);
    expect([...times].sort()).toEqual(times);
    expect(entries.some((e) => e.kind === 'flight' && e.title.includes('ขาไป'))).toBe(true);
    expect(entries.some((e) => e.kind === 'event')).toBe(true);
    expect(entries.find((e) => e.kind === 'flight').gcal.time).toBe('06:15');
  });
  it('returns nothing outside the trip dates', () => {
    expect(agendaFor('2026-10-24', [samplePlan()], [])).toEqual([]);
    expect(agendaFor('2026-10-28', [samplePlan()], [])).toEqual([]);
  });
  it('detects overlapping trips', () => {
    const other = samplePlan({ id: 'b-other', destination: 'ภูเก็ต', startDate: '2026-10-27', endDate: '2026-10-29' });
    const found = findConflicts([samplePlan(), other], []);
    expect(found).toHaveLength(1);
    expect(found[0].text).toContain('ซ้อนกับทริป');
    expect(findConflicts([samplePlan(), { ...other, startDate: '2026-10-28', endDate: '2026-10-30' }], [])).toEqual([]);
  });
  it('warns when a meeting makes the outbound flight unreachable', () => {
    const found = findConflicts([samplePlan()], [{ id: 'e', title: 'ประชุมเช้า', date: '2026-10-25', time: '05:00', kind: 'meeting' }]);
    expect(found[0].text).toContain('อาจทำให้ไม่ทันเที่ยวบิน');
  });
  it('warns when an event lands inside the trip, and stays quiet otherwise', () => {
    const inside = findConflicts([samplePlan()], [{ id: 'e', title: 'สัมมนา', date: '2026-10-26', time: '10:00', kind: 'meeting' }]);
    expect(inside[0].text).toContain('ตรงกับช่วงทริป');
    expect(findConflicts([samplePlan()], [{ id: 'e', title: 'สัมมนา', date: '2026-11-02', time: '10:00', kind: 'meeting' }])).toEqual([]);
  });
  it('warns when an event is too early on the return day', () => {
    const plan = samplePlan();
    const clash = { id: 'e', title: 'นัดด่วน', date: plan.endDate, time: plan.ret.dep, kind: 'meeting' };
    expect(findConflicts([plan], [clash])[0].text).toContain('ไม่ทันเที่ยวบินกลับ');
  });
  it('summarises a plan for sharing with the team', () => {
    const text = summarizePlan(samplePlan());
    expect(text).toContain('ทริปเชียงใหม่ 3 วัน');
    expect(text).toContain('25–27 ต.ค. 2569');
    expect(text).toContain('ขาไป:');
    expect(text).toContain('SB000001');
  });
  it('prices the trip without the estimated flight line, then adds real flights per traveller', () => {
    const plan = samplePlan();
    const draft = { travelers: 2, itinerary: plan.itinerary };
    const base = plan.itinerary.budgetBreakdown.filter((b) => b.label !== 'เที่ยวบิน').reduce((s, b) => s + b.value, 0);
    expect(setupPricing(draft, { skip: true, outbound: null, ret: null })).toEqual({ base, flights: 0, total: base });
    const p = setupPricing(draft, { skip: false, outbound: plan.outbound, ret: plan.ret });
    expect(p.flights).toBe((plan.outbound.price + plan.ret.price) * 2);
    expect(p.total).toBe(base + p.flights);
  });
  it('marks calendar bands', () => {
    expect(bandFor('2026-10-25', '2026-10-25', '2026-10-27')).toBe('start');
    expect(bandFor('2026-10-26', '2026-10-25', '2026-10-27')).toBe('mid');
    expect(bandFor('2026-10-27', '2026-10-25', '2026-10-27')).toBe('end');
    expect(bandFor('2026-10-25', '2026-10-25', '2026-10-25')).toBe('single');
    expect(bandFor(addDaysISO('2026-10-27', 1), '2026-10-25', '2026-10-27')).toBeNull();
    expect(bandFor('2026-10-25', null, null)).toBeNull();
  });
});
