import { describe, expect, it } from 'vitest';
import { REMINDER_WINDOW, buildReminders, defaultReminderPrefs, selectDueReminders } from '../../src/domain/reminders';
import { atLocal } from '../../src/domain/dates';
import { checklistFor } from '../../src/domain/tripPlan';
import { samplePlan } from './helpers';

const byKind = (list, kind) => list.filter((r) => r.kind === kind);

describe('reminder generation', () => {
  const plan = samplePlan();
  const prefs = defaultReminderPrefs();
  const list = buildReminders([plan], [], [], prefs);

  it('schedules the evening before departure, check-in 24h and airport 3h before each flight', () => {
    expect(byKind(list, 'tripeve')[0].fireAt).toBe(atLocal('2026-10-24', '18:00'));
    const dep = atLocal('2026-10-25', plan.outbound.dep);
    expect(byKind(list, 'checkin').find((r) => r.id.endsWith(':out')).fireAt).toBe(dep - 24 * 3600000);
    expect(byKind(list, 'airport').find((r) => r.id.endsWith(':out')).fireAt).toBe(dep - 3 * 3600000);
    expect(byKind(list, 'checkin')).toHaveLength(2);
  });
  it('returns reminders in time order with unique, stable ids', () => {
    const times = list.map((r) => r.fireAt);
    expect([...times].sort((a, b) => a - b)).toEqual(times);
    expect(new Set(list.map((r) => r.id)).size).toBe(list.length);
    expect(buildReminders([plan], [], [], prefs).map((r) => r.id)).toEqual(list.map((r) => r.id));
  });
  it('does not remind about checklist items already done', () => {
    const done = checklistFor(plan).find((i) => i.id === 'insurance').key;
    const after = buildReminders([plan], [], [done], prefs);
    expect(after.some((r) => r.id === `rem:task:${done}`)).toBe(false);
    expect(list.some((r) => r.id === `rem:task:${done}`)).toBe(true);
  });
  it('reminds about events with the configured lead time, or at 08:00 for all-day events', () => {
    const events = [{ id: 'e1', title: 'ประชุม', date: '2026-11-02', time: '10:00', place: 'ห้อง A' }, { id: 'e2', title: 'ลา', date: '2026-11-03' }];
    const evs = byKind(buildReminders([], events, [], { ...prefs, eventLead: 30 }), 'event');
    expect(evs[0].fireAt).toBe(atLocal('2026-11-02', '10:00') - 30 * 60000);
    expect(evs[0].title).toContain('30 นาที');
    expect(evs[1].fireAt).toBe(atLocal('2026-11-03', '08:00'));
  });
  it('honours switched-off kinds', () => {
    const off = buildReminders([plan], [{ id: 'e', title: 'x', date: '2026-11-02', time: '10:00' }], [], { ...prefs, kinds: { ...prefs.kinds, checkin: false, task: false, event: false } });
    expect(byKind(off, 'checkin')).toHaveLength(0);
    expect(byKind(off, 'task')).toHaveLength(0);
    expect(byKind(off, 'event')).toHaveLength(0);
    expect(byKind(off, 'airport').length).toBeGreaterThan(0);
  });
});

describe('selecting due reminders', () => {
  const now = Date.UTC(2026, 9, 25, 5, 0, 0);
  const r = (id, fireAt) => ({ id, fireAt, kind: 'task', title: id, body: '' });
  it('fires only due, unfired reminders inside the catch-up window', () => {
    const all = [r('future', now + 60000), r('due', now - 60000), r('fired', now - 1000), r('stale', now - REMINDER_WINDOW - 1), r('edge', now - REMINDER_WINDOW + 1)];
    expect(selectDueReminders(all, new Set(['fired']), now).map((x) => x.id)).toEqual(['due', 'edge']);
  });
  it('fires nothing twice once marked', () => {
    const all = [r('a', now - 1)];
    const fired = new Set();
    expect(selectDueReminders(all, fired, now)).toHaveLength(1);
    fired.add('a');
    expect(selectDueReminders(all, fired, now)).toHaveLength(0);
  });
});
