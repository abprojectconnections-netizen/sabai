import { describe, expect, it } from 'vitest';
import { addDaysISO, addMonthsISO, diffDays, fmtDate, fmtDuration, fmtMins, fmtRange, fmtUntil, monthStartISO, toMins } from '../../src/domain/dates';

describe('date helpers', () => {
  it('adds days across month and year boundaries', () => {
    expect(addDaysISO('2026-12-31', 1)).toBe('2027-01-01');
    expect(addDaysISO('2026-03-01', -1)).toBe('2026-02-28');
    expect(addDaysISO('2028-02-28', 1)).toBe('2028-02-29');
  });
  it('counts whole days between ISO dates (either direction)', () => {
    expect(diffDays('2026-10-25', '2026-10-28')).toBe(3);
    expect(diffDays('2026-10-28', '2026-10-25')).toBe(-3);
    expect(diffDays('2026-03-28', '2026-03-30')).toBe(2);
  });
  it('formats Thai Buddhist-era dates', () => {
    expect(fmtDate('2026-10-25')).toBe('25 ต.ค. 2569');
    expect(fmtDate('2026-10-25', { dow: true })).toBe('อา. 25 ต.ค. 2569');
  });
  it('formats ranges within a month, across months, and single days', () => {
    expect(fmtRange('2026-10-25', '2026-10-27')).toBe('25–27 ต.ค. 2569');
    expect(fmtRange('2026-10-30', '2026-11-02')).toBe('30 ต.ค. – 2 พ.ย. 2569');
    expect(fmtRange('2026-10-25', '2026-10-25')).toBe('25 ต.ค. 2569');
  });
  it('converts clock strings and minutes', () => {
    expect(toMins('06:15')).toBe(375);
    expect(fmtMins(375)).toBe('06:15');
    expect(fmtMins(24 * 60 + 5)).toBe('00:05');
    expect(fmtDuration(80)).toBe('1 ชม. 20 น.');
  });
  it('normalises month navigation to the first day', () => {
    expect(monthStartISO('2026-10-25')).toBe('2026-10-01');
    expect(addMonthsISO('2026-01-31', 1)).toBe('2026-02-01');
    expect(addMonthsISO('2026-01-15', -1)).toBe('2025-12-01');
  });
  it('describes time until a reminder', () => {
    const now = 1_000_000_000_000;
    expect(fmtUntil(now - 1, now)).toBe('ถึงเวลาแล้ว');
    expect(fmtUntil(now + 30 * 60000, now)).toBe('อีก 30 นาที');
    expect(fmtUntil(now + 150 * 60000, now)).toBe('อีก 2 ชม. 30 น.');
    expect(fmtUntil(now + (2 * 1440 + 180) * 60000, now)).toBe('อีก 2 วัน 3 ชม.');
  });
});
