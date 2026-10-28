import { flightGcal } from './calendarExport';
import { addDaysISO, diffDays, fmtDate, fmtMins, fmtRange, monthStartISO, toMins, todayISO } from './dates';
import { flightSummary } from './flights';
import { placeQuery } from './maps';

export function checklistFor(plan) {
  const items = [
    { id: 'docs', label: 'ตรวจบัตรประชาชน/พาสปอร์ตและเอกสารเดินทาง', due: addDaysISO(plan.startDate, -7) },
    { id: 'delegate', label: 'มอบหมายงานและแจ้งทีมระหว่างเดินทาง', due: addDaysISO(plan.startDate, -7) },
    { id: 'insurance', label: 'ทำประกันการเดินทาง', due: addDaysISO(plan.startDate, -5) },
    { id: 'transfer', label: 'จองรถรับส่งสนามบิน/ที่พัก', due: addDaysISO(plan.startDate, -3) },
    { id: 'cash', label: 'ตรวจวงเงินบัตรและเตรียมเงินสด', due: addDaysISO(plan.startDate, -3) },
  ];
  if (!plan.skipFlights) items.push({ id: 'checkin', label: 'เช็คอินออนไลน์ (เปิดก่อนบิน 24 ชม.)', due: addDaysISO(plan.startDate, -1) });
  items.push(
    { id: 'charge', label: 'ชาร์จอุปกรณ์และสำรองเอกสารสำคัญ', due: addDaysISO(plan.startDate, -1) },
    { id: 'expense', label: 'สรุปค่าใช้จ่ายและเก็บใบเสร็จ', due: addDaysISO(plan.endDate, 1) },
  );
  return items.map((it) => ({ ...it, key: `${plan.id}:${it.id}`, planId: plan.id }));
}

export function agendaFor(dateISO, plans, events) {
  const out = [];
  plans.forEach((p) => {
    if (dateISO < p.startDate || dateISO > p.endDate) return;
    const idx = diffDays(p.startDate, dateISO);
    out.push({ key: `${p.id}-trip`, kind: 'trip', time: null, title: `ทริป${p.destination} วันที่ ${idx + 1}/${p.days}`, sub: fmtRange(p.startDate, p.endDate), planId: p.id, gcal: { title: `ทริป${p.destination} ${p.days} วัน`, date: p.startDate, endDate: p.endDate, details: summarizePlan(p), location: p.destination } });
    if (dateISO === p.startDate && p.outbound) out.push({ key: `${p.id}-out`, kind: 'flight', time: p.outbound.dep, title: `เที่ยวบินขาไป ${p.outbound.number}`, sub: `${p.outbound.airline} · ${p.outbound.from}→${p.outbound.to} ถึง ${p.outbound.arr} · ถึงสนามบินก่อน ${fmtMins(Math.max(0, toMins(p.outbound.dep) - 120))}`, planId: p.id, gcal: flightGcal(p.outbound) });
    if (dateISO === p.endDate && p.ret) out.push({ key: `${p.id}-ret`, kind: 'flight', time: p.ret.dep, title: `เที่ยวบินขากลับ ${p.ret.number}`, sub: `${p.ret.airline} · ${p.ret.from}→${p.ret.to} ถึง ${p.ret.arr}`, planId: p.id, gcal: flightGcal(p.ret) });
    const day = p.itinerary && p.itinerary.days[idx];
    if (day) day.items.forEach((it, j) => out.push({ key: `${p.id}-s${idx}-${j}`, kind: 'stop', time: it.time, title: it.text, sub: day.title, place: it.place ? placeQuery(it.place, p.destination) : null, planId: p.id }));
  });
  events.filter((e) => e.date === dateISO).forEach((e) => out.push({ key: e.id, kind: 'event', time: e.time || null, title: e.title, sub: e.place || (EVENT_KINDS[e.kind] || {}).label || '', eventId: e.id, gcal: { title: e.title, date: e.date, time: e.time || null, location: e.place || '', details: `${(EVENT_KINDS[e.kind] || {}).label || 'นัดหมาย'} · สร้างจาก Sabai` } }));
  return out.sort((a, b) => {
    if (a.time === b.time) return 0;
    if (!a.time) return -1;
    if (!b.time) return 1;
    return a.time.localeCompare(b.time);
  });
}

export function findConflicts(plans, events) {
  const out = [];
  for (let i = 0; i < plans.length; i += 1) {
    for (let j = i + 1; j < plans.length; j += 1) {
      const a = plans[i]; const b = plans[j];
      if (a.startDate <= b.endDate && b.startDate <= a.endDate) {
        out.push({ id: `ov-${a.id}-${b.id}`, date: a.startDate < b.startDate ? b.startDate : a.startDate, planIds: [a.id, b.id], text: `ทริป${a.destination} (${fmtRange(a.startDate, a.endDate)}) ซ้อนกับทริป${b.destination} (${fmtRange(b.startDate, b.endDate)})` });
      }
    }
  }
  events.forEach((e) => {
    plans.forEach((p) => {
      if (e.date < p.startDate || e.date > p.endDate) return;
      let text = `นัด "${e.title}" ${fmtDate(e.date)} ตรงกับช่วงทริป${p.destination}`;
      if (e.time && e.date === p.startDate && p.outbound && toMins(p.outbound.dep) - (toMins(e.time) + 60) < 120) {
        text = `นัด "${e.title}" เวลา ${e.time} อาจทำให้ไม่ทันเที่ยวบิน ${p.outbound.number} เวลา ${p.outbound.dep} (ควรถึงสนามบินก่อนบิน 2 ชม.)`;
      } else if (e.time && e.date === p.endDate && p.ret && toMins(e.time) < toMins(p.ret.arr) + 30) {
        text = `นัด "${e.title}" เวลา ${e.time} อาจทำให้ไม่ทันเที่ยวบินกลับ ${p.ret.number} ซึ่งถึงเวลา ${p.ret.arr}`;
      }
      out.push({ id: `ev-${e.id}-${p.id}`, date: e.date, planIds: [p.id], eventId: e.id, text });
    });
  });
  return out.sort((a, b) => a.date.localeCompare(b.date));
}

export function summarizePlan(plan) {
  const lines = [`ทริป${plan.destination} ${plan.days} วัน (${plan.travelers} ผู้เดินทาง)`, `วันที่ ${fmtRange(plan.startDate, plan.endDate)}`];
  if (plan.outbound) lines.push(`ขาไป: ${flightSummary(plan.outbound)}`);
  if (plan.ret) lines.push(`ขากลับ: ${flightSummary(plan.ret)}`);
  if (plan.number) lines.push(`หมายเลขการจอง: ${plan.number}`);
  plan.itinerary.days.forEach((d) => {
    lines.push('', d.title);
    d.items.forEach((it) => lines.push(`${it.time} ${it.text}`));
  });
  return lines.join('\n');
}

export const EVENT_KINDS = {
  meeting: { label: 'ประชุม' },
  client: { label: 'นัดลูกค้า' },
  personal: { label: 'นัดส่วนตัว' },
};

export const emptySetup = () => ({ startDate: null, outbound: null, ret: null, skip: false, leg: 'out', airlines: [], sort: 'price', month: monthStartISO(addDaysISO(todayISO(), 1)) });

export const bandFor = (iso, start, end) => {
  if (!start || iso < start || iso > end) return null;
  if (start === end) return 'single';
  if (iso === start) return 'start';
  if (iso === end) return 'end';
  return 'mid';
};

export function setupPricing(draft, setup) {
  const base = draft.itinerary.budgetBreakdown.filter((b) => b.label !== 'เที่ยวบิน').reduce((s, b) => s + b.value, 0);
  const flights = setup.skip || !setup.outbound || !setup.ret ? 0 : (setup.outbound.price + setup.ret.price) * draft.travelers;
  return { base, flights, total: base + flights };
}
