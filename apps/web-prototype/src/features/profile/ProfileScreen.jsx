import { ChevronRight, FileText, HelpCircle, LogOut, Settings, Star, Ticket, Users, Wallet } from 'lucide-react';

export function ProfileScreen({ onLogout, onWalletTap, onReviewsTap, onCouponTap, onHelpTap, onBookingsTap, onSettingsTap, onCommunityTap }) {
  const items = [
    { icon: Users, label: 'ชุมชนของฉัน', onClick: onCommunityTap },
    { icon: FileText, label: 'การจองของฉัน', onClick: onBookingsTap },
    { icon: Wallet, label: 'กระเป๋าเงิน', onClick: onWalletTap },
    { icon: Ticket, label: 'คูปองของฉัน', onClick: onCouponTap },
    { icon: Star, label: 'รีวิวของฉัน', onClick: onReviewsTap },
    { icon: Settings, label: 'การตั้งค่า', onClick: onSettingsTap },
    { icon: HelpCircle, label: 'ช่วยเหลือ', onClick: onHelpTap },
  ];
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 20 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <div style={{ width: 60, height: 60, borderRadius: 999, background: 'var(--amber-soft)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20, fontWeight: 700, color: 'var(--pine)' }}>น</div>
          <div>
            <p className="font-display" style={{ fontSize: 17, fontWeight: 600 }}>หนาน ใจดี</p>
            <p style={{ fontSize: 12, color: 'var(--ink-soft)' }}>nan.jaidee@email.com</p>
          </div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', borderRadius: 18, border: '1px solid var(--border)', overflow: 'hidden' }}>
          {items.map((it, i) => {
            const Icon = it.icon;
            return (
              <button key={i} onClick={it.onClick} style={{ width: '100%', textAlign: 'left', background: 'none', borderTop: 'none', borderLeft: 'none', borderRight: 'none', display: 'flex', alignItems: 'center', gap: 12, padding: '14px 16px', borderBottom: i < items.length - 1 ? '1px solid var(--border)' : 'none', cursor: 'pointer' }}>
                <Icon size={17} color="var(--pine)" />
                <span style={{ fontSize: 13.5, flex: 1, color: 'var(--ink)' }}>{it.label}</span>
                <ChevronRight size={16} color="var(--ink-soft)" />
              </button>
            );
          })}
        </div>
        <button onClick={onLogout} style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, padding: 14, borderRadius: 16, border: '1.5px solid var(--danger)', background: 'transparent', color: 'var(--danger)', fontWeight: 700, fontSize: 13.5, cursor: 'pointer' }}>
          <LogOut size={16} /> ออกจากระบบ
        </button>
      </div>
    </div>
  );
}
