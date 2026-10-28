import { Calendar, CheckCircle2, CreditCard, Lock, QrCode, Ticket, Wallet } from 'lucide-react';
import { PrimaryButton, SecondaryButton, TextField, TopBar } from '../../components/ui';
import { TYPE_LABEL } from '../../ui/typeMeta';

export function BookingScreen({ item, onBack, onPay }) {
  if (!item) return null;
  const fee = Math.round(item.price * 0.05);
  const total = item.price + fee;
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="สรุปการจอง" onBack={onBack} />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 18 }}>
        <div style={{ border: '1px solid var(--border)', borderRadius: 18, padding: 16 }}>
          <p style={{ fontSize: 11, fontWeight: 700, color: 'var(--ink-soft)', marginBottom: 6 }}>{TYPE_LABEL[item.type] || 'รายการ'}</p>
          <p className="font-display" style={{ fontSize: 16, fontWeight: 600 }}>{item.title}</p>
          <p style={{ fontSize: 12, color: 'var(--ink-soft)', marginTop: 2 }}>{item.subtitle}</p>
        </div>
        <div>
          <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 10 }}>รหัสส่วนลด</p>
          <div style={{ display: 'flex', gap: 8 }}>
            <div style={{ flex: 1 }}><TextField icon={Ticket} placeholder="กรอกโค้ดส่วนลด" value="" onChange={() => {}} disabled /></div>
            <button style={{ padding: '0 18px', borderRadius: 14, border: '1.5px solid var(--pine)', background: 'transparent', color: 'var(--pine)', fontWeight: 700, fontSize: 13 }}>ใช้</button>
          </div>
        </div>
        {item.breakdown && (
          <div style={{ border: '1px solid var(--border)', borderRadius: 18, padding: 16, display: 'flex', flexDirection: 'column', gap: 8 }}>
            {item.breakdown.map(([k, v]) => (
              <div key={k} style={{ display: 'flex', justifyContent: 'space-between', gap: 12, fontSize: 12.5 }}><span style={{ color: 'var(--ink-soft)' }}>{k}</span><span style={{ fontWeight: 600, textAlign: 'right' }}>{v}</span></div>
            ))}
          </div>
        )}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13 }}><span style={{ color: 'var(--ink-soft)' }}>ราคารวม</span><span style={{ fontWeight: 600 }}>฿{item.price.toLocaleString()}</span></div>
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13 }}><span style={{ color: 'var(--ink-soft)' }}>ค่าธรรมเนียมบริการ</span><span style={{ fontWeight: 600 }}>฿{fee.toLocaleString()}</span></div>
          <div style={{ display: 'flex', justifyContent: 'space-between', paddingTop: 10, borderTop: '1px dashed var(--border)' }}>
            <span style={{ fontWeight: 700 }}>ยอดชำระทั้งหมด</span>
            <span className="font-display" style={{ fontSize: 18, fontWeight: 700, color: 'var(--pine)' }}>฿{total.toLocaleString()}</span>
          </div>
        </div>
      </div>
      <div style={{ padding: '16px 20px', borderTop: '1px solid var(--border)', flexShrink: 0 }}>
        <PrimaryButton onClick={onPay}>ดำเนินการชำระเงิน</PrimaryButton>
      </div>
    </div>
  );
}

export function PaymentScreen({ total, method, setMethod, onBack, onConfirm, processing, walletBalance, error }) {
  const methods = [
    { id: 'promptpay', label: 'พร้อมเพย์ (PromptPay)', icon: QrCode, note: 'สแกน QR เพื่อชำระเงินทันที' },
    { id: 'card', label: 'บัตรเครดิต/เดบิต', icon: CreditCard, note: 'Visa, Mastercard, JCB' },
    { id: 'wallet', label: 'Sabai Wallet', icon: Wallet, note: `คงเหลือ ฿${walletBalance.toLocaleString()}` },
  ];
  if (processing) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', gap: 16 }}>
        <div style={{ width: 56, height: 56, borderRadius: 999, border: '4px solid var(--pine-pale)', borderTopColor: 'var(--pine)', animation: 'spin-slow 0.9s linear infinite' }} />
        <p style={{ fontSize: 13.5, fontWeight: 700 }}>กำลังดำเนินการชำระเงิน...</p>
        <p style={{ fontSize: 11.5, color: 'var(--ink-soft)' }}>กรุณาอย่าปิดหน้าจอ</p>
      </div>
    );
  }
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="ชำระเงิน" onBack={onBack} />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 12 }}>
        {methods.map((m) => {
          const Icon = m.icon;
          const active = method === m.id;
          return (
            <button key={m.id} onClick={() => setMethod(m.id)} style={{ display: 'flex', alignItems: 'center', gap: 14, padding: 16, borderRadius: 16, border: active ? '2px solid var(--pine)' : '1.5px solid var(--border)', background: active ? 'var(--pine-pale)' : 'var(--surface)', cursor: 'pointer', textAlign: 'left' }}>
              <Icon size={22} color="var(--pine)" />
              <div style={{ flex: 1 }}>
                <p style={{ fontSize: 13.5, fontWeight: 700, color: 'var(--ink)' }}>{m.label}</p>
                <p style={{ fontSize: 11, color: 'var(--ink-soft)' }}>{m.note}</p>
              </div>
              <div style={{ width: 20, height: 20, borderRadius: 999, border: '2px solid var(--pine)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                {active && <div style={{ width: 10, height: 10, borderRadius: 999, background: 'var(--pine)' }} />}
              </div>
            </button>
          );
        })}
        {method === 'card' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: 6 }}>
            <TextField icon={CreditCard} placeholder="หมายเลขบัตร" value="" onChange={() => {}} disabled />
            <div style={{ display: 'flex', gap: 10 }}>
              <div style={{ flex: 1 }}><TextField icon={Calendar} placeholder="MM/YY" value="" onChange={() => {}} disabled /></div>
              <div style={{ flex: 1 }}><TextField icon={Lock} placeholder="CVV" value="" onChange={() => {}} disabled /></div>
            </div>
          </div>
        )}
      </div>
      <div style={{ padding: '16px 20px', borderTop: '1px solid var(--border)', display: 'flex', flexDirection: 'column', gap: 10, flexShrink: 0 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
          <span style={{ fontSize: 13, color: 'var(--ink-soft)' }}>ยอดชำระ</span>
          <span className="font-display" style={{ fontSize: 17, fontWeight: 700, color: 'var(--pine)' }}>฿{total.toLocaleString()}</span>
        </div>
        {error && <p role="alert" style={{ fontSize: 12, fontWeight: 600, color: 'var(--danger)' }}>{error}</p>}
        <PrimaryButton onClick={onConfirm}>ยืนยันการชำระเงิน</PrimaryButton>
      </div>
    </div>
  );
}

export function ConfirmationScreen({ bookingNumber, item, onHome, onViewBookings, onViewCalendar }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', padding: 30, textAlign: 'center', gap: 16 }}>
      <div className="fade-up" style={{ width: 76, height: 76, borderRadius: 999, background: 'var(--pine-pale)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <CheckCircle2 size={40} color="var(--pine)" />
      </div>
      <p className="font-display" style={{ fontSize: 22, fontWeight: 600 }}>จองสำเร็จ!</p>
      <p style={{ fontSize: 13, color: 'var(--ink-soft)' }}>เราได้ส่งรายละเอียดการจองไปยังอีเมลของคุณแล้ว</p>
      <div style={{ width: '100%', border: '1px dashed var(--border)', borderRadius: 16, padding: 16 }}>
        <p style={{ fontSize: 11, color: 'var(--ink-soft)' }}>หมายเลขการจอง</p>
        <p className="font-display" style={{ fontSize: 18, fontWeight: 700, color: 'var(--pine)' }}>{bookingNumber}</p>
        {item && <p style={{ fontSize: 12.5, color: 'var(--ink)', marginTop: 8 }}>{item.title}</p>}
      </div>
      <div style={{ width: '100%', marginTop: 10, display: 'flex', flexDirection: 'column', gap: 10 }}>
        {item && item.plan && <PrimaryButton onClick={onViewCalendar}>ดูในปฏิทินและเลขา</PrimaryButton>}
        {item && item.plan ? <SecondaryButton onClick={onViewBookings}>ดูการจองของฉัน</SecondaryButton> : <PrimaryButton onClick={onViewBookings}>ดูการจองของฉัน</PrimaryButton>}
        <SecondaryButton onClick={onHome}>กลับสู่หน้าแรก</SecondaryButton>
      </div>
    </div>
  );
}
