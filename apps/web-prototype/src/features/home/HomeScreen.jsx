import { Bell, ChevronDown, Heart, Hotel, Landmark, MapPin, Plane, Search, Sparkles, Ticket, UtensilsCrossed } from 'lucide-react';
import { IconCircle } from '../../components/ui';
import { DESTINATIONS } from '../../data/catalog';

export function HomeScreen({ onSearchTap, onQuickAction, onAiTap, onDestinationTap, onNotificationsTap, unreadCount }) {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '20px 20px 28px', display: 'flex', flexDirection: 'column', gap: 22 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: 'var(--ink-soft)', fontSize: 12, fontWeight: 600 }}>
            <MapPin size={14} /> กรุงเทพฯ, ประเทศไทย <ChevronDown size={14} />
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <button onClick={onNotificationsTap} style={{ position: 'relative', background: 'none', border: 'none', cursor: 'pointer', padding: 0, display: 'flex' }}>
              <Bell size={20} color="var(--ink)" />
              {unreadCount > 0 && <span style={{ position: 'absolute', top: -2, right: -2, width: 8, height: 8, borderRadius: 999, background: 'var(--danger)' }} />}
            </button>
            <div style={{ width: 34, height: 34, borderRadius: 999, background: 'var(--amber-soft)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, color: 'var(--pine)', fontSize: 13 }}>น</div>
          </div>
        </div>

        <div>
          <p className="font-display" style={{ fontSize: 24, fontWeight: 600, color: 'var(--ink)' }}>สวัสดี, หนาน 👋</p>
          <p style={{ fontSize: 13, color: 'var(--ink-soft)', marginTop: 2 }}>วันนี้อยากไปเที่ยวที่ไหนดี?</p>
        </div>

        <button onClick={onSearchTap} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '14px 16px', borderRadius: 16, border: '1.5px solid var(--border)', background: 'var(--surface)', cursor: 'pointer' }}>
          <Search size={18} color="var(--ink-soft)" />
          <span style={{ fontSize: 13, color: 'var(--ink-soft)' }}>ค้นหาที่พัก ร้านอาหาร สถานที่เที่ยว</span>
        </button>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 6 }}>
          <IconCircle icon={Plane} bg="#E4EDEA" color="var(--pine)" label="เที่ยวบิน" onClick={() => onQuickAction('เที่ยวบิน')} />
          <IconCircle icon={Hotel} bg="#E4EDEA" color="var(--pine)" label="ที่พัก" onClick={() => onQuickAction('ที่พัก')} />
          <IconCircle icon={UtensilsCrossed} bg="#E4EDEA" color="var(--pine)" label="อาหาร" onClick={() => onQuickAction('อาหาร')} />
          <IconCircle icon={Landmark} bg="#E4EDEA" color="var(--pine)" label="เที่ยว" onClick={() => onQuickAction('สถานที่เที่ยว')} />
          <IconCircle icon={Sparkles} bg="var(--amber-soft)" color="var(--amber-ink)" label="AI แพลน" onClick={onAiTap} />
        </div>

        <button onClick={onAiTap} style={{ textAlign: 'left', border: 'none', cursor: 'pointer', borderRadius: 20, padding: 20, background: 'linear-gradient(135deg, var(--pine) 0%, #1C5C57 100%)', color: '#fff' }}>
          <Sparkles size={20} color="var(--amber)" style={{ marginBottom: 10 }} />
          <p className="font-display" style={{ fontSize: 17, fontWeight: 600, marginBottom: 4 }}>ให้ AI จัดทริปให้คุณ</p>
          <p style={{ fontSize: 12.5, opacity: 0.85, maxWidth: 220, lineHeight: 1.5 }}>บอกจุดหมาย งบประมาณ และสไตล์การเที่ยว ที่เหลือให้ AI จัดการ</p>
          <span style={{ display: 'inline-block', marginTop: 14, fontSize: 12, fontWeight: 700, background: 'var(--amber)', color: 'var(--on-amber-solid)', padding: '8px 14px', borderRadius: 999 }}>เริ่มวางแผนทริป</span>
        </button>

        <div>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 12 }}>
            <h2 className="font-display" style={{ fontSize: 17, fontWeight: 600, color: 'var(--ink)' }}>จุดหมายยอดนิยม</h2>
            <span style={{ fontSize: 12, color: 'var(--pine)', fontWeight: 600 }}>ดูทั้งหมด</span>
          </div>
          <div className="scrollbar-hide" style={{ display: 'flex', gap: 12, overflowX: 'auto', paddingBottom: 4 }}>
            {DESTINATIONS.map((d) => (
              <button key={d.id} onClick={() => onDestinationTap(d)} style={{ flex: '0 0 auto', width: 150, height: 180, borderRadius: 20, border: 'none', cursor: 'pointer', padding: 14, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end', background: d.gradient, position: 'relative', overflow: 'hidden' }}>
                <span style={{ position: 'absolute', top: 12, right: 12 }}><Heart size={16} color="#fff" /></span>
                <p className="font-display" style={{ color: '#fff', fontSize: 17, fontWeight: 600, textAlign: 'left' }}>{d.name}</p>
                <p style={{ color: 'rgba(255,255,255,0.85)', fontSize: 10.5, textAlign: 'left', marginTop: 2 }}>{d.sub}</p>
              </button>
            ))}
          </div>
        </div>

        <div style={{ borderRadius: 20, background: 'var(--amber-soft)', padding: 16, display: 'flex', alignItems: 'center', gap: 14 }}>
          <div style={{ width: 44, height: 44, borderRadius: 14, background: 'var(--amber)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Ticket size={20} color="var(--on-amber-solid)" />
          </div>
          <div>
            <p style={{ fontSize: 13, fontWeight: 700, color: 'var(--on-amber)' }}>ลด 20% ทริปแรกของคุณ</p>
            <p style={{ fontSize: 11.5, color: 'var(--amber-ink)' }}>ใช้โค้ด SABAI20 ก่อนสิ้นเดือนนี้</p>
          </div>
        </div>
      </div>
    </div>
  );
}
