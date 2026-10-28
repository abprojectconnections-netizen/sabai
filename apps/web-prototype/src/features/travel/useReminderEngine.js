import { useRef, useEffect } from 'react';
import { buildReminders, selectDueReminders } from '../../domain/reminders';

export function useReminderEngine({ hub, plans, enabled, onFire }) {
  const latest = useRef({});
  latest.current = { hub, plans, enabled, onFire };
  const tick = () => {
    const { hub: h, plans: pl, enabled: on, onFire: fire } = latest.current;
    if (!on) return;
    const now = Date.now();
    const due = selectDueReminders(buildReminders(pl, h.events, h.checked, h.prefs), h.firedRef.current, now);
    if (!due.length) return;
    h.markFired(due.map((r) => r.id));
    due.forEach(fire);
  };
  useEffect(() => { const id = setInterval(tick, 30000); return () => clearInterval(id); }, []);
  const signature = `${enabled}|${plans.map((p) => p.id).join(',')}|${hub.events.length}|${hub.checked.length}|${JSON.stringify(hub.prefs)}`;
  useEffect(() => { tick(); }, [signature]);
}
