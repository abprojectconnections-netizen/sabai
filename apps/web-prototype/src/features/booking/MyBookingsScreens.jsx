import { useState } from 'react';
import { Sparkles } from 'lucide-react';
import { Chip, PrimaryButton, SecondaryButton, TopBar } from '../../components/ui';
import { BOOKING_STATUS, CANCEL_REASONS, refundFor } from '../../domain/bookings';
import { fmtRange } from '../../domain/dates';
import { flightSummary } from '../../domain/flights';
import { TYPE_GRADIENT, TYPE_ICON } from '../../ui/typeMeta';

export function StatusPill({ status }) {
  const m = BOOKING_STATUS[status];
  return <span style={{ fontSize: 10.5, fontWeight: 700, padding: '4px 10px', borderRadius: 999, background: m.bg, color: m.color, flexShrink: 0 }}>{m.label}</span>;
}

export function BookingsScreen({ bookings, onBack, onSelect, onStartSearch }) {
  const [tab, setTab] = useState('all');
  const tabs = [
    { id: 'all', label: 'ทั้งหมด' },
    { id: 'confirmed', label: 'ที่จะถึง' },
    { id: 'completed', label: 'เสร็จสิ้น' },
    { id: 'cancelled', label: 'ยกเลิก' },
  ];
  const list = bookings.filter((b) => tab === 'all' || b.status === tab);
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="การจองของฉัน" onBack={onBack} />
      <div className="scrollbar-hide" style={{ padding: '14px 20px 0', display: 'flex', gap: 8, overflowX: 'auto', flexShrink: 0 }}>
        {tabs.map((t) => <Chip key={t.id} label={t.label} active={tab === t.id} onClick={() => setTab(t.id)} />)}
      </div>
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '16px 20px 20px', display: 'flex', flexDirection: 'column', gap: 12 }}>
        {list.length === 0 && (
          <div style={{ textAlign: 'center', marginTop: 48, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
            <p style={{ fontSize: 13, color: 'var(--ink-soft)' }}>ยังไม่มีการจองในหมวดนี้</p>
            {tab === 'all' && <div style={{ width: 160 }}><PrimaryButton onClick={onStartSearch}>ค้นหาและจอง</PrimaryButton></div>}
          </div>
        )}
        {list.map((b) => {
          const Icon = TYPE_ICON[b.type] || Sparkles;
          return (
            <button key={b.id} onClick={() => onSelect(b.id)} style={{ display: 'flex', gap: 14, textAlign: 'left', border: '1px solid var(--border)', borderRadius: 18, padding: 14, background: 'var(--surface)', cursor: 'pointer' }}>
              <div style={{ width: 48, height: 48, borderRadius: 14, background: TYPE_GRADIENT[b.type] || TYPE_GRADIENT.trip, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <Icon size={20} color="#fff" />
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, alignItems: 'flex-start' }}>
                  <p style={{ fontSize: 13.5, fontWeight: 700, color: 'var(--ink)' }}>{b.title}</p>
                  <StatusPill status={b.status} />
                </div>
                <p style={{ fontSize: 11.5, color: 'var(--ink-soft)', margin: '3px 0 8px' }}>{b.subtitle}</p>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: 11, color: 'var(--ink-soft)' }}>{b.number} · {b.date}</span>
                  <span style={{ fontSize: 13, fontWeight: 700, color: 'var(--pine)' }}>฿{b.amount.toLocaleString()}</span>
                </div>
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}

export function BookingDetailScreen({ booking, onBack, onCancel, onReview }) {
  if (!booking) return null;
  const Icon = TYPE_ICON[booking.type] || Sparkles;
  const cancelled = booking.status === 'cancelled';
  const steps = [
    { label: 'สร้างการจอง', done: true },
    { label: 'ชำระเงินแล้ว', done: true },
    { label: 'ยืนยันการจอง', done: true },
    cancelled
      ? { label: 'ยกเลิกการจอง', done: true, danger: true }
      : { label: 'เสร็จสิ้น', done: booking.status === 'completed' },
  ];
  const rows = [
    ['หมายเลขการจอง', booking.number],
    ['วันที่จอง', booking.date],
    ...(booking.method ? [['วิธีชำระเงิน', booking.method]] : []),
    ['ยอดชำระ', `฿${booking.amount.toLocaleString()}`],
  ];
  if (booking.plan) {
    const pl = booking.plan;
    rows.splice(1, 0, ['วันเดินทาง', fmtRange(pl.startDate, pl.endDate)], ['ผู้เดินทาง', `${pl.travelers} คน`]);
    if (pl.outbound) rows.splice(3, 0, ['เที่ยวบินขาไป', flightSummary(pl.outbound)], ['เที่ยวบินขากลับ', flightSummary(pl.ret)]);
    else rows.splice(3, 0, ['เที่ยวบิน', 'ผู้ใช้มีตั๋วแล้ว']);
  }
  if (cancelled) {
    rows.push(['เหตุผลที่ยกเลิก', booking.cancelReason || '-'], ['เงินคืน', `฿${(booking.refund || 0).toLocaleString()} (เข้า Sabai Wallet)`]);
  }
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="รายละเอียดการจอง" onBack={onBack} />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 20 }}>
        <div style={{ display: 'flex', gap: 14, alignItems: 'center' }}>
          <div style={{ width: 56, height: 56, borderRadius: 16, background: TYPE_GRADIENT[booking.type] || TYPE_GRADIENT.trip, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Icon size={24} color="#fff" />
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <p className="font-display" style={{ fontSize: 17, fontWeight: 600 }}>{booking.title}</p>
            <p style={{ fontSize: 12, color: 'var(--ink-soft)', marginTop: 2 }}>{booking.subtitle}</p>
          </div>
          <StatusPill status={booking.status} />
        </div>

        <div style={{ border: '1px solid var(--border)', borderRadius: 18, overflow: 'hidden' }}>
          {rows.map(([k, v], i) => (
            <div key={k} style={{ display: 'flex', justifyContent: 'space-between', gap: 12, padding: '12px 16px', borderBottom: i < rows.length - 1 ? '1px solid var(--border)' : 'none', fontSize: 12.5 }}>
              <span style={{ color: 'var(--ink-soft)' }}>{k}</span>
              <span style={{ fontWeight: 600, color: 'var(--ink)', textAlign: 'right' }}>{v}</span>
            </div>
          ))}
        </div>

        <div>
          <p className="font-display" style={{ fontSize: 15, fontWeight: 600, marginBottom: 12 }}>ความคืบหน้า</p>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            {steps.map((s, i) => (
              <div key={i} style={{ display: 'flex', gap: 12 }}>
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                  <div style={{ width: 10, height: 10, borderRadius: 999, marginTop: 4, background: s.done ? (s.danger ? 'var(--danger)' : 'var(--pine)') : 'var(--border)' }} />
                  {i < steps.length - 1 && <div style={{ width: 1.5, flex: 1, background: 'var(--border)', minHeight: 22 }} />}
                </div>
                <p style={{ fontSize: 12.5, paddingBottom: 14, fontWeight: s.done ? 600 : 400, color: s.done ? 'var(--ink)' : 'var(--ink-soft)' }}>{s.label}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
      {(booking.status === 'confirmed' || (booking.status === 'completed' && onReview)) && (
        <div style={{ padding: '14px 20px', borderTop: '1px solid var(--border)', flexShrink: 0 }}>
          {booking.status === 'confirmed'
            ? <SecondaryButton onClick={onCancel}>ยกเลิกการจอง</SecondaryButton>
            : <PrimaryButton onClick={onReview}>เขียนรีวิว</PrimaryButton>}
        </div>
      )}
    </div>
  );
}

export function CancelBookingScreen({ booking, reason, setReason, onBack, onConfirm }) {
  if (!booking) return null;
  const refund = refundFor(booking);
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="ยกเลิกการจอง" onBack={onBack} />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 20 }}>
        <div style={{ border: '1px solid var(--border)', borderRadius: 16, padding: 14 }}>
          <p style={{ fontSize: 13.5, fontWeight: 700 }}>{booking.title}</p>
          <p style={{ fontSize: 11.5, color: 'var(--ink-soft)', marginTop: 2 }}>{booking.number}</p>
        </div>
        <div>
          <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 10 }}>เหตุผลที่ยกเลิก</p>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            {CANCEL_REASONS.map((r) => <Chip key={r} label={r} active={reason === r} onClick={() => setReason(r)} />)}
          </div>
        </div>
        <div style={{ borderRadius: 16, background: 'var(--pine-pale)', padding: 16 }}>
          <p style={{ fontSize: 12, color: 'var(--ink-soft)' }}>ประมาณการเงินคืน (ยอดจริงคำนวณโดยระบบ)</p>
          <p className="font-display" style={{ fontSize: 24, fontWeight: 700, color: 'var(--pine)', margin: '4px 0' }}>฿{refund.toLocaleString()}</p>
          <p style={{ fontSize: 11.5, color: 'var(--ink-soft)', lineHeight: 1.5 }}>ยอดเงินคืนจริงคำนวณตามเงื่อนไขของการจองและอาจต้องรอการอนุมัติ เงินจะคืนไปยังช่องทางที่ชำระเงิน เว้นแต่คุณเลือกรับเป็นเครดิต Sabai Wallet ด้วยความยินยอมของคุณเอง</p>
        </div>
      </div>
      <div style={{ padding: '14px 20px', borderTop: '1px solid var(--border)', flexShrink: 0 }}>
        <PrimaryButton onClick={onConfirm} disabled={!reason}>ส่งคำขอยกเลิกและขอคืนเงิน</PrimaryButton>
      </div>
    </div>
  );
}
