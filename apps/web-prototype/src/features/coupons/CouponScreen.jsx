import { useState } from 'react';
import { Check, Copy, Ticket } from 'lucide-react';
import { Chip, TextField, TopBar } from '../../components/ui';

export function CouponCard({ coupon, onCopy, copiedId }) {
  const statusMeta = {
    available: { label: 'ใช้ได้', bg: 'var(--pine-pale)', color: 'var(--pine)' },
    used: { label: 'ใช้แล้ว', bg: 'var(--muted-bg)', color: 'var(--ink-soft)' },
    expired: { label: 'หมดอายุ', bg: 'var(--danger-soft)', color: 'var(--danger)' },
  }[coupon.status];
  const isActive = coupon.status === 'available';
  return (
    <div style={{ display: 'flex', borderRadius: 18, border: '1px solid var(--border)', overflow: 'hidden', opacity: isActive ? 1 : 0.6 }}>
      <div style={{ width: 10, background: isActive ? 'var(--amber)' : 'var(--border)', flexShrink: 0 }} />
      <div style={{ flex: 1, padding: 16 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 6 }}>
          <p className="font-display" style={{ fontSize: 15, fontWeight: 600, color: 'var(--ink)' }}>{coupon.title}</p>
          <span style={{ fontSize: 10.5, fontWeight: 700, padding: '4px 10px', borderRadius: 999, background: statusMeta.bg, color: statusMeta.color, flexShrink: 0 }}>{statusMeta.label}</span>
        </div>
        <p style={{ fontSize: 12, color: 'var(--ink-soft)', lineHeight: 1.5, marginBottom: 10 }}>{coupon.detail}</p>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ fontFamily: 'monospace', fontSize: 13, fontWeight: 700, letterSpacing: 0.5, color: 'var(--ink)', background: 'var(--paper)', padding: '4px 10px', borderRadius: 8, border: '1px dashed var(--border)' }}>{coupon.code}</span>
            {isActive && (
              <button onClick={() => onCopy(coupon)} style={{ background: 'none', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 3, color: 'var(--pine)', fontSize: 11, fontWeight: 700 }}>
                {copiedId === coupon.id ? <Check size={13} /> : <Copy size={13} />}
                {copiedId === coupon.id ? 'คัดลอกแล้ว' : 'คัดลอก'}
              </button>
            )}
          </div>
          <span style={{ fontSize: 10.5, color: 'var(--ink-soft)' }}>หมดอายุ {coupon.expiry}</span>
        </div>
      </div>
    </div>
  );
}

export function CouponScreen({ coupons, onBack, onApply }) {
  const [tab, setTab] = useState('available');
  const [copiedId, setCopiedId] = useState(null);
  const [applyCode, setApplyCode] = useState('');
  const [applyMsg, setApplyMsg] = useState(null);
  const tabs = [
    { id: 'available', label: 'ใช้ได้' },
    { id: 'used', label: 'ใช้แล้ว' },
    { id: 'expired', label: 'หมดอายุ' },
  ];
  const filtered = coupons.filter((c) => c.status === tab);
  const handleCopy = (coupon) => {
    setCopiedId(coupon.id);
    setTimeout(() => setCopiedId(null), 1500);
  };
  const handleApply = () => {
    const code = applyCode.trim().toUpperCase();
    if (!code) return;
    const found = coupons.find((c) => c.code === code);
    if (!found) {
      setApplyMsg({ ok: false, text: 'ไม่พบรหัสคูปองนี้' });
    } else if (found.status === 'used') {
      setApplyMsg({ ok: false, text: 'คุณใช้คูปองนี้ไปแล้ว' });
    } else if (found.status === 'expired') {
      setApplyMsg({ ok: false, text: 'คูปองนี้หมดอายุแล้ว' });
    } else {
      onApply(found);
      setApplyMsg({ ok: true, text: `เพิ่มคูปอง "${found.title}" เรียบร้อยแล้ว` });
      setApplyCode('');
      setTab('available');
    }
    setTimeout(() => setApplyMsg(null), 2500);
  };
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="คูปองของฉัน" onBack={onBack} />
      <div style={{ padding: '14px 20px 0', flexShrink: 0, display: 'flex', flexDirection: 'column', gap: 12 }}>
        <div style={{ display: 'flex', gap: 8 }}>
          <div style={{ flex: 1 }}><TextField icon={Ticket} placeholder="กรอกรหัสคูปองที่นี่" value={applyCode} onChange={(e) => setApplyCode(e.target.value)} /></div>
          <button onClick={handleApply} style={{ padding: '0 18px', borderRadius: 14, border: 'none', background: 'var(--pine)', color: '#fff', fontWeight: 700, fontSize: 13, cursor: 'pointer' }}>เพิ่ม</button>
        </div>
        {applyMsg && (
          <p style={{ fontSize: 12, fontWeight: 600, color: applyMsg.ok ? 'var(--pine)' : 'var(--danger)' }}>{applyMsg.text}</p>
        )}
        <div style={{ display: 'flex', gap: 8 }}>
          {tabs.map((t) => <Chip key={t.id} label={t.label} active={tab === t.id} onClick={() => setTab(t.id)} />)}
        </div>
      </div>
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '16px 20px 20px', display: 'flex', flexDirection: 'column', gap: 12 }}>
        {filtered.length === 0 && <p style={{ textAlign: 'center', color: 'var(--ink-soft)', fontSize: 13, marginTop: 40 }}>ไม่มีคูปองในหมวดนี้</p>}
        {filtered.map((c) => <CouponCard key={c.id} coupon={c} onCopy={handleCopy} copiedId={copiedId} />)}
      </div>
    </div>
  );
}
