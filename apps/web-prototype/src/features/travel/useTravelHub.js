import { useState, useRef } from 'react';
import { addMonthsISO, monthStartISO, todayISO } from '../../domain/dates';
import { defaultReminderPrefs } from '../../domain/reminders';
import { emptySetup } from '../../domain/tripPlan';

export function useTravelHub({ showToast, initialEvents = [] }) {
  const [tab, setTab] = useState('plans');
  const [month, setMonth] = useState(monthStartISO(todayISO()));
  const [selected, setSelected] = useState(todayISO());
  const [events, setEvents] = useState(() => initialEvents);
  const [checked, setChecked] = useState([]);
  const [setup, setSetup] = useState(emptySetup);
  const [prefs, setPrefs] = useState(defaultReminderPrefs);
  const [fired, setFired] = useState([]);
  const firedRef = useRef(new Set());

  const patchSetup = (patch) => setSetup((prev) => ({ ...prev, ...patch }));
  return {
    tab, month, selected, events, checked, setup, prefs, fired, firedRef,
    toggleKind: (id) => setPrefs((p) => ({ ...p, kinds: { ...p.kinds, [id]: !p.kinds[id] } })),
    setEventLead: (m) => setPrefs((p) => ({ ...p, eventLead: m })),
    setBrowserPref: (v) => setPrefs((p) => ({ ...p, browser: v })),
    markFired: (ids) => { ids.forEach((id) => firedRef.current.add(id)); setFired([...firedRef.current]); },
    setTab,
    shiftMonth: (n) => setMonth((m) => addMonthsISO(m, n)),
    selectDate: (iso) => { setSelected(iso); setMonth(monthStartISO(iso)); },
    openCalendar: (iso) => { setTab('calendar'); setSelected(iso); setMonth(monthStartISO(iso)); },
    toggleCheck: (key) => setChecked((prev) => (prev.includes(key) ? prev.filter((k) => k !== key) : [...prev, key])),
    addEvent: (ev) => {
      setEvents((prev) => [...prev, { ...ev, id: `ev${Date.now()}` }]);
      showToast('เพิ่มนัดหมายลงปฏิทินแล้ว');
    },
    removeEvent: (id) => { setEvents((prev) => prev.filter((e) => e.id !== id)); showToast('ลบนัดหมายแล้ว'); },
    resetSetup: () => setSetup(emptySetup()),
    patchSetup,
    shiftSetupMonth: (n) => setSetup((prev) => ({ ...prev, month: addMonthsISO(prev.month, n) })),
    chooseStart: (iso) => patchSetup({ startDate: iso, outbound: null, ret: null, leg: 'out' }),
    toggleAirline: (code) => setSetup((prev) => ({ ...prev, airlines: prev.airlines.includes(code) ? prev.airlines.filter((c) => c !== code) : [...prev.airlines, code] })),
  };
}
