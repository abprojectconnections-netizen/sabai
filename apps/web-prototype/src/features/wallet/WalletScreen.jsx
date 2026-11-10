import { ArrowDown, ArrowUp } from 'lucide-react';
import { TopBar } from '../../components/ui';

export function WalletScreen({ balance, transactions, onBack }) {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="กระเป๋าเงิน" onBack={onBack} />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 20 }}>
        <div style={{ borderRadius: 20, padding: 20, background: 'linear-gradient(135deg, var(--pine) 0%, #1C5C57 100%)', color: '#fff' }}>
          <p style={{ fontSize: 12, opacity: 0.8 }}>ยอดคงเหลือ</p>
          <p className="font-display" style={{ fontSize: 30, fontWeight: 600, margin: '6px 0 16px' }}>฿{balance.toLocaleString()}</p>
          <p style={{ fontSize: 11.5, opacity: 0.85, lineHeight: 1.5 }}>เครดิตจากการคืนเงินที่คุณเลือกรับเท่านั้น ใช้ชำระค่าจองได้ · ไม่มีการเติมเงิน โอน หรือถอนในขณะนี้</p>
        </div>
        <div>
          <p className="font-display" style={{ fontSize: 15, fontWeight: 600, marginBottom: 12 }}>ธุรกรรมล่าสุด</p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {transactions.map((t) => (
              <div key={t.id} style={{ display: 'flex', alignItems: 'center', gap: 12, border: '1px solid var(--border)', borderRadius: 16, padding: 12 }}>
                <div style={{ width: 38, height: 38, borderRadius: 999, background: t.type === 'in' ? 'var(--pine-pale)' : 'var(--danger-soft)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  {t.type === 'in' ? <ArrowDown size={16} color="var(--pine)" /> : <ArrowUp size={16} color="var(--danger)" />}
                </div>
                <div style={{ flex: 1 }}>
                  <p style={{ fontSize: 13, fontWeight: 600, color: 'var(--ink)' }}>{t.label}</p>
                  <p style={{ fontSize: 11, color: 'var(--ink-soft)' }}>{t.date}</p>
                </div>
                <span style={{ fontSize: 13, fontWeight: 700, color: t.type === 'in' ? 'var(--pine)' : 'var(--danger)' }}>{t.type === 'in' ? '+' : '-'}฿{t.amount.toLocaleString()}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
