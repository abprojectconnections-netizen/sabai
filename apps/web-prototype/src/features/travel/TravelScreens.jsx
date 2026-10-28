import { useState } from 'react';
import { AlarmClock, AlertCircle, BellRing, Briefcase, Calendar, CalendarDays, CalendarPlus, Check, CheckCircle2, ChevronLeft, ChevronRight, ClipboardList, MapPin, Navigation, Plane, Plus, Trash2 } from 'lucide-react';
import { Chip, PrimaryButton, SecondaryButton, TopBar } from '../../components/ui';
import { buildICS, downloadText, flightGcal, gcalUrl } from '../../domain/calendarExport';
import { TH_DOW_FULL, TH_DOW_SHORT, TH_MONTHS, addDaysISO, diffDays, fmtDate, fmtDuration, fmtRange, fmtUntil, fromISO, pad2, relativeDay, toMins, todayISO } from '../../domain/dates';
import { AIRLINES, AIRLINE_BY_CODE, SORTS, flightRouteFor, genFlights } from '../../domain/flights';
import { mapsDirUrl } from '../../domain/maps';
import { EVENT_LEADS, REMINDER_KINDS, buildReminders } from '../../domain/reminders';
import { EVENT_KINDS, agendaFor, bandFor, checklistFor, findConflicts, setupPricing, summarizePlan } from '../../domain/tripPlan';
import { MapLink } from '../maps/MapComponents';
import { TripsScreen } from '../trips/TripsScreens';

export function MonthGrid({ month, onShift, cell, onPick, label }) {
  const first = fromISO(month);
  const dim = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate();
  const blanks = first.getDay();
  const cells = [];
  for (let i = 0; i < blanks; i += 1) cells.push(null);
  for (let d = 1; d <= dim; d += 1) cells.push(`${month.slice(0, 8)}${pad2(d)}`);
  const arrow = { width: 34, height: 34, borderRadius: 999, border: '1px solid var(--border)', background: 'var(--surface)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' };
  return (
    <div role="group" aria-label={label} style={{ border: '1px solid var(--border)', borderRadius: 18, background: 'var(--surface)', padding: 12 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
        <button onClick={() => onShift(-1)} aria-label="เดือนก่อนหน้า" style={arrow}><ChevronLeft size={16} color="var(--ink)" /></button>
        <p className="font-display" style={{ fontSize: 15, fontWeight: 600 }}>{TH_MONTHS[first.getMonth()]} {first.getFullYear() + 543}</p>
        <button onClick={() => onShift(1)} aria-label="เดือนถัดไป" style={arrow}><ChevronRight size={16} color="var(--ink)" /></button>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 2 }}>
        {TH_DOW_SHORT.map((d) => <span key={d} style={{ textAlign: 'center', fontSize: 10.5, fontWeight: 700, color: 'var(--ink-soft)', padding: '2px 0 6px' }}>{d}</span>)}
        {cells.map((iso, i) => {
          if (!iso) return <span key={`b${i}`} />;
          const c = cell(iso);
          const tripEdge = c.band === 'start' || c.band === 'end' || c.band === 'single';
          return (
            <button key={iso} onClick={() => onPick(iso)} disabled={c.disabled} aria-label={c.aria} aria-pressed={c.selected || undefined}
              style={{ height: 42, border: 'none', cursor: c.disabled ? 'default' : 'pointer', borderRadius: c.band === 'mid' ? 4 : 12, background: tripEdge ? 'var(--pine)' : c.band === 'mid' ? 'var(--pine-pale)' : 'transparent', color: tripEdge ? '#fff' : c.disabled ? 'var(--disabled)' : 'var(--ink)', boxShadow: c.selected ? 'inset 0 0 0 2px var(--amber)' : c.today ? 'inset 0 0 0 1.5px var(--border)' : 'none', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 2, fontSize: 13, fontWeight: c.today || tripEdge ? 800 : 500, padding: 0 }}>
              <span>{Number(iso.slice(8))}</span>
              <span style={{ display: 'flex', alignItems: 'center', gap: 2, height: 8 }}>
                {c.flight && <Plane size={8} />}
                {c.events > 0 && <span style={{ width: 5, height: 5, borderRadius: 999, background: 'var(--amber)' }} />}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

export function FlightCard({ flight, selected, badge, travelers, onSelect }) {
  const a = AIRLINE_BY_CODE[flight.code];
  return (
    <button onClick={onSelect} aria-pressed={selected} aria-label={`เลือกเที่ยวบิน ${flight.airline} ${flight.number} ออก ${flight.dep}`}
      style={{ textAlign: 'left', width: '100%', cursor: 'pointer', border: selected ? '2px solid var(--pine)' : '1px solid var(--border)', borderRadius: 16, background: selected ? 'var(--pine-pale)' : 'var(--surface)', padding: selected ? 13 : 14, display: 'flex', flexDirection: 'column', gap: 10 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <span aria-hidden="true" style={{ width: 34, height: 34, borderRadius: 999, background: a.color, color: '#fff', fontSize: 11, fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>{flight.code}</span>
        <span style={{ flex: 1, minWidth: 0 }}>
          <span style={{ display: 'block', fontSize: 13, fontWeight: 700, color: 'var(--ink)' }}>{flight.airline}</span>
          <span style={{ display: 'block', fontSize: 11, color: 'var(--ink-soft)' }}>{flight.number}</span>
        </span>
        {badge && <span style={{ fontSize: 10.5, fontWeight: 700, padding: '3px 9px', borderRadius: 999, background: 'var(--amber-soft)', color: 'var(--amber-ink)' }}>{badge}</span>}
        {selected && <CheckCircle2 size={18} color="var(--pine)" />}
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ textAlign: 'center' }}>
          <p className="font-display" style={{ fontSize: 17, fontWeight: 700, color: 'var(--ink)' }}>{flight.dep}</p>
          <p style={{ fontSize: 10.5, color: 'var(--ink-soft)' }}>{flight.from}</p>
        </div>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2 }}>
          <span style={{ fontSize: 10.5, color: 'var(--ink-soft)' }}>{fmtDuration(flight.mins)}</span>
          <div style={{ width: '100%', height: 1.5, background: 'var(--border)', position: 'relative' }}>
            <Plane size={13} color="var(--pine)" style={{ position: 'absolute', left: '50%', top: -6, transform: 'translateX(-50%)', background: selected ? 'var(--pine-pale)' : 'var(--surface)' }} />
          </div>
          <span style={{ fontSize: 10.5, color: 'var(--ink-soft)' }}>บินตรง</span>
        </div>
        <div style={{ textAlign: 'center' }}>
          <p className="font-display" style={{ fontSize: 17, fontWeight: 700, color: 'var(--ink)' }}>{flight.arr}</p>
          <p style={{ fontSize: 10.5, color: 'var(--ink-soft)' }}>{flight.to}</p>
        </div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
        <span style={{ fontSize: 11, color: 'var(--ink-soft)' }}>{flight.bag}</span>
        <span style={{ textAlign: 'right' }}>
          <span className="font-display" style={{ fontSize: 16, fontWeight: 700, color: 'var(--pine)' }}>฿{flight.price.toLocaleString()}</span>
          <span style={{ fontSize: 10.5, color: 'var(--ink-soft)' }}> /คน{travelers > 1 ? ` · ฿${(flight.price * travelers).toLocaleString()} รวม` : ''}</span>
        </span>
      </div>
    </button>
  );
}

export function TripSetupScreen({ hub, plans, draft, nav, onContinue }) {
  const { setup } = hub;
  if (!draft) return null;
  const today = todayISO();
  const route = flightRouteFor(draft.destination);
  const endDate = setup.startDate ? addDaysISO(setup.startDate, draft.days - 1) : null;
  const legDate = setup.leg === 'out' ? setup.startDate : endDate;
  const legRoute = setup.leg === 'out' ? route : { ...route, origin: route.dest, dest: route.origin };
  let flights = legDate ? genFlights(legRoute, legDate) : [];
  if (setup.airlines.length) flights = flights.filter((f) => setup.airlines.includes(f.code));
  if (setup.leg === 'ret' && draft.days === 1 && setup.outbound) flights = flights.filter((f) => toMins(f.dep) >= toMins(setup.outbound.arr) + 120);
  flights = [...flights].sort(SORTS.find((s) => s.id === setup.sort).fn);
  const cheapest = flights.length ? flights.reduce((m, f) => (f.price < m.price ? f : m)).id : null;
  const fastest = flights.length ? flights.reduce((m, f) => (f.mins < m.mins ? f : m)).id : null;
  const pricing = setupPricing(draft, setup);
  const ready = !!setup.startDate && (setup.skip || (!!setup.outbound && !!setup.ret));
  const candidate = setup.startDate ? { id: 'new', destination: draft.destination, startDate: setup.startDate, endDate, outbound: setup.skip ? null : setup.outbound, ret: setup.skip ? null : setup.ret } : null;
  const warnings = candidate ? findConflicts([...plans, candidate], hub.events).filter((c) => c.planIds.includes('new')) : [];

  const cell = (iso) => {
    const band = bandFor(iso, setup.startDate, endDate);
    return {
      disabled: iso <= today, band, selected: false, today: iso === today,
      flight: !setup.skip && ((setup.outbound && iso === setup.startDate) || (setup.ret && iso === endDate)),
      events: hub.events.filter((e) => e.date === iso).length,
      aria: `${fmtDate(iso, { dow: true })}${band === 'start' ? ' วันออกเดินทาง' : band === 'end' ? ' วันกลับ' : ''}${iso <= today ? ' เลือกไม่ได้' : ''}`,
    };
  };
  const pickFlight = (f) => {
    if (setup.leg === 'out') {
      const retStillValid = setup.ret && !(draft.days === 1 && toMins(setup.ret.dep) < toMins(f.arr) + 120);
      hub.patchSetup({ outbound: f, ret: retStillValid ? setup.ret : null, leg: 'ret' });
    } else {
      hub.patchSetup({ ret: f });
    }
  };
  const selectedId = setup.leg === 'out' ? setup.outbound && setup.outbound.id : setup.ret && setup.ret.id;
  const sectionTitle = (n, t) => <p className="font-display" style={{ fontSize: 15, fontWeight: 600, marginBottom: 10 }}>{n}. {t}</p>;

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="เลือกวันและเที่ยวบิน" onBack={nav.pop} />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 22 }}>
        <div style={{ borderRadius: 16, background: 'var(--pine-pale)', padding: 14 }}>
          <p className="font-display" style={{ fontSize: 16, fontWeight: 600, color: 'var(--ink)' }}>ทริป{draft.destination} {draft.days} วัน</p>
          <p style={{ fontSize: 12, color: 'var(--ink-soft)', marginTop: 2 }}>{draft.travelers} ผู้เดินทาง · จัดโดย AI · บินจาก {route.origin.airport}</p>
        </div>

        <section>
          {sectionTitle(1, 'เลือกวันออกเดินทาง')}
          <MonthGrid month={setup.month} onShift={hub.shiftSetupMonth} cell={cell} onPick={hub.chooseStart} label="ปฏิทินเลือกวันเดินทาง" />
          <p style={{ fontSize: 12.5, marginTop: 10, color: setup.startDate ? 'var(--pine)' : 'var(--ink-soft)', fontWeight: setup.startDate ? 700 : 400 }}>
            {setup.startDate ? `เดินทาง ${fmtRange(setup.startDate, endDate)} (${draft.days} วัน)` : 'แตะวันที่ต้องการออกเดินทาง ระบบจะมาร์กวันกลับให้อัตโนมัติ'}
          </p>
          {warnings.length > 0 && (
            <div role="alert" style={{ marginTop: 10, borderRadius: 14, background: 'var(--amber-soft)', padding: 12, display: 'flex', flexDirection: 'column', gap: 6 }}>
              {warnings.map((w) => (
                <p key={w.id} style={{ fontSize: 12, color: 'var(--amber-ink)', lineHeight: 1.55, display: 'flex', gap: 6 }}><AlertCircle size={14} style={{ flexShrink: 0, marginTop: 2 }} /> {w.text}</p>
              ))}
            </div>
          )}
        </section>

        {setup.startDate && (
          <section>
            {sectionTitle(2, 'เลือกเที่ยวบิน')}
            <button onClick={() => hub.patchSetup({ skip: !setup.skip })} aria-pressed={setup.skip}
              style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 10, padding: '12px 14px', marginBottom: 14, borderRadius: 14, cursor: 'pointer', textAlign: 'left', border: '1px solid var(--border)', background: setup.skip ? 'var(--pine-pale)' : 'var(--surface)', color: 'var(--ink)', fontSize: 12.5, fontWeight: 600 }}>
              <span style={{ width: 20, height: 20, borderRadius: 6, border: '2px solid var(--pine)', background: setup.skip ? 'var(--pine)' : 'transparent', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>{setup.skip && <Check size={13} color="#fff" />}</span>
              ฉันมีตั๋วเครื่องบินแล้ว ไม่ต้องจองเที่ยวบิน
            </button>
            {!setup.skip && (
              <>
                <div role="tablist" aria-label="ขาไปหรือขากลับ" style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
                  {[['out', 'ขาไป', setup.startDate, setup.outbound], ['ret', 'ขากลับ', endDate, setup.ret]].map(([id, label, d, chosen]) => (
                    <button key={id} role="tab" aria-selected={setup.leg === id} onClick={() => hub.patchSetup({ leg: id })}
                      style={{ flex: 1, padding: '10px 8px', borderRadius: 14, cursor: 'pointer', textAlign: 'left', border: setup.leg === id ? '2px solid var(--pine)' : '1px solid var(--border)', background: 'var(--surface)', color: 'var(--ink)' }}>
                      <span style={{ display: 'block', fontSize: 11, color: 'var(--ink-soft)', fontWeight: 600 }}>{label} · {fmtDate(d)}</span>
                      <span style={{ display: 'block', fontSize: 12.5, fontWeight: 700, marginTop: 2, color: chosen ? 'var(--pine)' : 'var(--ink-soft)' }}>{chosen ? `${chosen.number} · ${chosen.dep}` : 'ยังไม่ได้เลือก'}</span>
                    </button>
                  ))}
                </div>
                <p style={{ fontSize: 12, fontWeight: 700, marginBottom: 8 }}>สายการบิน (เลือกได้หลายสาย)</p>
                <div className="scrollbar-hide" style={{ display: 'flex', gap: 8, overflowX: 'auto', marginBottom: 12 }}>
                  <Chip label="ทุกสายการบิน" active={setup.airlines.length === 0} onClick={() => hub.patchSetup({ airlines: [] })} />
                  {AIRLINES.map((a) => <Chip key={a.code} label={a.name} active={setup.airlines.includes(a.code)} onClick={() => hub.toggleAirline(a.code)} />)}
                </div>
                <div className="scrollbar-hide" style={{ display: 'flex', gap: 8, overflowX: 'auto', marginBottom: 14 }}>
                  {SORTS.map((s) => <Chip key={s.id} label={s.label} active={setup.sort === s.id} onClick={() => hub.patchSetup({ sort: s.id })} />)}
                </div>
                <p aria-live="polite" style={{ fontSize: 11.5, color: 'var(--ink-soft)', marginBottom: 10 }}>พบ {flights.length} เที่ยวบิน · {legRoute.origin.code} → {legRoute.dest.code} · {fmtDate(legDate, { dow: true })}</p>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  {flights.length === 0
                    ? <p style={{ fontSize: 12.5, color: 'var(--ink-soft)', textAlign: 'center', padding: 20 }}>ไม่พบเที่ยวบินที่ตรงกับตัวกรอง ลองเลือกสายการบินเพิ่มหรือกด "ทุกสายการบิน"</p>
                    : flights.map((f) => <FlightCard key={f.id} flight={f} travelers={draft.travelers} selected={selectedId === f.id} badge={f.id === cheapest ? 'ถูกที่สุด' : f.id === fastest ? 'เร็วที่สุด' : null} onSelect={() => pickFlight(f)} />)}
                </div>
                <p style={{ fontSize: 11, color: 'var(--ink-soft)', marginTop: 12, lineHeight: 1.6 }}>ตารางบินและราคาในพรอโทไทป์เป็นข้อมูลจำลอง ไม่ใช่ราคาจริงจากสายการบิน</p>
              </>
            )}
          </section>
        )}
      </div>
      <div style={{ padding: '12px 20px 14px', borderTop: '1px solid var(--border)', flexShrink: 0, display: 'flex', flexDirection: 'column', gap: 10 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
          <span style={{ fontSize: 12, color: 'var(--ink-soft)' }}>{pricing.flights > 0 ? `รวมค่าเที่ยวบิน ฿${pricing.flights.toLocaleString()}` : 'ราคาทริป'}</span>
          <span className="font-display" style={{ fontSize: 18, fontWeight: 700, color: 'var(--pine)' }}>฿{pricing.total.toLocaleString()}</span>
        </div>
        <PrimaryButton onClick={() => onContinue(pricing)} disabled={!ready}>ไปหน้าสรุปการจอง</PrimaryButton>
        {!ready && <p style={{ fontSize: 11.5, color: 'var(--ink-soft)', textAlign: 'center', marginTop: -2 }}>{!setup.startDate ? 'เลือกวันออกเดินทางก่อน' : 'เลือกเที่ยวบินขาไปและขากลับ หรือเลือกว่ามีตั๋วแล้ว'}</p>}
      </div>
    </div>
  );
}

export const AGENDA_ICON = { trip: Briefcase, flight: Plane, stop: MapPin, event: Calendar };

export const AGENDA_COLOR = { trip: 'var(--pine)', flight: 'var(--pine)', stop: 'var(--ink-soft)', event: 'var(--amber-ink)' };

export function AgendaList({ entries, hub, emptyText }) {
  if (entries.length === 0) return <p style={{ fontSize: 12.5, color: 'var(--ink-soft)', padding: '6px 0' }}>{emptyText}</p>;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      {entries.map((e) => {
        const Icon = AGENDA_ICON[e.kind];
        return (
          <div key={e.key} style={{ display: 'flex', gap: 10, alignItems: 'flex-start', padding: 12, borderRadius: 14, border: '1px solid var(--border)', background: e.kind === 'event' ? 'var(--amber-soft)' : 'var(--surface)' }}>
            <Icon size={16} color={AGENDA_COLOR[e.kind]} style={{ marginTop: 2, flexShrink: 0 }} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <p style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--ink)' }}>{e.time && <span style={{ color: 'var(--ink-soft)', marginRight: 6 }}>{e.time}</span>}{e.title}</p>
              {e.sub && <p style={{ fontSize: 11, color: 'var(--ink-soft)', marginTop: 2 }}>{e.sub}</p>}
              {(e.place || e.gcal) && (
                <div style={{ marginTop: 6, display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                  {e.place && <MapLink href={mapsDirUrl({ destination: e.place })} icon={Navigation} label="นำทาง" ariaLabel={`นำทางไป ${e.place}`} />}
                  {e.gcal && <MapLink href={gcalUrl(e.gcal)} icon={CalendarPlus} label={e.kind === 'trip' ? 'เพิ่มทั้งทริปใน Google Calendar' : 'Google Calendar'} ariaLabel={`เพิ่ม ${e.title} ลง Google Calendar`} />}
                </div>
              )}
            </div>
            {e.eventId && (
              <button onClick={() => hub.removeEvent(e.eventId)} aria-label={`ลบนัดหมาย ${e.title}`} style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 4, display: 'flex' }}><Trash2 size={15} color="var(--danger)" /></button>
            )}
          </div>
        );
      })}
    </div>
  );
}

export function CalendarView({ hub, plans, nav }) {
  const today = todayISO();
  const cell = (iso) => {
    const plan = plans.find((p) => iso >= p.startDate && iso <= p.endDate);
    const band = plan ? bandFor(iso, plan.startDate, plan.endDate) : null;
    const events = hub.events.filter((e) => e.date === iso).length;
    const flight = plans.some((p) => (p.outbound && iso === p.startDate) || (p.ret && iso === p.endDate));
    return {
      disabled: false, band, selected: hub.selected === iso, today: iso === today, flight, events,
      aria: `${fmtDate(iso, { dow: true })}${plan ? ` ทริป${plan.destination}` : ''}${flight ? ' มีเที่ยวบิน' : ''}${events ? ` มีนัดหมาย ${events}` : ''}`,
    };
  };
  const entries = agendaFor(hub.selected, plans, hub.events);
  const legend = [['var(--pine)', 'วันเดินทาง/วันกลับ'], ['var(--pine-pale)', 'ระหว่างทริป'], ['var(--amber)', 'นัดหมาย']];
  return (
    <>
      <MonthGrid month={hub.month} onShift={hub.shiftMonth} cell={cell} onPick={hub.selectDate} label="ปฏิทินทริป" />
      <div style={{ display: 'flex', gap: 14, flexWrap: 'wrap' }}>
        {legend.map(([c, t]) => <span key={t} style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11, color: 'var(--ink-soft)' }}><span style={{ width: 10, height: 10, borderRadius: 999, background: c, border: '1px solid var(--border)' }} />{t}</span>)}
      </div>
      <section aria-label="กำหนดการของวันที่เลือก">
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
          <p className="font-display" style={{ fontSize: 15, fontWeight: 600 }}>{relativeDay(hub.selected)} · {fmtDate(hub.selected)}</p>
          <button onClick={() => nav.push('add-event')} style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '7px 12px', borderRadius: 999, border: '1.5px solid var(--pine)', background: 'transparent', color: 'var(--pine)', fontWeight: 700, fontSize: 12, cursor: 'pointer' }}><Plus size={14} /> นัดหมาย</button>
        </div>
        <AgendaList entries={entries} hub={hub} emptyText="ไม่มีกำหนดการในวันนี้" />
      </section>
    </>
  );
}

export function ChecklistCard({ plan, hub }) {
  const items = checklistFor(plan);
  const today = todayISO();
  const done = items.filter((it) => hub.checked.includes(it.key)).length;
  return (
    <div style={{ border: '1px solid var(--border)', borderRadius: 18, background: 'var(--surface)', padding: 14 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
        <p style={{ fontSize: 13.5, fontWeight: 700 }}>เช็กลิสต์ทริป{plan.destination}</p>
        <span style={{ fontSize: 11.5, color: 'var(--ink-soft)' }}>{done}/{items.length} เสร็จแล้ว</span>
      </div>
      <div style={{ height: 5, borderRadius: 999, background: 'var(--pine-pale)', margin: '8px 0 6px' }}>
        <div style={{ height: '100%', width: `${(done / items.length) * 100}%`, borderRadius: 999, background: 'var(--pine)' }} />
      </div>
      {items.map((it) => {
        const isDone = hub.checked.includes(it.key);
        const overdue = !isDone && it.due < today;
        return (
          <button key={it.key} role="checkbox" aria-checked={isDone} onClick={() => hub.toggleCheck(it.key)}
            style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 10, padding: '9px 0', background: 'none', border: 'none', borderTop: '1px solid var(--border)', cursor: 'pointer', textAlign: 'left' }}>
            <span style={{ width: 20, height: 20, borderRadius: 6, border: '2px solid var(--pine)', background: isDone ? 'var(--pine)' : 'transparent', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>{isDone && <Check size={13} color="#fff" />}</span>
            <span style={{ flex: 1, minWidth: 0 }}>
              <span style={{ display: 'block', fontSize: 12.5, color: isDone ? 'var(--ink-soft)' : 'var(--ink)', textDecoration: isDone ? 'line-through' : 'none' }}>{it.label}</span>
              <span style={{ display: 'block', fontSize: 10.5, color: overdue ? 'var(--danger)' : 'var(--ink-soft)', fontWeight: overdue ? 700 : 400 }}>{overdue ? 'เลยกำหนด · ' : 'ภายใน '}{fmtDate(it.due)}</span>
            </span>
          </button>
        );
      })}
    </div>
  );
}

export function SecretaryView({ hub, plans, nav, showToast, remindersOn, onTestReminder }) {
  const today = todayISO();
  const hour = new Date().getHours();
  const greeting = hour < 12 ? 'สวัสดีตอนเช้า' : hour < 17 ? 'สวัสดีตอนบ่าย' : 'สวัสดีตอนเย็น';
  const d = fromISO(today);
  const todayEntries = agendaFor(today, plans, hub.events);
  const upcoming = plans.filter((p) => p.endDate >= today).sort((a, b) => a.startDate.localeCompare(b.startDate));
  const next = upcoming[0];
  let nextLine = 'ยังไม่มีทริปที่จองไว้ เริ่มวางแผนกับ AI ได้เลย';
  if (next) {
    const n = diffDays(today, next.startDate);
    nextLine = n > 0 ? `ทริป${next.destination} ออกเดินทางอีก ${n} วัน (${fmtDate(next.startDate, { dow: true })})` : `กำลังอยู่ในทริป${next.destination} วันที่ ${diffDays(next.startDate, today) + 1}/${next.days}`;
  }
  const tasks = plans.flatMap(checklistFor).filter((it) => !hub.checked.includes(it.key) && it.due <= addDaysISO(today, 3)).sort((a, b) => a.due.localeCompare(b.due));
  const conflicts = findConflicts(plans, hub.events);
  const week = [];
  for (let i = 0; i < 7; i += 1) {
    const iso = addDaysISO(today, i);
    const entries = agendaFor(iso, plans, hub.events).filter((e) => e.kind !== 'stop');
    if (entries.length) week.push({ iso, entries });
  }
  const copySummary = async (plan) => {
    try {
      await navigator.clipboard.writeText(summarizePlan(plan));
      showToast('คัดลอกสรุปทริปแล้ว พร้อมส่งให้ทีม');
    } catch {
      showToast('คัดลอกไม่สำเร็จ ลองอีกครั้ง');
    }
  };
  const nowMs = Date.now();
  const upcomingReminders = buildReminders(plans, hub.events, hub.checked, hub.prefs).filter((r) => r.fireAt > nowMs && !hub.firedRef.current.has(r.id)).slice(0, 5);
  const toggleBrowser = async () => {
    if (hub.prefs.browser) { hub.setBrowserPref(false); return; }
    if (typeof Notification === 'undefined') { showToast('เบราว์เซอร์นี้ไม่รองรับการแจ้งเตือน'); return; }
    try {
      const perm = Notification.permission === 'granted' ? 'granted' : await Notification.requestPermission();
      if (perm === 'granted') { hub.setBrowserPref(true); showToast('เปิดการแจ้งเตือนผ่านเบราว์เซอร์แล้ว'); } else showToast('ยังไม่ได้รับอนุญาตให้แจ้งเตือน ตรวจสอบการตั้งค่าเบราว์เซอร์');
    } catch { showToast('เปิดการแจ้งเตือนไม่สำเร็จ'); }
  };
  const exportIcs = () => {
    try {
      downloadText('sabai-travel.ics', buildICS(plans, hub.events, hub.prefs), 'text/calendar;charset=utf-8');
      showToast('ดาวน์โหลดไฟล์ปฏิทินแล้ว เปิดไฟล์เพื่อนำเข้า Google Calendar');
    } catch { showToast('สร้างไฟล์ปฏิทินไม่สำเร็จ'); }
  };
  const sectionHead = (Icon, text) => <p className="font-display" style={{ fontSize: 15, fontWeight: 600, marginBottom: 10, display: 'flex', alignItems: 'center', gap: 8 }}><Icon size={16} color="var(--pine)" /> {text}</p>;
  return (
    <>
      <div style={{ borderRadius: 20, padding: 18, background: 'linear-gradient(135deg,#10403D,#1C5C57)', color: '#fff' }}>
        <p style={{ fontSize: 12, opacity: 0.85 }}>{greeting} คุณหนาน</p>
        <p className="font-display" style={{ fontSize: 18, fontWeight: 600, marginTop: 2 }}>วัน{TH_DOW_FULL[d.getDay()]}ที่ {fmtDate(today)}</p>
        <p style={{ fontSize: 13, marginTop: 10, lineHeight: 1.6 }}>{nextLine}</p>
        <p style={{ fontSize: 12.5, marginTop: 6, opacity: 0.9 }}>
          วันนี้มี {todayEntries.filter((e) => e.kind !== 'stop').length} รายการสำคัญ · งานที่ต้องจัดการ {tasks.length} รายการ · ข้อควรระวัง {conflicts.length} เรื่อง
        </p>
        <div style={{ display: 'flex', gap: 8, marginTop: 14, flexWrap: 'wrap' }}>
          <button onClick={() => nav.push('add-event')} style={{ padding: '8px 14px', borderRadius: 999, border: 'none', background: '#fff', color: '#10403D', fontWeight: 700, fontSize: 12, cursor: 'pointer' }}>+ เพิ่มนัดหมาย</button>
          <button onClick={() => hub.openCalendar(today)} style={{ padding: '8px 14px', borderRadius: 999, border: '1.5px solid rgba(255,255,255,0.6)', background: 'transparent', color: '#fff', fontWeight: 700, fontSize: 12, cursor: 'pointer' }}>เปิดปฏิทิน</button>
        </div>
      </div>

      <section aria-label="ข้อควรระวัง">
        {sectionHead(AlertCircle, 'ข้อควรระวังเรื่องตาราง')}
        {conflicts.length === 0
          ? <p style={{ fontSize: 12.5, color: 'var(--ink-soft)' }}>ไม่พบนัดหมายหรือทริปที่ชนกัน</p>
          : <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>{conflicts.map((c) => (
            <div key={c.id} style={{ borderRadius: 14, background: 'var(--amber-soft)', padding: 12, display: 'flex', gap: 8 }}>
              <AlertCircle size={15} color="var(--amber-ink)" style={{ flexShrink: 0, marginTop: 2 }} />
              <p style={{ fontSize: 12.5, color: 'var(--amber-ink)', lineHeight: 1.55 }}>{c.text}</p>
            </div>
          ))}</div>}
      </section>

      <section aria-label="งานที่ต้องจัดการ">
        {sectionHead(AlarmClock, 'งานที่ต้องจัดการเร็วๆ นี้')}
        {tasks.length === 0
          ? <p style={{ fontSize: 12.5, color: 'var(--ink-soft)' }}>ไม่มีงานค้างหรืองานที่ครบกำหนดใน 3 วันนี้</p>
          : <div style={{ border: '1px solid var(--border)', borderRadius: 16, background: 'var(--surface)', padding: '0 14px' }}>
            {tasks.slice(0, 6).map((it, i) => {
              const overdue = it.due < today;
              return (
                <button key={it.key} role="checkbox" aria-checked={false} onClick={() => hub.toggleCheck(it.key)}
                  style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 10, padding: '11px 0', background: 'none', border: 'none', borderTop: i ? '1px solid var(--border)' : 'none', cursor: 'pointer', textAlign: 'left' }}>
                  <span style={{ width: 20, height: 20, borderRadius: 6, border: '2px solid var(--pine)', flexShrink: 0 }} />
                  <span style={{ flex: 1, minWidth: 0 }}>
                    <span style={{ display: 'block', fontSize: 12.5, color: 'var(--ink)' }}>{it.label}</span>
                    <span style={{ display: 'block', fontSize: 10.5, color: overdue ? 'var(--danger)' : 'var(--ink-soft)', fontWeight: overdue ? 700 : 400 }}>{overdue ? 'เลยกำหนด · ' : 'ภายใน '}{fmtDate(it.due)}</span>
                  </span>
                </button>
              );
            })}
          </div>}
      </section>

      <section aria-label="กำหนดการ 7 วันข้างหน้า">
        {sectionHead(CalendarDays, '7 วันข้างหน้า')}
        {week.length === 0
          ? <p style={{ fontSize: 12.5, color: 'var(--ink-soft)' }}>ยังไม่มีกำหนดการใน 7 วันนี้</p>
          : <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>{week.map(({ iso, entries }) => (
            <div key={iso}>
              <p style={{ fontSize: 12, fontWeight: 700, color: 'var(--pine)', marginBottom: 6 }}>{relativeDay(iso)}</p>
              <AgendaList entries={entries} hub={hub} emptyText="" />
            </div>
          ))}</div>}
      </section>

      <section aria-label="การแจ้งเตือนอัตโนมัติ">
        {sectionHead(BellRing, 'การแจ้งเตือนอัตโนมัติ')}
        {!remindersOn && <p role="alert" style={{ fontSize: 12, color: 'var(--amber-ink)', background: 'var(--amber-soft)', borderRadius: 12, padding: 10, marginBottom: 10, lineHeight: 1.55 }}>การแจ้งเตือนการเดินทางถูกปิดอยู่ในการตั้งค่า จึงยังไม่ส่งเตือนจนกว่าจะเปิดอีกครั้ง</p>}
        <div style={{ border: '1px solid var(--border)', borderRadius: 16, background: 'var(--surface)', padding: '0 14px' }}>
          {REMINDER_KINDS.map((k, i) => (
            <button key={k.id} role="switch" aria-checked={!!hub.prefs.kinds[k.id]} onClick={() => hub.toggleKind(k.id)}
              style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 10, padding: '12px 0', background: 'none', border: 'none', borderTop: i ? '1px solid var(--border)' : 'none', cursor: 'pointer', textAlign: 'left' }}>
              <span style={{ flex: 1, fontSize: 12.5, color: 'var(--ink)' }}>{k.label}</span>
              <span aria-hidden="true" style={{ width: 38, height: 22, borderRadius: 999, background: hub.prefs.kinds[k.id] ? 'var(--pine)' : 'var(--disabled)', position: 'relative', flexShrink: 0 }}>
                <span style={{ position: 'absolute', top: 2, left: hub.prefs.kinds[k.id] ? 18 : 2, width: 18, height: 18, borderRadius: 999, background: '#fff', transition: 'left .15s' }} />
              </span>
            </button>
          ))}
          {hub.prefs.kinds.event && (
            <div style={{ borderTop: '1px solid var(--border)', padding: '12px 0' }}>
              <p style={{ fontSize: 11.5, color: 'var(--ink-soft)', marginBottom: 8 }}>เตือนนัดหมายล่วงหน้า</p>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>{EVENT_LEADS.map((m) => <Chip key={m} label={`${m} นาที`} active={hub.prefs.eventLead === m} onClick={() => hub.setEventLead(m)} />)}</div>
            </div>
          )}
          <button role="switch" aria-checked={hub.prefs.browser} onClick={toggleBrowser}
            style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 10, padding: '12px 0', background: 'none', border: 'none', borderTop: '1px solid var(--border)', cursor: 'pointer', textAlign: 'left' }}>
            <span style={{ flex: 1 }}>
              <span style={{ display: 'block', fontSize: 12.5, color: 'var(--ink)' }}>แจ้งเตือนผ่านเบราว์เซอร์</span>
              <span style={{ display: 'block', fontSize: 10.5, color: 'var(--ink-soft)', marginTop: 2 }}>แสดงป๊อปอัปแม้ไม่ได้เปิดหน้านี้ (ขณะเปิดแอปค้างไว้)</span>
            </span>
            <span aria-hidden="true" style={{ width: 38, height: 22, borderRadius: 999, background: hub.prefs.browser ? 'var(--pine)' : 'var(--disabled)', position: 'relative', flexShrink: 0 }}>
              <span style={{ position: 'absolute', top: 2, left: hub.prefs.browser ? 18 : 2, width: 18, height: 18, borderRadius: 999, background: '#fff', transition: 'left .15s' }} />
            </span>
          </button>
        </div>
        <p style={{ fontSize: 12, fontWeight: 700, margin: '14px 0 8px' }}>เตือนที่กำลังจะมาถึง</p>
        {upcomingReminders.length === 0
          ? <p style={{ fontSize: 12.5, color: 'var(--ink-soft)' }}>ยังไม่มีการเตือนที่รออยู่ จองทริปหรือเพิ่มนัดหมายเพื่อให้เลขาเตือนให้</p>
          : <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>{upcomingReminders.map((r) => (
            <div key={r.id} style={{ display: 'flex', gap: 10, padding: 12, borderRadius: 14, border: '1px solid var(--border)', background: 'var(--surface)' }}>
              <BellRing size={15} color="var(--pine)" style={{ marginTop: 2, flexShrink: 0 }} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <p style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--ink)' }}>{r.title}</p>
                <p style={{ fontSize: 11, color: 'var(--ink-soft)', marginTop: 2, lineHeight: 1.5 }}>{r.body}</p>
              </div>
              <span style={{ fontSize: 10.5, fontWeight: 700, color: 'var(--pine)', whiteSpace: 'nowrap' }}>{fmtUntil(r.fireAt, nowMs)}</span>
            </div>
          ))}</div>}
        <div style={{ marginTop: 12 }}><SecondaryButton onClick={() => onTestReminder(upcomingReminders[0] || { id: 'rem:test', title: 'ทดสอบการแจ้งเตือน', body: 'เลขาส่วนตัวพร้อมเตือนคุณก่อนถึงเวลาสำคัญ' })}>ส่งการแจ้งเตือนทดสอบ</SecondaryButton></div>
      </section>

      <section aria-label="ซิงก์กับ Google Calendar">
        {sectionHead(CalendarPlus, 'ซิงก์กับ Google Calendar')}
        <p style={{ fontSize: 12, color: 'var(--ink-soft)', lineHeight: 1.6, marginBottom: 10 }}>เพิ่มทริป เที่ยวบิน และนัดหมายลง Google Calendar ทีละรายการ หรือดาวน์โหลดไฟล์ .ics ครั้งเดียวเพื่อนำเข้าได้ทั้ง Google, Apple และ Outlook พร้อมการเตือนที่ตั้งไว้</p>
        <PrimaryButton onClick={exportIcs}>ดาวน์โหลดไฟล์ปฏิทิน (.ics)</PrimaryButton>
        {plans.length > 0 && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 12 }}>
            {plans.map((p) => (
              <div key={p.id} style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                <MapLink href={gcalUrl({ title: `ทริป${p.destination} ${p.days} วัน`, date: p.startDate, endDate: p.endDate, details: summarizePlan(p), location: p.destination })} icon={CalendarPlus} label={`ทริป${p.destination} ทั้งทริป`} ariaLabel={`เพิ่มทริป${p.destination} ทั้งทริปลง Google Calendar`} />
                {[p.outbound, p.ret].filter(Boolean).map((f) => <MapLink key={f.id} href={gcalUrl(flightGcal(f))} icon={Plane} label={`${f.number} ${fmtDate(f.date)}`} ariaLabel={`เพิ่มเที่ยวบิน ${f.number} ลง Google Calendar`} />)}
              </div>
            ))}
          </div>
        )}
        <p style={{ fontSize: 11, color: 'var(--ink-soft)', marginTop: 12, lineHeight: 1.6 }}>การซิงก์สองทางอัตโนมัติ (อ่านและเขียนปฏิทินของคุณเอง) ต้องเชื่อมบัญชี Google ผ่าน OAuth และเซิร์ฟเวอร์ ซึ่งยังไม่รวมในพรอโทไทป์นี้ และเมื่อลบหรือยกเลิกทริปแล้ว รายการที่เพิ่มลง Google Calendar ไปก่อนหน้าต้องลบเอง</p>
      </section>

      {plans.length > 0 && (
        <section aria-label="เช็กลิสต์และสรุปทริป">
          {sectionHead(ClipboardList, 'เช็กลิสต์และสรุปทริป')}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {plans.map((p) => (
              <div key={p.id} style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                <ChecklistCard plan={p} hub={hub} />
                <SecondaryButton onClick={() => copySummary(p)}>คัดลอกสรุปทริป{p.destination}ส่งให้ทีม</SecondaryButton>
              </div>
            ))}
          </div>
        </section>
      )}
    </>
  );
}

export function TripsHub({ hub, plans, savedTrips, nav, onStartAi, onSelectTrip, onOpenPlan, showToast, remindersOn, onTestReminder }) {
  const tabs = [{ id: 'plans', label: 'ทริป' }, { id: 'calendar', label: 'ปฏิทิน' }, { id: 'secretary', label: 'เลขา' }];
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <div style={{ padding: '14px 20px 0', flexShrink: 0 }}>
        <h1 className="font-display" style={{ fontSize: 20, fontWeight: 600, color: 'var(--ink)' }}>ทริปของฉัน</h1>
      </div>
      <div role="tablist" aria-label="หมวดทริป" style={{ display: 'flex', borderBottom: '1px solid var(--border)', margin: '12px 20px 0', flexShrink: 0 }}>
        {tabs.map((t) => (
          <button key={t.id} role="tab" aria-selected={hub.tab === t.id} onClick={() => hub.setTab(t.id)}
            style={{ flex: 1, padding: '10px 0', background: 'none', border: 'none', borderBottom: hub.tab === t.id ? '2.5px solid var(--pine)' : '2.5px solid transparent', color: hub.tab === t.id ? 'var(--pine)' : 'var(--ink-soft)', fontWeight: hub.tab === t.id ? 700 : 500, fontSize: 13.5, cursor: 'pointer', marginBottom: -1 }}>{t.label}</button>
        ))}
      </div>
      {hub.tab === 'plans' ? (
        <div style={{ flex: 1, minHeight: 0 }}>
          <TripsScreen hideTitle plans={plans} onOpenPlan={onOpenPlan} savedTrips={savedTrips} onStartAi={onStartAi} onSelectTrip={onSelectTrip} />
        </div>
      ) : (
        <div className="scrollbar-hide" role="tabpanel" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '14px 20px 20px', display: 'flex', flexDirection: 'column', gap: 16 }}>
          {hub.tab === 'calendar' && <CalendarView hub={hub} plans={plans} nav={nav} />}
          {hub.tab === 'secretary' && <SecretaryView hub={hub} plans={plans} nav={nav} showToast={showToast} remindersOn={remindersOn} onTestReminder={onTestReminder} />}
        </div>
      )}
    </div>
  );
}

export function AddEventScreen({ hub, plans, nav }) {
  const today = todayISO();
  const [title, setTitle] = useState('');
  const [date, setDate] = useState(hub.selected >= today ? hub.selected : today);
  const [time, setTime] = useState('09:00');
  const [place, setPlace] = useState('');
  const [kind, setKind] = useState('meeting');
  const valid = title.trim().length > 0 && /^\d{4}-\d{2}-\d{2}$/.test(date) && date >= today;
  const draft = { id: 'draft', title: title.trim() || 'นัดหมายใหม่', date, time, place, kind };
  const warnings = /^\d{4}-\d{2}-\d{2}$/.test(date) ? findConflicts(plans, [draft]).filter((c) => c.eventId === 'draft') : [];
  const save = () => {
    if (!valid) return;
    hub.addEvent({ title: title.trim(), date, time, place: place.trim(), kind });
    hub.selectDate(date);
    hub.setTab('calendar');
    nav.pop();
  };
  const field = { width: '100%', border: '1.5px solid var(--border)', borderRadius: 14, padding: '12px 14px', fontSize: 14, fontFamily: "'Plus Jakarta Sans', sans-serif", background: 'var(--surface)', color: 'var(--ink)', outline: 'none' };
  const label = { display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 8 };
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="เพิ่มนัดหมาย" onBack={nav.pop} />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 18 }}>
        <div>
          <p style={label}>ประเภท</p>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>{Object.entries(EVENT_KINDS).map(([id, k]) => <Chip key={id} label={k.label} active={kind === id} onClick={() => setKind(id)} />)}</div>
        </div>
        <div><label htmlFor="ev-title" style={label}>ชื่อนัดหมาย</label><input id="ev-title" value={title} maxLength={80} onChange={(e) => setTitle(e.target.value)} placeholder="เช่น ประชุมทีมขาย" style={field} /></div>
        <div style={{ display: 'flex', gap: 12 }}>
          <div style={{ flex: 1.3 }}><label htmlFor="ev-date" style={label}>วันที่</label><input id="ev-date" type="date" min={today} value={date} onChange={(e) => setDate(e.target.value)} style={field} /></div>
          <div style={{ flex: 1 }}><label htmlFor="ev-time" style={label}>เวลา</label><input id="ev-time" type="time" value={time} onChange={(e) => setTime(e.target.value)} style={field} /></div>
        </div>
        <div><label htmlFor="ev-place" style={label}>สถานที่ (ไม่บังคับ)</label><input id="ev-place" value={place} maxLength={80} onChange={(e) => setPlace(e.target.value)} placeholder="เช่น ห้องประชุมชั้น 12" style={field} /></div>
        {warnings.length > 0 && (
          <div role="alert" style={{ borderRadius: 14, background: 'var(--amber-soft)', padding: 12, display: 'flex', flexDirection: 'column', gap: 6 }}>
            {warnings.map((w) => <p key={w.id} style={{ fontSize: 12, color: 'var(--amber-ink)', lineHeight: 1.55, display: 'flex', gap: 6 }}><AlertCircle size={14} style={{ flexShrink: 0, marginTop: 2 }} /> {w.text}</p>)}
          </div>
        )}
      </div>
      <div style={{ padding: '14px 20px', borderTop: '1px solid var(--border)', flexShrink: 0 }}>
        <PrimaryButton onClick={save} disabled={!valid}>บันทึกนัดหมาย</PrimaryButton>
      </div>
    </div>
  );
}
