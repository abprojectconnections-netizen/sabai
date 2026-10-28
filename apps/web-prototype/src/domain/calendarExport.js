import { addDaysISO, diffDays, fmtMins, toMins } from './dates';
import { placeQuery } from './maps';
import { EVENT_KINDS, summarizePlan } from './tripPlan';

export const compactDate = (iso) => iso.replace(/-/g, '');

export const flightGcal = (f) => ({ title: `เที่ยวบิน ${f.number} ${f.from}→${f.to}`, date: f.date, time: f.dep, endTime: f.arr, location: `${f.fromName} (${f.from})`, details: `${f.airline} ${f.number}\nออก ${f.dep} ถึง ${f.arr} (${f.to})\nควรถึงสนามบินก่อนเวลาบิน 2 ชั่วโมง` });

export const endTimeOf = (g) => g.endTime || fmtMins(Math.min(toMins(g.time) + 60, 1439));

export function gcalUrl(g) {
  const dates = g.time
    ? `${compactDate(g.date)}T${g.time.replace(':', '')}00/${compactDate(g.date)}T${endTimeOf(g).replace(':', '')}00`
    : `${compactDate(g.date)}/${compactDate(addDaysISO(g.endDate || g.date, 1))}`;
  const q = [['action', 'TEMPLATE'], ['text', g.title], ['dates', dates], ['ctz', 'Asia/Bangkok'], ['details', g.details || ''], ['location', g.location || '']];
  return `https://calendar.google.com/calendar/render?${q.map(([k, v]) => `${k}=${encodeURIComponent(v)}`).join('&')}`;
}

export const icsEscape = (t) => String(t).replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\r?\n/g, '\\n');

// RFC 5545: บรรทัดยาวไม่เกิน 75 octets (นับเป็น UTF-8) ส่วนที่ต่อขึ้นบรรทัดใหม่นำหน้าด้วยช่องว่าง
export function icsFold(line) {
  const enc = new TextEncoder();
  const out = [];
  let cur = '';
  let bytes = 0;
  let limit = 75;
  Array.from(line).forEach((ch) => {
    const n = enc.encode(ch).length;
    if (bytes + n > limit) { out.push(cur); cur = ' '; bytes = 1; limit = 75; }
    cur += ch; bytes += n;
  });
  out.push(cur);
  return out;
}

export function buildICS(plans, events, prefs) {
  const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\.\d+Z$/, 'Z');
  const L = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Sabai Travel//Trip Planner//TH', 'CALSCALE:GREGORIAN', 'METHOD:PUBLISH', 'X-WR-CALNAME:Sabai Travel', 'X-WR-TIMEZONE:Asia/Bangkok',
    'BEGIN:VTIMEZONE', 'TZID:Asia/Bangkok', 'BEGIN:STANDARD', 'DTSTART:19700101T000000', 'TZOFFSETFROM:+0700', 'TZOFFSETTO:+0700', 'TZNAME:ICT', 'END:STANDARD', 'END:VTIMEZONE'];
  const add = ({ uid, title, date, endDate, time, endTime, details, location, alarms = [] }) => {
    L.push('BEGIN:VEVENT', `UID:${uid}@sabai.example`, `DTSTAMP:${stamp}`);
    if (time) {
      L.push(`DTSTART;TZID=Asia/Bangkok:${compactDate(date)}T${time.replace(':', '')}00`, `DTEND;TZID=Asia/Bangkok:${compactDate(date)}T${endTimeOf({ time, endTime }).replace(':', '')}00`);
    } else {
      L.push(`DTSTART;VALUE=DATE:${compactDate(date)}`, `DTEND;VALUE=DATE:${compactDate(addDaysISO(endDate || date, 1))}`);
    }
    L.push(`SUMMARY:${icsEscape(title)}`);
    if (details) L.push(`DESCRIPTION:${icsEscape(details)}`);
    if (location) L.push(`LOCATION:${icsEscape(location)}`);
    alarms.forEach((m) => L.push('BEGIN:VALARM', 'ACTION:DISPLAY', `DESCRIPTION:${icsEscape(title)}`, `TRIGGER:-PT${m}M`, 'END:VALARM'));
    L.push('END:VEVENT');
  };
  plans.forEach((p) => {
    add({ uid: `trip-${p.id}`, title: `ทริป${p.destination} ${p.days} วัน`, date: p.startDate, endDate: p.endDate, details: summarizePlan(p), location: p.destination, alarms: prefs.kinds.tripeve ? [900] : [] });
    [p.outbound, p.ret].filter(Boolean).forEach((f, i) => {
      const g = flightGcal(f);
      add({ uid: `flight-${p.id}-${i}`, ...g, alarms: [...(prefs.kinds.checkin ? [1440] : []), ...(prefs.kinds.airport ? [180] : [])] });
    });
    p.itinerary.days.forEach((d, di) => d.items.forEach((it, j) => {
      if (!it.time || diffDays(p.startDate, p.endDate) < di) return;
      add({ uid: `stop-${p.id}-${di}-${j}`, title: it.text, date: addDaysISO(p.startDate, di), time: it.time, details: `${d.title} · ทริป${p.destination}`, location: it.place ? placeQuery(it.place, p.destination) : p.destination });
    }));
  });
  events.forEach((e) => add({ uid: `event-${e.id}`, title: e.title, date: e.date, time: e.time || undefined, location: e.place, details: `${(EVENT_KINDS[e.kind] || {}).label || 'นัดหมาย'} · สร้างจาก Sabai`, alarms: prefs.kinds.event && e.time ? [prefs.eventLead] : [] }));
  L.push('END:VCALENDAR');
  return `${L.flatMap(icsFold).join('\r\n')}\r\n`;
}

export function downloadText(filename, text, mime) {
  const url = URL.createObjectURL(new Blob([text], { type: mime }));
  const a = document.createElement('a');
  a.href = url; a.download = filename;
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
