import { describe, expect, it } from 'vitest';
import { buildICS, flightGcal, gcalUrl, icsEscape, icsFold } from '../../src/domain/calendarExport';
import { defaultReminderPrefs } from '../../src/domain/reminders';
import { samplePlan } from './helpers';

const params = (url) => Object.fromEntries(new URL(url).searchParams);
const unfold = (ics) => ics.replace(/\r\n /g, '');

describe('Google Calendar links', () => {
  it('builds an all-day range with an exclusive end date', () => {
    const p = params(gcalUrl({ title: 'ทริปเชียงใหม่', date: '2026-10-25', endDate: '2026-10-27', details: 'รายละเอียด', location: 'เชียงใหม่' }));
    expect(p.action).toBe('TEMPLATE');
    expect(p.dates).toBe('20261025/20261028');
    expect(p.ctz).toBe('Asia/Bangkok');
    expect(p.text).toBe('ทริปเชียงใหม่');
    expect(p.location).toBe('เชียงใหม่');
  });
  it('builds a timed event: explicit end, or one hour by default', () => {
    expect(params(gcalUrl({ title: 'x', date: '2026-10-25', time: '09:30', endTime: '10:45' })).dates).toBe('20261025T093000/20261025T104500');
    expect(params(gcalUrl({ title: 'x', date: '2026-10-25', time: '09:30' })).dates).toBe('20261025T093000/20261025T103000');
    expect(params(gcalUrl({ title: 'x', date: '2026-10-25', time: '23:45' })).dates).toBe('20261025T234500/20261025T235900');
  });
  it('describes a flight', () => {
    const g = flightGcal(samplePlan().outbound);
    expect(g.title).toContain('BKK→CNX');
    expect(g.time).toBe('06:15');
    expect(g.details).toContain('2 ชั่วโมง');
  });
});

describe('ICS export (RFC 5545)', () => {
  const ics = buildICS([samplePlan()], [{ id: 'e1', title: 'ประชุม; บอร์ด, ชั้น 12', date: '2026-11-02', time: '10:00', place: 'ห้อง A', kind: 'meeting' }], defaultReminderPrefs());

  it('has a calendar envelope, timezone and CRLF line endings', () => {
    expect(ics.startsWith('BEGIN:VCALENDAR\r\nVERSION:2.0\r\n')).toBe(true);
    expect(ics.endsWith('END:VCALENDAR\r\n')).toBe(true);
    expect(ics).toContain('BEGIN:VTIMEZONE\r\nTZID:Asia/Bangkok');
    expect(ics.replace(/\r\n/g, '')).not.toMatch(/[\r\n]/);
  });
  it('folds every line to at most 75 octets without losing Thai text', () => {
    const lines = ics.split('\r\n').slice(0, -1);
    const enc = new TextEncoder();
    lines.forEach((l) => expect(enc.encode(l).length).toBeLessThanOrEqual(75));
    expect(unfold(ics)).toContain('SUMMARY:ทริปเชียงใหม่ 3 วัน');
    expect(lines.some((l) => l.startsWith(' '))).toBe(true); // something was actually folded
  });
  it('escapes semicolons, commas, backslashes and newlines in text values', () => {
    expect(icsEscape('a;b,c\\d\ne')).toBe('a\\;b\\,c\\\\d\\ne');
    expect(unfold(ics)).toContain('SUMMARY:ประชุม\\; บอร์ด\\, ชั้น 12');
  });
  it('writes all-day trips with exclusive DTEND and timed flights in Bangkok time', () => {
    const t = unfold(ics);
    expect(t).toContain('DTSTART;VALUE=DATE:20261025');
    expect(t).toContain('DTEND;VALUE=DATE:20261028');
    expect(t).toContain('DTSTART;TZID=Asia/Bangkok:20261025T061500');
  });
  it('contains balanced events with unique UIDs', () => {
    const begins = (ics.match(/BEGIN:VEVENT/g) || []).length;
    expect(begins).toBe((ics.match(/END:VEVENT/g) || []).length);
    expect(begins).toBeGreaterThanOrEqual(1 + 2 + 3 + 1); // trip + 2 flights + >=3 stops + 1 event
    const uids = ics.match(/UID:[^\r\n]+/g);
    expect(new Set(uids).size).toBe(uids.length);
  });
  it('attaches reminders according to preferences', () => {
    expect(ics).toContain('TRIGGER:-PT900M');
    expect(ics).toContain('TRIGGER:-PT1440M');
    expect(ics).toContain('TRIGGER:-PT180M');
    expect(ics).toContain('TRIGGER:-PT60M');
    const off = buildICS([samplePlan()], [], { ...defaultReminderPrefs(), kinds: { tripeve: false, checkin: false, airport: false, task: false, event: false } });
    expect(off).not.toContain('BEGIN:VALARM');
  });
  it('omits flights for travellers who already hold tickets', () => {
    const own = buildICS([samplePlan({ outbound: null, ret: null, skipFlights: true })], [], defaultReminderPrefs());
    expect(own).not.toContain('UID:flight-');
  });
  it('folds long ASCII and multibyte lines on character boundaries', () => {
    const folded = icsFold(`SUMMARY:${'ก'.repeat(80)}`);
    folded.forEach((l, i) => expect(new TextEncoder().encode(l).length).toBeLessThanOrEqual(75) && expect(i === 0 || l.startsWith(' ')).toBe(true));
    expect(folded.map((l, i) => (i ? l.slice(1) : l)).join('')).toBe(`SUMMARY:${'ก'.repeat(80)}`);
  });
});
