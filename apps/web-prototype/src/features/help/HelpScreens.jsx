import { useState } from 'react';
import { AlertCircle, ChevronDown, ChevronUp, FileText, MessageCircle, Phone, Send } from 'lucide-react';
import { PrimaryButton, TextField, TopBar } from '../../components/ui';
import { FAQS } from '../../data/catalog';
import { TextArea } from '../reviews/ReviewScreens';

export function FaqItem({ faq, open, onToggle }) {
  return (
    <div style={{ border: '1px solid var(--border)', borderRadius: 16, overflow: 'hidden' }}>
      <button onClick={onToggle} style={{ width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10, padding: 14, background: 'none', border: 'none', cursor: 'pointer', textAlign: 'left' }}>
        <span style={{ fontSize: 13, fontWeight: 700, color: 'var(--ink)' }}>{faq.q}</span>
        {open ? <ChevronUp size={16} color="var(--ink-soft)" style={{ flexShrink: 0 }} /> : <ChevronDown size={16} color="var(--ink-soft)" style={{ flexShrink: 0 }} />}
      </button>
      {open && <p style={{ padding: '0 14px 14px', fontSize: 12.5, color: 'var(--ink-soft)', lineHeight: 1.6 }}>{faq.a}</p>}
    </div>
  );
}

export function HelpScreen({ onBack, onOpenTicket, tickets }) {
  const [openFaqId, setOpenFaqId] = useState(null);
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="ช่วยเหลือ" onBack={onBack} />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 24 }}>
        <div style={{ display: 'flex', gap: 10 }}>
          <button style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, padding: '16px 10px', borderRadius: 18, border: '1.5px solid var(--border)', background: 'var(--surface)', cursor: 'pointer' }}>
            <div style={{ width: 40, height: 40, borderRadius: 999, background: 'var(--pine-pale)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <MessageCircle size={18} color="var(--pine)" />
            </div>
            <span style={{ fontSize: 12, fontWeight: 700, color: 'var(--ink)' }}>แชทสด</span>
            <span style={{ fontSize: 10, color: 'var(--ink-soft)' }}>ตลอด 24 ชม.</span>
          </button>
          <button onClick={onOpenTicket} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, padding: '16px 10px', borderRadius: 18, border: '1.5px solid var(--border)', background: 'var(--surface)', cursor: 'pointer' }}>
            <div style={{ width: 40, height: 40, borderRadius: 999, background: 'var(--amber-soft)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <AlertCircle size={18} color="var(--amber-ink)" />
            </div>
            <span style={{ fontSize: 12, fontWeight: 700, color: 'var(--ink)' }}>แจ้งปัญหา</span>
            <span style={{ fontSize: 10, color: 'var(--ink-soft)' }}>สร้างตั๋วสนับสนุน</span>
          </button>
        </div>

        {tickets.length > 0 && (
          <div>
            <p className="font-display" style={{ fontSize: 15, fontWeight: 600, marginBottom: 10 }}>ตั๋วสนับสนุนของฉัน</p>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {tickets.map((t) => (
                <div key={t.id} style={{ display: 'flex', alignItems: 'center', gap: 12, border: '1px solid var(--border)', borderRadius: 14, padding: 12 }}>
                  <div style={{ width: 34, height: 34, borderRadius: 999, background: 'var(--pine-pale)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                    <FileText size={15} color="var(--pine)" />
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <p style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--ink)' }}>{t.subject}</p>
                    <p style={{ fontSize: 10.5, color: 'var(--ink-soft)' }}>{t.date}</p>
                  </div>
                  <span style={{ fontSize: 10.5, fontWeight: 700, padding: '4px 10px', borderRadius: 999, background: 'var(--amber-soft)', color: 'var(--amber-ink)', flexShrink: 0 }}>รอตอบกลับ</span>
                </div>
              ))}
            </div>
          </div>
        )}

        <div>
          <p className="font-display" style={{ fontSize: 15, fontWeight: 600, marginBottom: 10 }}>คำถามที่พบบ่อย</p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {FAQS.map((f) => (
              <FaqItem key={f.id} faq={f} open={openFaqId === f.id} onToggle={() => setOpenFaqId(openFaqId === f.id ? null : f.id)} />
            ))}
          </div>
        </div>

        <div style={{ borderRadius: 16, background: 'var(--pine-pale)', padding: 14, display: 'flex', alignItems: 'center', gap: 10 }}>
          <Phone size={16} color="var(--pine)" />
          <span style={{ fontSize: 12, color: 'var(--pine)', fontWeight: 600 }}>สายด่วนฉุกเฉิน: 02-123-4567 (24 ชม.)</span>
        </div>
      </div>
    </div>
  );
}

export function SupportTicketScreen({ subject, setSubject, message, setMessage, onBack, onSubmit }) {
  const canSubmit = subject.trim().length > 0 && message.trim().length > 0;
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="แจ้งปัญหา" onBack={onBack} />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 18 }}>
        <div>
          <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 8 }}>หัวข้อปัญหา</p>
          <TextField placeholder="เช่น ปัญหาการชำระเงิน, การจองผิดพลาด" value={subject} onChange={(e) => setSubject(e.target.value)} />
        </div>
        <div>
          <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 8 }}>รายละเอียด</p>
          <TextArea placeholder="อธิบายปัญหาที่พบโดยละเอียด เพื่อให้ทีมงานช่วยเหลือได้รวดเร็วขึ้น..." value={message} onChange={(e) => setMessage(e.target.value)} />
        </div>
        <p style={{ fontSize: 11.5, color: 'var(--ink-soft)', lineHeight: 1.6 }}>ทีมงานจะตอบกลับภายใน 24 ชั่วโมง ผ่านการแจ้งเตือนในแอปและอีเมลที่ลงทะเบียนไว้</p>
      </div>
      <div style={{ padding: '14px 20px', borderTop: '1px solid var(--border)', flexShrink: 0 }}>
        <PrimaryButton onClick={onSubmit} disabled={!canSubmit}>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}><Send size={15} /> ส่งตั๋วสนับสนุน</span>
        </PrimaryButton>
      </div>
    </div>
  );
}
