import { Car, Clock, Coffee, MapPin, Search, SlidersHorizontal, UtensilsCrossed, Waves, Wifi } from 'lucide-react';
import { Chip, PrimaryButton, RatingStars, TopBar } from '../../components/ui';
import { TYPE_GRADIENT, TYPE_ICON, TYPE_LABEL } from '../../ui/typeMeta';

export function SearchScreen({ query, setQuery, category, setCategory, results, onSelect }) {
  const categories = ['ทั้งหมด', 'ที่พัก', 'อาหาร', 'เที่ยวบิน', 'สถานที่เที่ยว'];
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <div style={{ padding: '18px 20px 14px', display: 'flex', flexDirection: 'column', gap: 14, borderBottom: '1px solid var(--border)', flexShrink: 0 }}>
        <h1 className="font-display" style={{ fontSize: 20, fontWeight: 600 }}>ค้นหา</h1>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '12px 14px', borderRadius: 14, border: '1.5px solid var(--border)' }}>
          <Search size={17} color="var(--ink-soft)" />
          <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="ค้นหาที่พัก ร้านอาหาร เที่ยวบิน..."
            style={{ border: 'none', outline: 'none', flex: 1, fontSize: 13.5, fontFamily: "'Plus Jakarta Sans', sans-serif" }} />
          <SlidersHorizontal size={17} color="var(--ink-soft)" />
        </div>
        <div className="scrollbar-hide" style={{ display: 'flex', gap: 8, overflowX: 'auto' }}>
          {categories.map((c) => <Chip key={c} label={c} active={category === c} onClick={() => setCategory(c)} />)}
        </div>
      </div>
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '16px 20px', display: 'flex', flexDirection: 'column', gap: 12 }}>
        {results.length === 0 && <p style={{ textAlign: 'center', color: 'var(--ink-soft)', fontSize: 13, marginTop: 40 }}>ไม่พบผลลัพธ์ที่ตรงกัน ลองค้นหาด้วยคำอื่น</p>}
        {results.map((item) => {
          const Icon = TYPE_ICON[item.type];
          return (
            <button key={item.id} onClick={() => onSelect(item)} style={{ display: 'flex', gap: 14, textAlign: 'left', border: '1px solid var(--border)', borderRadius: 18, padding: 12, background: 'var(--surface)', cursor: 'pointer' }}>
              <div style={{ width: 64, height: 64, borderRadius: 14, flexShrink: 0, background: TYPE_GRADIENT[item.type], display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Icon size={24} color="#fff" />
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <p style={{ fontSize: 14, fontWeight: 700, color: 'var(--ink)' }}>{item.name}</p>
                <p style={{ fontSize: 11.5, color: 'var(--ink-soft)', margin: '2px 0 6px', display: 'flex', alignItems: 'center', gap: 4 }}><MapPin size={11} /> {item.location}</p>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <RatingStars value={item.rating} />
                  <span style={{ fontSize: 13, fontWeight: 700, color: 'var(--pine)' }}>฿{item.price.toLocaleString()}</span>
                </div>
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}

export function ListingDetailScreen({ item, onBack, onBook }) {
  if (!item) return null;
  const Icon = TYPE_ICON[item.type];
  const amenities = item.type === 'hotel'
    ? [{ icon: Wifi, label: 'ไวไฟฟรี' }, { icon: Waves, label: 'สระว่ายน้ำ' }, { icon: Car, label: 'ที่จอดรถ' }]
    : item.type === 'restaurant'
    ? [{ icon: UtensilsCrossed, label: 'อาหารพื้นเมือง' }, { icon: Coffee, label: 'เครื่องดื่ม' }]
    : [{ icon: Clock, label: 'เปิด 08:00–18:00' }];
  const desc = {
    hotel: 'ที่พักสไตล์ล้านนา ท่ามกลางบรรยากาศร่มรื่น ห่างจากย่านใจกลางเมืองเพียงไม่กี่นาที เหมาะสำหรับทริปพักผ่อนหรือทำงานไปด้วยเที่ยวไปด้วย',
    restaurant: 'ร้านอาหารท้องถิ่นที่คนในพื้นที่แนะนำ เสิร์ฟเมนูขึ้นชื่อด้วยวัตถุดิบสดใหม่ทุกวัน บรรยากาศเป็นกันเอง',
    attraction: 'สถานที่ท่องเที่ยวสำคัญที่ไม่ควรพลาด เหมาะกับการถ่ายภาพและเรียนรู้ประวัติศาสตร์ท้องถิ่น',
    flight: 'เที่ยวบินตรง สะดวก ตรงเวลา พร้อมบริการเช็คอินออนไลน์และเลือกที่นั่งล่วงหน้า',
  }[item.type];
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title={TYPE_LABEL[item.type]} onBack={onBack} />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto' }}>
        <div style={{ height: 190, background: TYPE_GRADIENT[item.type], display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon size={56} color="rgba(255,255,255,0.9)" />
        </div>
        <div style={{ padding: 20 }}>
          <p className="font-display" style={{ fontSize: 21, fontWeight: 600, color: 'var(--ink)' }}>{item.name}</p>
          <p style={{ fontSize: 12.5, color: 'var(--ink-soft)', display: 'flex', alignItems: 'center', gap: 4, margin: '6px 0 10px' }}><MapPin size={12} /> {item.location}</p>
          <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 16 }}>
            <RatingStars value={item.rating} />
            <span style={{ fontSize: 12, color: 'var(--ink-soft)' }}>{item.reviews.toLocaleString()} รีวิว</span>
          </div>
          <p style={{ fontSize: 13.5, lineHeight: 1.7, color: 'var(--ink)', marginBottom: 18 }}>{desc}</p>
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
            {amenities.map((a, i) => {
              const AIcon = a.icon;
              return (
                <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '8px 12px', borderRadius: 999, background: 'var(--pine-pale)' }}>
                  <AIcon size={14} color="var(--pine)" />
                  <span style={{ fontSize: 11.5, fontWeight: 600, color: 'var(--pine)' }}>{a.label}</span>
                </div>
              );
            })}
          </div>
        </div>
      </div>
      <div style={{ padding: '16px 20px', borderTop: '1px solid var(--border)', display: 'flex', alignItems: 'center', gap: 14, flexShrink: 0 }}>
        <div style={{ flex: 1 }}>
          <p style={{ fontSize: 11, color: 'var(--ink-soft)' }}>เริ่มต้น</p>
          <p className="font-display" style={{ fontSize: 19, fontWeight: 700, color: 'var(--pine)' }}>฿{item.price.toLocaleString()}</p>
        </div>
        <div style={{ flex: 1 }}><PrimaryButton onClick={onBook}>จองเลย</PrimaryButton></div>
      </div>
    </div>
  );
}
