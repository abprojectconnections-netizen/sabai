import { Briefcase, ChevronRight, MapPin, Plane } from 'lucide-react';
import { PrimaryButton, TopBar } from '../../components/ui';
import { diffDays, fmtRange, todayISO } from '../../domain/dates';
import { TripItinerary } from '../maps/MapComponents';

export function TripsScreen({ savedTrips, onStartAi, onSelectTrip, plans = [], onOpenPlan, hideTitle = false }) {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 16 }}>
        {!hideTitle && <h1 className="font-display" style={{ fontSize: 20, fontWeight: 600 }}>ทริปของฉัน</h1>}
        {plans.length > 0 && (
          <section aria-label="ทริปที่จองแล้ว">
            <p className="font-display" style={{ fontSize: 15, fontWeight: 600, marginBottom: 10 }}>ทริปที่จองแล้ว</p>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {plans.map((pl) => <PlanCard key={pl.id} plan={pl} onOpen={() => onOpenPlan(pl)} />)}
            </div>
          </section>
        )}
        {plans.length > 0 && savedTrips.length > 0 && <p className="font-display" style={{ fontSize: 15, fontWeight: 600, marginBottom: -6 }}>แผนที่บันทึกไว้</p>}
        {savedTrips.length === 0 && plans.length > 0 ? null : savedTrips.length === 0 ? (
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 14, textAlign: 'center', padding: 20 }}>
            <div style={{ width: 64, height: 64, borderRadius: 999, background: 'var(--pine-pale)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Briefcase size={26} color="var(--pine)" />
            </div>
            <p style={{ fontSize: 14, fontWeight: 700, color: 'var(--ink)' }}>คุณยังไม่มีทริปที่บันทึกไว้</p>
            <p style={{ fontSize: 12, color: 'var(--ink-soft)', maxWidth: 220 }}>เริ่มวางแผนทริปแรกของคุณด้วย AI ได้เลยตอนนี้</p>
            <div style={{ width: 180 }}><PrimaryButton onClick={onStartAi}>เริ่มวางแผน</PrimaryButton></div>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {savedTrips.map((t) => (
              <button key={t.id} onClick={() => onSelectTrip(t)} style={{ textAlign: 'left', border: '1px solid var(--border)', borderRadius: 18, padding: 16, display: 'flex', gap: 14, alignItems: 'center', background: 'var(--surface)', cursor: 'pointer' }}>
                <div style={{ width: 52, height: 52, borderRadius: 14, background: 'linear-gradient(135deg,#1C5C57,#89A66B)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  <MapPin size={22} color="#fff" />
                </div>
                <div style={{ flex: 1 }}>
                  <p style={{ fontSize: 14, fontWeight: 700 }}>{t.destination}</p>
                  <p style={{ fontSize: 11.5, color: 'var(--ink-soft)' }}>{t.days} วัน · งบ ฿{t.budget.toLocaleString()}</p>
                </div>
                <ChevronRight size={18} color="var(--ink-soft)" />
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

export function TripDetailScreen({ trip, onBack }) {
  if (!trip) return null;
  const total = trip.itinerary.budgetBreakdown.reduce((s, b) => s + b.value, 0);
  const maxVal = Math.max(...trip.itinerary.budgetBreakdown.map((b) => b.value));
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="รายละเอียดทริป" onBack={onBack} />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto' }}>
        <div style={{ height: 130, background: 'linear-gradient(135deg,#1C5C57,#89A66B)', display: 'flex', flexDirection: 'column', justifyContent: 'flex-end', padding: 18 }}>
          <p className="font-display" style={{ color: '#fff', fontSize: 22, fontWeight: 600 }}>{trip.destination}</p>
          <p style={{ color: 'rgba(255,255,255,0.85)', fontSize: 12 }}>{trip.days} วัน · {trip.travelers} ผู้เดินทาง</p>
        </div>
        <div style={{ padding: '18px 20px', display: 'flex', flexDirection: 'column', gap: 20 }}>
          <TripItinerary itinerary={trip.itinerary} destination={trip.destination} />

          <div>
            <p className="font-display" style={{ fontSize: 15, fontWeight: 600, marginBottom: 10 }}>ประมาณการค่าใช้จ่าย</p>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 10 }}>
              {trip.itinerary.budgetBreakdown.map((b, i) => (
                <div key={i}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, marginBottom: 4 }}>
                    <span style={{ color: 'var(--ink)' }}>{b.label}</span>
                    <span style={{ fontWeight: 700, color: 'var(--ink)' }}>฿{b.value.toLocaleString()}</span>
                  </div>
                  <div style={{ height: 6, borderRadius: 999, background: 'var(--pine-pale)' }}>
                    <div style={{ height: '100%', width: `${(b.value / maxVal) * 100}%`, borderRadius: 999, background: 'var(--amber)' }} />
                  </div>
                </div>
              ))}
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', paddingTop: 10, borderTop: '1px dashed var(--border)' }}>
              <span style={{ fontSize: 13.5, fontWeight: 700 }}>รวมทั้งหมด</span>
              <span className="font-display" style={{ fontSize: 17, fontWeight: 700, color: 'var(--pine)' }}>฿{total.toLocaleString()}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export function PlanCard({ plan, onOpen }) {
  const today = todayISO();
  const n = diffDays(today, plan.startDate);
  const status = plan.endDate < today ? 'เสร็จสิ้นแล้ว' : n > 0 ? `อีก ${n} วัน` : 'กำลังเดินทาง';
  return (
    <button onClick={onOpen} aria-label={`ทริป${plan.destination} ${fmtRange(plan.startDate, plan.endDate)}`}
      style={{ textAlign: 'left', border: '1px solid var(--border)', borderRadius: 18, padding: 14, display: 'flex', gap: 12, alignItems: 'center', background: 'var(--surface)', cursor: 'pointer', width: '100%' }}>
      <div style={{ width: 50, height: 50, borderRadius: 14, background: 'linear-gradient(135deg,#10403D,#1C5C57)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Plane size={22} color="#fff" /></div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <p style={{ fontSize: 14, fontWeight: 700, color: 'var(--ink)' }}>{plan.destination} · {plan.days} วัน</p>
        <p style={{ fontSize: 11.5, color: 'var(--ink-soft)', marginTop: 2 }}>{fmtRange(plan.startDate, plan.endDate)} · {plan.travelers} ผู้เดินทาง</p>
        <p style={{ fontSize: 11, color: 'var(--ink-soft)', marginTop: 2, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{plan.outbound ? `${plan.outbound.number} ${plan.outbound.dep} · ${plan.ret.number} ${plan.ret.dep}` : 'ไม่ได้จองเที่ยวบินกับ Sabai'}</p>
      </div>
      <span style={{ fontSize: 10.5, fontWeight: 700, padding: '4px 10px', borderRadius: 999, background: 'var(--pine-pale)', color: 'var(--pine)', flexShrink: 0 }}>{status}</span>
    </button>
  );
}
