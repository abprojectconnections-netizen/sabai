import { addDaysISO, atLocal, fmtDate, fmtMins, fmtRange, toMins } from './dates';
import { checklistFor } from './tripPlan';

export const REMINDER_KINDS = [
  { id: 'tripeve', label: 'คืนก่อนวันเดินทาง (18:00)' },
  { id: 'checkin', label: 'เปิดเช็คอินออนไลน์ (24 ชม. ก่อนบิน)' },
  { id: 'airport', label: 'ถึงเวลาออกไปสนามบิน (3 ชม. ก่อนบิน)' },
  { id: 'task', label: 'งานในเช็กลิสต์ครบกำหนด (09:00)' },
  { id: 'event', label: 'นัดหมายส่วนตัว' },
];

export const EVENT_LEADS = [15, 30, 60, 120];

export const REMINDER_WINDOW = 12 * 3600 * 1000; // เตือนย้อนหลังได้ไม่เกิน 12 ชม. เพื่อไม่ให้ท่วมเมื่อเปิดแอปหลังหายไปนาน

export const defaultReminderPrefs = () => ({ kinds: { tripeve: true, checkin: true, airport: true, task: true, event: true }, eventLead: 60, browser: false });

export function buildReminders(plans, events, checked, prefs) {
  const out = [];
  plans.forEach((p) => {
    if (prefs.kinds.tripeve) out.push({ id: `rem:tripeve:${p.id}`, kind: 'tripeve', fireAt: atLocal(addDaysISO(p.startDate, -1), '18:00'), title: `พรุ่งนี้ออกเดินทางไป${p.destination}`, body: `${fmtRange(p.startDate, p.endDate)} ตรวจเอกสาร ชาร์จอุปกรณ์ และเตรียมสัมภาระให้พร้อม` });
    [['out', p.outbound], ['ret', p.ret]].forEach(([leg, f]) => {
      if (!f) return;
      const dep = atLocal(f.date, f.dep);
      if (prefs.kinds.checkin) out.push({ id: `rem:checkin:${p.id}:${leg}`, kind: 'checkin', fireAt: dep - 24 * 3600000, title: `เช็คอินออนไลน์ได้แล้ว ${f.number}`, body: `${f.from}→${f.to} ออก ${f.dep} ${fmtDate(f.date)}` });
      if (prefs.kinds.airport) out.push({ id: `rem:airport:${p.id}:${leg}`, kind: 'airport', fireAt: dep - 3 * 3600000, title: `ได้เวลาออกเดินทางไปสนามบิน`, body: `เที่ยวบิน ${f.number} ออก ${f.dep} ควรถึงสนามบินก่อน ${fmtMins(Math.max(0, toMins(f.dep) - 120))}` });
    });
    if (prefs.kinds.task) checklistFor(p).forEach((it) => { if (!checked.includes(it.key)) out.push({ id: `rem:task:${it.key}`, kind: 'task', fireAt: atLocal(it.due, '09:00'), title: 'งานครบกำหนดวันนี้', body: `${it.label} (ทริป${p.destination})` }); });
  });
  if (prefs.kinds.event) events.forEach((e) => out.push({ id: `rem:event:${e.id}:${e.time || 'allday'}:${prefs.eventLead}`, kind: 'event', fireAt: e.time ? atLocal(e.date, e.time) - prefs.eventLead * 60000 : atLocal(e.date, '08:00'), title: e.time ? `นัดหมายอีก ${prefs.eventLead} นาที` : 'นัดหมายวันนี้', body: `${e.title}${e.time ? ` เวลา ${e.time}` : ''}${e.place ? ` ที่ ${e.place}` : ''}` }));
  return out.sort((a, b) => a.fireAt - b.fireAt);
}

/**
 * Reminders that should fire now: not fired before, due already, and not older than REMINDER_WINDOW
 * (so reopening the app after a long absence does not flood the user with stale alerts).
 */
export function selectDueReminders(reminders, firedIds, now) {
  return reminders.filter((r) => !firedIds.has(r.id) && r.fireAt <= now && r.fireAt > now - REMINDER_WINDOW);
}
