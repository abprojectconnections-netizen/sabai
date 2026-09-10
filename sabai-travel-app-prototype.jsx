import React, { useState } from 'react';
import {
  Home, Search, Sparkles, Briefcase, User, Bell, MapPin, Star, ChevronRight,
  ArrowLeft, Calendar, Wallet, CreditCard, CheckCircle2, Plane, Hotel,
  UtensilsCrossed, Coffee, SlidersHorizontal, Plus, Minus, Clock, Mail, Lock,
  ChevronDown, Heart, LogOut, Settings, HelpCircle, Ticket, Wifi, Car, Waves,
  Landmark, QrCode, FileText, Phone, ArrowDown, ArrowUp
} from 'lucide-react';

/* ---------------------------------------------------------------- */
/*  THEME + FONTS                                                    */
/* ---------------------------------------------------------------- */

const FONT_CSS = `
@import url('https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,400;9..144,500;9..144,600;9..144,700&family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap');
:root{
  --ink:#16241F; --ink-soft:#5C6A64; --paper:#FAFAF8; --surface:#FFFFFF;
  --pine:#10403D; --pine-light:#1C5C57; --pine-pale:#E4EDEA;
  --amber:#E3A23C; --amber-soft:#F6E4C1; --border:#E4E1D8; --danger:#C0483A;
}
.font-display{ font-family:'Fraunces', serif; }
@keyframes spin-slow{ to{ transform:rotate(360deg); } }
@keyframes fade-up{ from{opacity:0; transform:translateY(8px);} to{opacity:1; transform:translateY(0);} }
.fade-up{ animation: fade-up .35s ease both; }
.scrollbar-hide::-webkit-scrollbar{ display:none; }
.scrollbar-hide{ -ms-overflow-style:none; scrollbar-width:none; }
`;

/* ---------------------------------------------------------------- */
/*  MOCK DATA                                                         */
/* ---------------------------------------------------------------- */

const DESTINATIONS = [
  { id: 'chiangmai', name: 'เชียงใหม่', sub: 'ภูเขา ธรรมชาติ วัฒนธรรมล้านนา', gradient: 'linear-gradient(135deg,#1C5C57,#89A66B)' },
  { id: 'phuket', name: 'ภูเก็ต', sub: 'ทะเลอันดามัน ชายหาดสวย', gradient: 'linear-gradient(135deg,#0B4F6C,#01BAEF)' },
  { id: 'krabi', name: 'กระบี่', sub: 'หน้าผาหินปูน เกาะแก่ง', gradient: 'linear-gradient(135deg,#123C69,#3E92CC)' },
  { id: 'pai', name: 'ปาย', sub: 'หมอกยามเช้า คาเฟ่ริมเขา', gradient: 'linear-gradient(135deg,#7A4B22,#E3A23C)' },
  { id: 'bangkok', name: 'กรุงเทพฯ', sub: 'เมืองหลวง สตรีทฟู้ด ช้อปปิ้ง', gradient: 'linear-gradient(135deg,#3B2352,#A768C9)' },
  { id: 'samui', name: 'เกาะสมุย', sub: 'เกาะสวรรค์ มะพร้าว ทะเลใส', gradient: 'linear-gradient(135deg,#0E6E55,#59C9A5)' },
];

const LISTINGS = [
  { id: 1, type: 'hotel', name: 'ล้านนา วิว รีสอร์ท', location: 'นิมมานเหมินท์, เชียงใหม่', rating: 4.8, reviews: 342, price: 1490 },
  { id: 2, type: 'restaurant', name: 'ข้าวซอยแม่สาย', location: 'เมืองเก่า, เชียงใหม่', rating: 4.6, reviews: 891, price: 120 },
  { id: 3, type: 'attraction', name: 'วัดพระธาตุดอยสุเทพ', location: 'ดอยสุเทพ, เชียงใหม่', rating: 4.9, reviews: 5210, price: 50 },
  { id: 4, type: 'hotel', name: 'อันดามัน บีช วิลลา', location: 'ป่าตอง, ภูเก็ต', rating: 4.7, reviews: 206, price: 2350 },
  { id: 5, type: 'flight', name: 'กรุงเทพฯ → เชียงใหม่', location: 'สายการบิน Sabai Air', rating: 4.4, reviews: 1032, price: 990 },
  { id: 6, type: 'restaurant', name: 'ครัวทะเลกระบี่', location: 'อ่าวนาง, กระบี่', rating: 4.5, reviews: 410, price: 250 },
];

const STYLE_OPTIONS = ['ธรรมชาติ', 'อาหารท้องถิ่น', 'วัฒนธรรม', 'ผจญภัย', 'ช้อปปิ้ง', 'พักผ่อนสบายๆ'];
const TRAVEL_WITH_OPTIONS = ['คนเดียว', 'คู่รัก', 'ครอบครัว', 'เพื่อน', 'กลุ่มทัวร์'];
const BUDGET_LEVELS = ['ประหยัด', 'ปานกลาง', 'หรูหรา'];

const TYPE_ICON = { hotel: Hotel, restaurant: UtensilsCrossed, flight: Plane, attraction: Landmark, trip: Sparkles };
const TYPE_GRADIENT = {
  hotel: 'linear-gradient(135deg,#1C5C57,#0B2422)',
  restaurant: 'linear-gradient(135deg,#B5651D,#7A4B22)',
  flight: 'linear-gradient(135deg,#123C69,#3E92CC)',
  attraction: 'linear-gradient(135deg,#3B2352,#A768C9)',
  trip: 'linear-gradient(135deg,#10403D,#E3A23C)',
};
const TYPE_LABEL = { hotel: 'ที่พัก', restaurant: 'อาหาร', flight: 'เที่ยวบิน', attraction: 'สถานที่เที่ยว', trip: 'ทริป' };

const NOTIF_ICON = { booking: FileText, payment: CreditCard, promotion: Ticket, trip: Briefcase, system: Settings };

function buildItinerary({ destinationName, days, budget, styles }) {
  if (destinationName === 'เชียงใหม่' && days === 3) {
    return {
      days: [
        { title: 'วันที่ 1 · เมืองเก่าเชียงใหม่', items: [
          { time: '09:00', text: 'เดินทางถึงสนามบินเชียงใหม่ เช็คอินที่พัก' },
          { time: '12:00', text: 'อาหารกลางวันข้าวซอยที่ร้านเมืองเก่า' },
          { time: '14:00', text: 'เที่ยววัดพระสิงห์และเดินเล่นถนนคนเดินท่าแพ' },
          { time: '18:30', text: 'อาหารเย็นที่ตลาดวโรรส' },
        ]},
        { title: 'วันที่ 2 · ดอยอินทนนท์', items: [
          { time: '07:00', text: 'ออกเดินทางสู่ดอยอินทนนท์' },
          { time: '09:30', text: 'ชมพระธาตุนภเมทนีดลและนภพลภูมิสิริ' },
          { time: '12:00', text: 'ปิคนิคอาหารกลางวันริมธารน้ำ' },
          { time: '15:00', text: 'เดินชมน้ำตกวชิรธาร' },
          { time: '19:00', text: 'กลับเข้าเมือง อาหารเย็นชิลๆ' },
        ]},
        { title: 'วันที่ 3 · คาเฟ่และตลาด', items: [
          { time: '09:00', text: 'จิบกาแฟที่คาเฟ่ย่านนิมมานเหมินท์' },
          { time: '11:00', text: 'ช้อปปิ้งที่ One Nimman' },
          { time: '14:00', text: 'เดินเล่นตลาดเมืองใหม่' },
          { time: '17:00', text: 'เดินทางกลับสนามบิน' },
        ]},
      ],
      budgetBreakdown: [
        { label: 'เที่ยวบิน', value: 3000 },
        { label: 'ที่พัก', value: 4000 },
        { label: 'อาหาร', value: 1500 },
        { label: 'กิจกรรม', value: 1000 },
        { label: 'การเดินทางในพื้นที่', value: 500 },
      ],
    };
  }
  const templates = [
    (d) => `สำรวจแหล่งท่องเที่ยวสำคัญของ${d}`,
    (d) => `ลิ้มลองอาหารท้องถิ่นชื่อดังของ${d}`,
    () => `เดินเล่นตลาดและย่านคาเฟ่ยอดนิยม`,
    (d) => `กิจกรรมกลางแจ้งท่ามกลางธรรมชาติใกล้${d}`,
    () => `พักผ่อนและช้อปปิ้งของฝาก`,
  ];
  const dayList = Array.from({ length: Math.min(days, 7) }).map((_, i) => ({
    title: `วันที่ ${i + 1} · ${destinationName}`,
    items: [
      { time: '09:00', text: templates[i % templates.length](destinationName) },
      { time: '13:00', text: `อาหารกลางวันร้านแนะนำใน${destinationName}` },
      { time: '16:00', text: styles.length ? `กิจกรรมตามความสนใจ: ${styles.join(', ')}` : 'เดินเล่นชมเมือง' },
      { time: '19:00', text: 'อาหารเย็นและพักผ่อน' },
    ],
  }));
  const b = Math.max(budget, 3000);
  return {
    days: dayList,
    budgetBreakdown: [
      { label: 'เที่ยวบิน', value: Math.round((b * 0.28) / 100) * 100 },
      { label: 'ที่พัก', value: Math.round((b * 0.35) / 100) * 100 },
      { label: 'อาหาร', value: Math.round((b * 0.2) / 100) * 100 },
      { label: 'กิจกรรม', value: Math.round((b * 0.1) / 100) * 100 },
      { label: 'การเดินทางในพื้นที่', value: Math.round((b * 0.07) / 100) * 100 },
    ],
  };
}

/* ---------------------------------------------------------------- */
/*  SHARED UI PIECES                                                  */
/* ---------------------------------------------------------------- */

function TopBar({ title, onBack, right }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 20px', borderBottom: '1px solid var(--border)', background: 'var(--surface)', flexShrink: 0 }}>
      {onBack && (
        <button onClick={onBack} style={{ background: 'var(--pine-pale)', border: 'none', width: 36, height: 36, borderRadius: 999, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
          <ArrowLeft size={18} color="var(--pine)" />
        </button>
      )}
      <h1 className="font-display" style={{ fontSize: 18, fontWeight: 600, color: 'var(--ink)', flex: 1 }}>{title}</h1>
      {right}
    </div>
  );
}

function TabBar({ active, onChange }) {
  const tabs = [
    { id: 'home', label: 'หน้าแรก', icon: Home },
    { id: 'search', label: 'ค้นหา', icon: Search },
    { id: 'ai', label: 'AI', icon: Sparkles },
    { id: 'trips', label: 'ทริป', icon: Briefcase },
    { id: 'profile', label: 'โปรไฟล์', icon: User },
  ];
  return (
    <div style={{ display: 'flex', borderTop: '1px solid var(--border)', background: 'var(--surface)', flexShrink: 0 }}>
      {tabs.map((t) => {
        const Icon = t.icon;
        const isActive = active === t.id;
        return (
          <button key={t.id} onClick={() => onChange(t.id)} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, padding: '10px 0 14px', background: 'transparent', border: 'none', cursor: 'pointer' }}>
            <Icon size={22} strokeWidth={isActive ? 2.4 : 1.8} color={isActive ? 'var(--pine)' : 'var(--ink-soft)'} />
            <span style={{ fontSize: 11, fontWeight: isActive ? 700 : 500, color: isActive ? 'var(--pine)' : 'var(--ink-soft)' }}>{t.label}</span>
          </button>
        );
      })}
    </div>
  );
}

function Chip({ label, active, onClick }) {
  return (
    <button onClick={onClick} style={{
      padding: '8px 16px', borderRadius: 999, fontSize: 13, fontWeight: 600, whiteSpace: 'nowrap',
      border: active ? '1.5px solid var(--pine)' : '1.5px solid var(--border)',
      background: active ? 'var(--pine)' : 'var(--surface)',
      color: active ? '#fff' : 'var(--ink)', cursor: 'pointer',
    }}>{label}</button>
  );
}

function Stepper({ value, onChange, min = 1, max = 14 }) {
  const btn = { width: 36, height: 36, borderRadius: 999, border: '1.5px solid var(--border)', background: 'var(--surface)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' };
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
      <button onClick={() => onChange(Math.max(min, value - 1))} style={btn}><Minus size={16} color="var(--ink)" /></button>
      <span className="font-display" style={{ fontSize: 20, fontWeight: 600, minWidth: 28, textAlign: 'center' }}>{value}</span>
      <button onClick={() => onChange(Math.min(max, value + 1))} style={btn}><Plus size={16} color="var(--ink)" /></button>
    </div>
  );
}

function RatingStars({ value }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 3 }}>
      <Star size={13} fill="var(--amber)" color="var(--amber)" />
      <span style={{ fontSize: 12, fontWeight: 700, color: 'var(--ink)' }}>{value}</span>
    </div>
  );
}

function TextField({ icon: Icon, type = 'text', placeholder, value, onChange, disabled }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, border: '1.5px solid var(--border)', borderRadius: 14, padding: '12px 14px', background: 'var(--surface)', opacity: disabled ? 0.55 : 1 }}>
      {Icon && <Icon size={18} color="var(--ink-soft)" />}
      <input type={type} placeholder={placeholder} value={value} onChange={onChange} disabled={disabled}
        style={{ border: 'none', outline: 'none', flex: 1, fontSize: 14, fontFamily: "'Plus Jakarta Sans', sans-serif", background: 'transparent', color: 'var(--ink)', width: '100%' }} />
    </div>
  );
}

function PrimaryButton({ children, onClick, disabled }) {
  return (
    <button onClick={onClick} disabled={disabled} style={{ width: '100%', padding: '15px', borderRadius: 16, border: 'none', background: disabled ? '#B9C4C1' : 'var(--pine)', color: '#fff', fontWeight: 700, fontSize: 15, cursor: disabled ? 'default' : 'pointer' }}>
      {children}
    </button>
  );
}

function SecondaryButton({ children, onClick }) {
  return (
    <button onClick={onClick} style={{ width: '100%', padding: '15px', borderRadius: 16, border: '1.5px solid var(--pine)', background: 'transparent', color: 'var(--pine)', fontWeight: 700, fontSize: 15, cursor: 'pointer' }}>
      {children}
    </button>
  );
}

function IconCircle({ icon: Icon, bg, color, onClick, label }) {
  return (
    <button onClick={onClick} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, background: 'transparent', border: 'none', cursor: 'pointer' }}>
      <div style={{ width: 52, height: 52, borderRadius: 18, background: bg, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Icon size={22} color={color} />
      </div>
      <span style={{ fontSize: 11, fontWeight: 600, color: 'var(--ink)' }}>{label}</span>
    </button>
  );
}

function StepDots({ current, total }) {
  return (
    <div style={{ display: 'flex', gap: 6 }}>
      {Array.from({ length: total }).map((_, i) => (
        <div key={i} style={{ flex: 1, height: 4, borderRadius: 999, background: i < current ? 'var(--pine)' : 'var(--border)' }} />
      ))}
    </div>
  );
}

/* ---------------------------------------------------------------- */
/*  SCREENS                                                           */
/* ---------------------------------------------------------------- */

function LoginScreen({ email, setEmail, password, setPassword, onLogin, onGuest, onRegister }) {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <div style={{ background: 'linear-gradient(160deg, var(--pine) 0%, #0B2422 100%)', padding: '52px 28px 40px', color: '#fff', flexShrink: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 24 }}>
          <div style={{ width: 34, height: 34, borderRadius: 10, background: 'var(--amber)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Sparkles size={18} color="#10403D" />
          </div>
          <span style={{ fontWeight: 700, letterSpacing: 0.2 }}>Sabai</span>
        </div>
        <h1 className="font-display" style={{ fontSize: 32, lineHeight: 1.2, fontWeight: 600, marginBottom: 10 }}>เที่ยวให้สบาย<br />ครบในแอปเดียว</h1>
        <p style={{ fontSize: 13.5, opacity: 0.8, maxWidth: 260 }}>ค้นหา วางแผน จอง และเดินทาง — ให้ AI ช่วยจัดทริปของคุณตั้งแต่ต้นจนจบ</p>
      </div>
      <div className="fade-up scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', background: 'var(--surface)', borderTopLeftRadius: 28, borderTopRightRadius: 28, marginTop: -22, padding: '26px 24px', display: 'flex', flexDirection: 'column', gap: 14 }}>
        <div>
          <p style={{ fontSize: 13, fontWeight: 700, color: 'var(--ink)', marginBottom: 6 }}>อีเมลหรือเบอร์โทรศัพท์</p>
          <TextField icon={Mail} placeholder="you@email.com" value={email} onChange={(e) => setEmail(e.target.value)} />
        </div>
        <div>
          <p style={{ fontSize: 13, fontWeight: 700, color: 'var(--ink)', marginBottom: 6 }}>รหัสผ่าน</p>
          <TextField icon={Lock} type="password" placeholder="••••••••" value={password} onChange={(e) => setPassword(e.target.value)} />
        </div>
        <button style={{ alignSelf: 'flex-end', background: 'none', border: 'none', color: 'var(--pine)', fontSize: 12, fontWeight: 600, cursor: 'pointer' }}>ลืมรหัสผ่าน?</button>
        <div style={{ marginTop: 4 }}><PrimaryButton onClick={onLogin}>เข้าสู่ระบบ</PrimaryButton></div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, margin: '4px 0' }}>
          <div style={{ flex: 1, height: 1, background: 'var(--border)' }} />
          <span style={{ fontSize: 12, color: 'var(--ink-soft)' }}>หรือ</span>
          <div style={{ flex: 1, height: 1, background: 'var(--border)' }} />
        </div>
        <button onClick={onGuest} style={{ background: 'none', border: 'none', color: 'var(--ink-soft)', fontSize: 13, fontWeight: 600, textDecoration: 'underline', cursor: 'pointer' }}>เข้าใช้งานแบบผู้เยี่ยมชม</button>
        <p style={{ textAlign: 'center', fontSize: 12, color: 'var(--ink-soft)', marginTop: 14 }}>
          ยังไม่มีบัญชี?{' '}
          <span onClick={onRegister} style={{ color: 'var(--pine)', fontWeight: 700, cursor: 'pointer' }}>สมัครสมาชิก</span>
        </p>
      </div>
    </div>
  );
}

function RegisterScreen({ step, form, onChange, onToggleStyle, onBack, onNext, onFinish }) {
  const step1Valid = form.firstName && form.lastName && form.email && form.password && form.password === form.confirmPassword;
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="สมัครสมาชิก" onBack={onBack} />
      <div style={{ padding: '14px 20px 0', flexShrink: 0 }}>
        <StepDots current={step} total={3} />
        <p style={{ fontSize: 11, color: 'var(--ink-soft)', marginTop: 6 }}>ขั้นตอนที่ {step} จาก 3</p>
      </div>
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '16px 20px 20px', display: 'flex', flexDirection: 'column', gap: 14 }}>
        {step === 1 && (
          <>
            <p className="font-display" style={{ fontSize: 19, fontWeight: 600 }}>ข้อมูลส่วนตัว</p>
            <div style={{ display: 'flex', gap: 10 }}>
              <div style={{ flex: 1 }}><TextField icon={User} placeholder="ชื่อจริง" value={form.firstName} onChange={(e) => onChange({ firstName: e.target.value })} /></div>
              <div style={{ flex: 1 }}><TextField icon={User} placeholder="นามสกุล" value={form.lastName} onChange={(e) => onChange({ lastName: e.target.value })} /></div>
            </div>
            <TextField icon={Mail} placeholder="อีเมล" value={form.email} onChange={(e) => onChange({ email: e.target.value })} />
            <TextField icon={Phone} placeholder="เบอร์โทรศัพท์" value={form.phone} onChange={(e) => onChange({ phone: e.target.value })} />
            <TextField icon={Lock} type="password" placeholder="รหัสผ่าน" value={form.password} onChange={(e) => onChange({ password: e.target.value })} />
            <TextField icon={Lock} type="password" placeholder="ยืนยันรหัสผ่าน" value={form.confirmPassword} onChange={(e) => onChange({ confirmPassword: e.target.value })} />
            {form.confirmPassword && form.password !== form.confirmPassword && (
              <p style={{ fontSize: 11.5, color: 'var(--danger)' }}>รหัสผ่านไม่ตรงกัน</p>
            )}
          </>
        )}
        {step === 2 && (
          <>
            <p className="font-display" style={{ fontSize: 19, fontWeight: 600 }}>ข้อมูลโปรไฟล์</p>
            <div>
              <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 8 }}>เพศ</p>
              <div style={{ display: 'flex', gap: 8 }}>
                {['หญิง', 'ชาย', 'ไม่ระบุ'].map((g) => <Chip key={g} label={g} active={form.gender === g} onClick={() => onChange({ gender: g })} />)}
              </div>
            </div>
            <div>
              <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 8 }}>วันเกิด</p>
              <TextField icon={Calendar} type="date" value={form.dob} onChange={(e) => onChange({ dob: e.target.value })} />
            </div>
            <div>
              <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 8 }}>สัญชาติ</p>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                {['ไทย', 'ต่างชาติ'].map((n) => <Chip key={n} label={n} active={form.nationality === n} onClick={() => onChange({ nationality: n })} />)}
              </div>
            </div>
            <div>
              <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 8 }}>ภาษาที่ใช้งาน</p>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                {['ไทย', 'English', '中文', '日本語'].map((l) => <Chip key={l} label={l} active={form.language === l} onClick={() => onChange({ language: l })} />)}
              </div>
            </div>
          </>
        )}
        {step === 3 && (
          <>
            <p className="font-display" style={{ fontSize: 19, fontWeight: 600 }}>ความชอบด้านการเที่ยว</p>
            <div>
              <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 8 }}>งบประมาณที่สบายใจ</p>
              <div style={{ display: 'flex', gap: 8 }}>
                {BUDGET_LEVELS.map((b) => <Chip key={b} label={b} active={form.budgetLevel === b} onClick={() => onChange({ budgetLevel: b })} />)}
              </div>
            </div>
            <div>
              <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 8 }}>สไตล์การเที่ยวที่ชอบ</p>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                {STYLE_OPTIONS.map((s) => <Chip key={s} label={s} active={form.travelStyles.includes(s)} onClick={() => onToggleStyle(s)} />)}
              </div>
            </div>
            <div>
              <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 8 }}>จุดหมายที่อยากไป</p>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                {DESTINATIONS.map((d) => <Chip key={d.id} label={d.name} active={form.favoriteDestination === d.name} onClick={() => onChange({ favoriteDestination: d.name })} />)}
              </div>
            </div>
            <div>
              <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 8 }}>ปกติเที่ยวกับใคร</p>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                {TRAVEL_WITH_OPTIONS.map((t) => <Chip key={t} label={t} active={form.travelWith === t} onClick={() => onChange({ travelWith: t })} />)}
              </div>
            </div>
          </>
        )}
      </div>
      <div style={{ padding: '14px 20px', borderTop: '1px solid var(--border)', flexShrink: 0 }}>
        {step < 3 ? (
          <PrimaryButton onClick={onNext} disabled={step === 1 && !step1Valid}>ถัดไป</PrimaryButton>
        ) : (
          <PrimaryButton onClick={onFinish}>เริ่มต้นใช้งาน 🎉</PrimaryButton>
        )}
      </div>
    </div>
  );
}

function HomeScreen({ onSearchTap, onQuickAction, onAiTap, onDestinationTap, onNotificationsTap, unreadCount }) {
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
          <IconCircle icon={Sparkles} bg="var(--amber-soft)" color="#8A5A17" label="AI แพลน" onClick={onAiTap} />
        </div>

        <button onClick={onAiTap} style={{ textAlign: 'left', border: 'none', cursor: 'pointer', borderRadius: 20, padding: 20, background: 'linear-gradient(135deg, var(--pine) 0%, #1C5C57 100%)', color: '#fff' }}>
          <Sparkles size={20} color="var(--amber)" style={{ marginBottom: 10 }} />
          <p className="font-display" style={{ fontSize: 17, fontWeight: 600, marginBottom: 4 }}>ให้ AI จัดทริปให้คุณ</p>
          <p style={{ fontSize: 12.5, opacity: 0.85, maxWidth: 220, lineHeight: 1.5 }}>บอกจุดหมาย งบประมาณ และสไตล์การเที่ยว ที่เหลือให้ AI จัดการ</p>
          <span style={{ display: 'inline-block', marginTop: 14, fontSize: 12, fontWeight: 700, background: 'var(--amber)', color: '#4A2E06', padding: '8px 14px', borderRadius: 999 }}>เริ่มวางแผนทริป</span>
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
            <Ticket size={20} color="#4A2E06" />
          </div>
          <div>
            <p style={{ fontSize: 13, fontWeight: 700, color: '#4A2E06' }}>ลด 20% ทริปแรกของคุณ</p>
            <p style={{ fontSize: 11.5, color: '#7A5219' }}>ใช้โค้ด SABAI20 ก่อนสิ้นเดือนนี้</p>
          </div>
        </div>
      </div>
    </div>
  );
}

function SearchScreen({ query, setQuery, category, setCategory, results, onSelect }) {
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

function ListingDetailScreen({ item, onBack, onBook }) {
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

function AiPlannerScreen({ destination, setDestination, days, setDays, budget, setBudget, styles, toggleStyle, travelers, setTravelers, generating, result, onGenerate, onReset, onSave, onBookTrip, saved }) {
  if (generating) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', gap: 18, padding: 20, textAlign: 'center' }}>
        <div style={{ width: 64, height: 64, borderRadius: 999, background: 'var(--pine-pale)', display: 'flex', alignItems: 'center', justifyContent: 'center', animation: 'spin-slow 2.2s linear infinite' }}>
          <Sparkles size={28} color="var(--pine)" />
        </div>
        <p className="font-display" style={{ fontSize: 17, fontWeight: 600 }}>AI กำลังจัดทริปให้คุณ...</p>
        <p style={{ fontSize: 12.5, color: 'var(--ink-soft)', maxWidth: 230 }}>กำลังวิเคราะห์งบประมาณ ระยะทาง และสไตล์การเที่ยวที่คุณเลือก</p>
      </div>
    );
  }

  if (result) {
    const total = result.budgetBreakdown.reduce((s, b) => s + b.value, 0);
    const maxVal = Math.max(...result.budgetBreakdown.map((b) => b.value));
    return (
      <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        <div style={{ padding: '18px 20px 12px', borderBottom: '1px solid var(--border)', flexShrink: 0 }}>
          <button onClick={onReset} style={{ background: 'none', border: 'none', color: 'var(--pine)', fontSize: 12, fontWeight: 700, marginBottom: 8, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 4 }}><ArrowLeft size={14} /> วางแผนใหม่</button>
          <h1 className="font-display" style={{ fontSize: 19, fontWeight: 600 }}>ทริป {destination} · {days} วัน</h1>
          <p style={{ fontSize: 12, color: 'var(--ink-soft)' }}>{travelers} ผู้เดินทาง · จัดโดย AI</p>
        </div>
        <div className="scrollbar-hide fade-up" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '18px 20px', display: 'flex', flexDirection: 'column', gap: 20 }}>
          {result.days.map((day, i) => (
            <div key={i}>
              <p style={{ fontSize: 13.5, fontWeight: 700, color: 'var(--pine)', marginBottom: 10 }}>{day.title}</p>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                {day.items.map((it, j) => (
                  <div key={j} style={{ display: 'flex', gap: 12 }}>
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                      <div style={{ width: 8, height: 8, borderRadius: 999, background: 'var(--amber)', marginTop: 5 }} />
                      {j < day.items.length - 1 && <div style={{ width: 1.5, flex: 1, background: 'var(--border)', marginTop: 2 }} />}
                    </div>
                    <div style={{ paddingBottom: 10 }}>
                      <p style={{ fontSize: 11.5, fontWeight: 700, color: 'var(--ink-soft)' }}>{it.time}</p>
                      <p style={{ fontSize: 13, color: 'var(--ink)', marginTop: 1 }}>{it.text}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ))}

          <div>
            <p className="font-display" style={{ fontSize: 15, fontWeight: 600, marginBottom: 10 }}>ประมาณการค่าใช้จ่าย</p>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 10 }}>
              {result.budgetBreakdown.map((b, i) => (
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
        <div style={{ padding: '14px 20px', borderTop: '1px solid var(--border)', display: 'flex', gap: 10, flexShrink: 0 }}>
          <div style={{ flex: 1 }}><SecondaryButton onClick={onSave}>{saved ? 'บันทึกแล้ว ✓' : 'บันทึกทริป'}</SecondaryButton></div>
          <div style={{ flex: 1.4 }}><PrimaryButton onClick={onBookTrip}>จองทริปนี้</PrimaryButton></div>
        </div>
      </div>
    );
  }

  return (
    <div className="scrollbar-hide" style={{ height: '100%', overflowY: 'auto', padding: '20px 20px 28px', display: 'flex', flexDirection: 'column', gap: 22 }}>
      <div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
          <Sparkles size={18} color="var(--amber)" />
          <span style={{ fontSize: 11, fontWeight: 700, color: 'var(--pine)' }}>ผู้ช่วยวางแผนทริป</span>
        </div>
        <h1 className="font-display" style={{ fontSize: 22, fontWeight: 600 }}>ให้ AI จัดทริปในฝันของคุณ</h1>
        <p style={{ fontSize: 12.5, color: 'var(--ink-soft)', marginTop: 4 }}>ตอบคำถามสั้นๆ แล้วปล่อยให้ AI จัดการที่เหลือ</p>
      </div>

      <div>
        <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 10 }}>อยากไปที่ไหน?</p>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {DESTINATIONS.map((d) => <Chip key={d.id} label={d.name} active={destination === d.name} onClick={() => setDestination(d.name)} />)}
        </div>
      </div>

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <p style={{ fontSize: 13, fontWeight: 700 }}>กี่วัน?</p>
          <p style={{ fontSize: 11.5, color: 'var(--ink-soft)' }}>รวมวันเดินทาง</p>
        </div>
        <Stepper value={days} onChange={setDays} min={1} max={14} />
      </div>

      <div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
          <p style={{ fontSize: 13, fontWeight: 700 }}>งบประมาณโดยประมาณ</p>
          <span className="font-display" style={{ fontSize: 15, fontWeight: 700, color: 'var(--pine)' }}>฿{budget.toLocaleString()}</span>
        </div>
        <input type="range" min={3000} max={50000} step={500} value={budget} onChange={(e) => setBudget(Number(e.target.value))} style={{ width: '100%', accentColor: '#10403D' }} />
        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 10.5, color: 'var(--ink-soft)' }}>
          <span>฿3,000</span><span>฿50,000</span>
        </div>
      </div>

      <div>
        <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 10 }}>สไตล์การเที่ยว</p>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {STYLE_OPTIONS.map((s) => <Chip key={s} label={s} active={styles.includes(s)} onClick={() => toggleStyle(s)} />)}
        </div>
      </div>

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <p style={{ fontSize: 13, fontWeight: 700 }}>จำนวนผู้เดินทาง</p>
        <Stepper value={travelers} onChange={setTravelers} min={1} max={10} />
      </div>

      <PrimaryButton onClick={onGenerate}>ให้ AI จัดแผนให้ ✨</PrimaryButton>
    </div>
  );
}

function TripsScreen({ savedTrips, onStartAi, onSelectTrip }) {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 16 }}>
        <h1 className="font-display" style={{ fontSize: 20, fontWeight: 600 }}>ทริปของฉัน</h1>
        {savedTrips.length === 0 ? (
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

function TripDetailScreen({ trip, onBack }) {
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
          {trip.itinerary.days.map((day, i) => (
            <div key={i}>
              <p style={{ fontSize: 13.5, fontWeight: 700, color: 'var(--pine)', marginBottom: 10 }}>{day.title}</p>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                {day.items.map((it, j) => (
                  <div key={j} style={{ display: 'flex', gap: 12 }}>
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                      <div style={{ width: 8, height: 8, borderRadius: 999, background: 'var(--amber)', marginTop: 5 }} />
                      {j < day.items.length - 1 && <div style={{ width: 1.5, flex: 1, background: 'var(--border)', marginTop: 2 }} />}
                    </div>
                    <div style={{ paddingBottom: 10 }}>
                      <p style={{ fontSize: 11.5, fontWeight: 700, color: 'var(--ink-soft)' }}>{it.time}</p>
                      <p style={{ fontSize: 13, color: 'var(--ink)', marginTop: 1 }}>{it.text}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ))}
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

function ProfileScreen({ onLogout, onWalletTap, onReviewsTap }) {
  const items = [
    { icon: FileText, label: 'การจองของฉัน', onClick: null },
    { icon: Wallet, label: 'กระเป๋าเงิน', onClick: onWalletTap },
    { icon: Ticket, label: 'คูปองของฉัน', onClick: null },
    { icon: Star, label: 'รีวิวของฉัน', onClick: onReviewsTap },
    { icon: Settings, label: 'การตั้งค่า', onClick: null },
    { icon: HelpCircle, label: 'ช่วยเหลือ', onClick: null },
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
              <div key={i} onClick={it.onClick || undefined} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 16px', borderBottom: i < items.length - 1 ? '1px solid var(--border)' : 'none', cursor: it.onClick ? 'pointer' : 'default' }}>
                <Icon size={17} color="var(--pine)" />
                <span style={{ fontSize: 13.5, flex: 1, color: 'var(--ink)' }}>{it.label}</span>
                <ChevronRight size={16} color="var(--ink-soft)" />
              </div>
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

function WalletScreen({ balance, transactions, onBack, onTopUp }) {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="กระเป๋าเงิน" onBack={onBack} />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 20 }}>
        <div style={{ borderRadius: 20, padding: 20, background: 'linear-gradient(135deg, var(--pine) 0%, #1C5C57 100%)', color: '#fff' }}>
          <p style={{ fontSize: 12, opacity: 0.8 }}>ยอดคงเหลือ</p>
          <p className="font-display" style={{ fontSize: 30, fontWeight: 600, margin: '6px 0 16px' }}>฿{balance.toLocaleString()}</p>
          <div style={{ display: 'flex', gap: 10 }}>
            <button onClick={onTopUp} style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, padding: 10, borderRadius: 12, border: 'none', background: 'var(--amber)', color: '#4A2E06', fontWeight: 700, fontSize: 12.5, cursor: 'pointer' }}>
              <ArrowDown size={14} /> เติมเงิน
            </button>
            <button style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, padding: 10, borderRadius: 12, border: '1.5px solid rgba(255,255,255,0.4)', background: 'transparent', color: '#fff', fontWeight: 700, fontSize: 12.5, cursor: 'pointer' }}>
              <ArrowUp size={14} /> ถอนเงิน
            </button>
          </div>
        </div>
        <div>
          <p className="font-display" style={{ fontSize: 15, fontWeight: 600, marginBottom: 12 }}>ธุรกรรมล่าสุด</p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {transactions.map((t) => (
              <div key={t.id} style={{ display: 'flex', alignItems: 'center', gap: 12, border: '1px solid var(--border)', borderRadius: 16, padding: 12 }}>
                <div style={{ width: 38, height: 38, borderRadius: 999, background: t.type === 'in' ? 'var(--pine-pale)' : '#F6DCD6', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
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

function BookingScreen({ item, onBack, onPay }) {
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

function PaymentScreen({ total, method, setMethod, onBack, onConfirm, processing, walletBalance }) {
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
        <PrimaryButton onClick={onConfirm}>ยืนยันการชำระเงิน</PrimaryButton>
      </div>
    </div>
  );
}

function ConfirmationScreen({ bookingNumber, item, onHome }) {
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
      <div style={{ width: '100%', marginTop: 10 }}><PrimaryButton onClick={onHome}>กลับสู่หน้าแรก</PrimaryButton></div>
    </div>
  );
}

function NotificationScreen({ notifications, onBack, onMarkAll, onMarkOne }) {
  const hasUnread = notifications.some((n) => !n.read);
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="การแจ้งเตือน" onBack={onBack} right={
        hasUnread ? <button onClick={onMarkAll} style={{ background: 'none', border: 'none', color: 'var(--pine)', fontSize: 12, fontWeight: 700, cursor: 'pointer' }}>อ่านทั้งหมด</button> : null
      } />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '12px 20px 20px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {notifications.length === 0 && <p style={{ textAlign: 'center', color: 'var(--ink-soft)', fontSize: 13, marginTop: 40 }}>ยังไม่มีการแจ้งเตือน</p>}
        {notifications.map((n) => {
          const Icon = NOTIF_ICON[n.type];
          return (
            <button key={n.id} onClick={() => onMarkOne(n.id)} style={{ display: 'flex', gap: 12, textAlign: 'left', border: '1px solid var(--border)', borderRadius: 16, padding: 14, background: n.read ? 'var(--surface)' : 'var(--pine-pale)', cursor: 'pointer' }}>
              <div style={{ width: 40, height: 40, borderRadius: 999, background: n.read ? 'var(--pine-pale)' : '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, position: 'relative' }}>
                <Icon size={17} color="var(--pine)" />
                {!n.read && <span style={{ position: 'absolute', top: -1, right: -1, width: 9, height: 9, borderRadius: 999, background: 'var(--danger)', border: '2px solid #fff' }} />}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
                  <p style={{ fontSize: 13, fontWeight: n.read ? 600 : 700, color: 'var(--ink)' }}>{n.title}</p>
                  <span style={{ fontSize: 10.5, color: 'var(--ink-soft)', flexShrink: 0 }}>{n.time}</span>
                </div>
                <p style={{ fontSize: 12, color: 'var(--ink-soft)', marginTop: 3, lineHeight: 1.5 }}>{n.message}</p>
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}

function StarPicker({ value, onChange }) {
  return (
    <div style={{ display: 'flex', gap: 8 }}>
      {[1, 2, 3, 4, 5].map((n) => (
        <button key={n} onClick={() => onChange(n)} style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 2 }}>
          <Star size={30} fill={n <= value ? 'var(--amber)' : 'none'} color="var(--amber)" strokeWidth={1.5} />
        </button>
      ))}
    </div>
  );
}

function TextArea({ placeholder, value, onChange }) {
  return (
    <textarea placeholder={placeholder} value={value} onChange={onChange} rows={5}
      style={{ width: '100%', border: '1.5px solid var(--border)', borderRadius: 14, padding: '12px 14px', fontSize: 13.5, fontFamily: "'Plus Jakarta Sans', sans-serif", color: 'var(--ink)', outline: 'none', resize: 'none' }} />
  );
}

function ReviewsScreen({ reviews, onBack, onWriteReview }) {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="รีวิวของฉัน" onBack={onBack} right={
        <button onClick={onWriteReview} style={{ display: 'flex', alignItems: 'center', gap: 4, background: 'none', border: 'none', color: 'var(--pine)', fontSize: 12, fontWeight: 700, cursor: 'pointer' }}>
          <Plus size={14} /> เขียนรีวิว
        </button>
      } />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 12 }}>
        {reviews.length === 0 && (
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 14, textAlign: 'center', padding: 20 }}>
            <div style={{ width: 64, height: 64, borderRadius: 999, background: 'var(--pine-pale)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Star size={26} color="var(--pine)" />
            </div>
            <p style={{ fontSize: 14, fontWeight: 700 }}>คุณยังไม่มีรีวิว</p>
            <p style={{ fontSize: 12, color: 'var(--ink-soft)', maxWidth: 220 }}>แบ่งปันประสบการณ์ของคุณให้นักเดินทางคนอื่น</p>
            <div style={{ width: 160 }}><PrimaryButton onClick={onWriteReview}>เขียนรีวิวแรก</PrimaryButton></div>
          </div>
        )}
        {reviews.map((r) => {
          const Icon = TYPE_ICON[r.itemType];
          return (
            <div key={r.id} style={{ border: '1px solid var(--border)', borderRadius: 18, padding: 16 }}>
              <div style={{ display: 'flex', gap: 12, marginBottom: 10 }}>
                <div style={{ width: 44, height: 44, borderRadius: 12, background: TYPE_GRADIENT[r.itemType], display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  <Icon size={18} color="#fff" />
                </div>
                <div style={{ flex: 1 }}>
                  <p style={{ fontSize: 13.5, fontWeight: 700, color: 'var(--ink)' }}>{r.itemName}</p>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 3 }}>
                    <div style={{ display: 'flex', gap: 1 }}>
                      {[1, 2, 3, 4, 5].map((n) => <Star key={n} size={12} fill={n <= r.rating ? 'var(--amber)' : 'none'} color="var(--amber)" />)}
                    </div>
                    <span style={{ fontSize: 10.5, color: 'var(--ink-soft)' }}>{r.date}</span>
                  </div>
                </div>
              </div>
              <p style={{ fontSize: 12.5, color: 'var(--ink)', lineHeight: 1.6 }}>{r.comment}</p>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function WriteReviewScreen({ selectedItem, onSelectItem, rating, setRating, comment, setComment, onBack, onSubmit }) {
  const canSubmit = selectedItem && rating > 0 && comment.trim().length > 0;
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="เขียนรีวิว" onBack={onBack} />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 20 }}>
        <div>
          <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 10 }}>คุณกำลังรีวิวอะไร?</p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {LISTINGS.map((item) => {
              const Icon = TYPE_ICON[item.type];
              const active = selectedItem && selectedItem.id === item.id;
              return (
                <button key={item.id} onClick={() => onSelectItem(item)} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: 12, borderRadius: 14, border: active ? '2px solid var(--pine)' : '1.5px solid var(--border)', background: active ? 'var(--pine-pale)' : 'var(--surface)', cursor: 'pointer', textAlign: 'left' }}>
                  <div style={{ width: 36, height: 36, borderRadius: 10, background: TYPE_GRADIENT[item.type], display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                    <Icon size={16} color="#fff" />
                  </div>
                  <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--ink)' }}>{item.name}</span>
                </button>
              );
            })}
          </div>
        </div>
        <div>
          <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 10 }}>ให้คะแนนกี่ดาว?</p>
          <StarPicker value={rating} onChange={setRating} />
        </div>
        <div>
          <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 10 }}>เล่าประสบการณ์ของคุณ</p>
          <TextArea placeholder="บอกเล่าประสบการณ์ให้นักเดินทางคนอื่นฟังหน่อย..." value={comment} onChange={(e) => setComment(e.target.value)} />
        </div>
      </div>
      <div style={{ padding: '14px 20px', borderTop: '1px solid var(--border)', flexShrink: 0 }}>
        <PrimaryButton onClick={onSubmit} disabled={!canSubmit}>ส่งรีวิว</PrimaryButton>
      </div>
    </div>
  );
}

/* ---------------------------------------------------------------- */
/*  MAIN APP                                                          */
/* ---------------------------------------------------------------- */

export default function SabaiTravelApp() {
  const [stack, setStack] = useState(['login']);
  const screen = stack[stack.length - 1];
  const push = (s) => setStack((prev) => [...prev, s]);
  const pop = () => setStack((prev) => (prev.length > 1 ? prev.slice(0, -1) : prev));
  const gotoTab = (tab) => setStack([tab]);

  const [loginEmail, setLoginEmail] = useState('');
  const [loginPassword, setLoginPassword] = useState('');

  const [searchQuery, setSearchQuery] = useState('');
  const [searchCategory, setSearchCategory] = useState('ทั้งหมด');
  const [selectedListing, setSelectedListing] = useState(null);

  const [aiDestination, setAiDestination] = useState('เชียงใหม่');
  const [aiDays, setAiDays] = useState(3);
  const [aiBudget, setAiBudget] = useState(10000);
  const [aiStyles, setAiStyles] = useState(['ธรรมชาติ', 'อาหารท้องถิ่น']);
  const [aiTravelers, setAiTravelers] = useState(2);
  const [aiGenerating, setAiGenerating] = useState(false);
  const [aiResult, setAiResult] = useState(null);
  const [aiSaved, setAiSaved] = useState(false);
  const [savedTrips, setSavedTrips] = useState([]);

  const [bookingItem, setBookingItem] = useState(null);
  const [paymentMethod, setPaymentMethod] = useState('promptpay');
  const [processingPayment, setProcessingPayment] = useState(false);
  const [bookingNumber, setBookingNumber] = useState('');

  const [registerForm, setRegisterForm] = useState({
    firstName: '', lastName: '', email: '', phone: '', password: '', confirmPassword: '',
    gender: 'หญิง', dob: '', nationality: 'ไทย', language: 'ไทย',
    budgetLevel: 'ปานกลาง', travelStyles: [], favoriteDestination: '', travelWith: 'คู่รัก',
  });
  const updateRegisterForm = (patch) => setRegisterForm((prev) => ({ ...prev, ...patch }));
  const toggleRegisterStyle = (s) => setRegisterForm((prev) => ({
    ...prev,
    travelStyles: prev.travelStyles.includes(s) ? prev.travelStyles.filter((x) => x !== s) : [...prev.travelStyles, s],
  }));
  const handleFinishRegister = () => gotoTab('home');

  const [walletBalance, setWalletBalance] = useState(4250);
  const [walletTransactions, setWalletTransactions] = useState([
    { id: 1, type: 'in', label: 'เติมเงินผ่านพร้อมเพย์', date: '5 ก.ย. 2569', amount: 2000 },
    { id: 2, type: 'out', label: 'ชำระค่าที่พัก ล้านนา วิว รีสอร์ท', date: '2 ก.ย. 2569', amount: 1490 },
    { id: 3, type: 'in', label: 'เงินคืนจากการยกเลิกจอง', date: '28 ส.ค. 2569', amount: 990 },
    { id: 4, type: 'out', label: 'ชำระค่าอาหาร ข้าวซอยแม่สาย', date: '20 ส.ค. 2569', amount: 120 },
  ]);
  const handleTopUp = () => {
    setWalletBalance((prev) => prev + 1000);
    setWalletTransactions((prev) => [{ id: Date.now(), type: 'in', label: 'เติมเงินผ่านพร้อมเพย์', date: 'วันนี้', amount: 1000 }, ...prev]);
  };

  const [selectedTrip, setSelectedTrip] = useState(null);

  const [notifications, setNotifications] = useState([
    { id: 1, type: 'booking', title: 'ยืนยันการจองสำเร็จ', message: 'การจองที่ ล้านนา วิว รีสอร์ท ของคุณได้รับการยืนยันแล้ว', time: '5 นาทีที่แล้ว', read: false },
    { id: 2, type: 'payment', title: 'ชำระเงินสำเร็จ', message: 'ชำระเงิน ฿1,564 ผ่านพร้อมเพย์เรียบร้อยแล้ว', time: '5 นาทีที่แล้ว', read: false },
    { id: 3, type: 'promotion', title: 'โปรโมชั่นใหม่! ลด 20%', message: 'ใช้โค้ด SABAI20 สำหรับทริปแรกของคุณ ก่อนสิ้นเดือนนี้', time: '2 ชั่วโมงที่แล้ว', read: false },
    { id: 4, type: 'trip', title: 'ทริปของคุณใกล้ถึงแล้ว', message: 'อีก 3 วัน ทริปเชียงใหม่ของคุณจะเริ่มต้น เตรียมตัวให้พร้อม', time: 'เมื่อวาน', read: true },
    { id: 5, type: 'system', title: 'อัปเดตนโยบายความเป็นส่วนตัว', message: 'เราปรับปรุงนโยบายความเป็นส่วนตัวใหม่ อ่านรายละเอียดเพิ่มเติมได้ในการตั้งค่า', time: '3 วันที่แล้ว', read: true },
  ]);
  const unreadCount = notifications.filter((n) => !n.read).length;
  const handleMarkAllRead = () => setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
  const handleMarkOneRead = (id) => setNotifications((prev) => prev.map((n) => (n.id === id ? { ...n, read: true } : n)));

  const [reviews, setReviews] = useState([
    { id: 1, itemName: 'ล้านนา วิว รีสอร์ท', itemType: 'hotel', rating: 5, comment: 'ที่พักสวยมาก บรรยากาศดี พนักงานเป็นกันเอง จะกลับมาพักอีกแน่นอน', date: '28 ส.ค. 2569' },
    { id: 2, itemName: 'ข้าวซอยแม่สาย', itemType: 'restaurant', rating: 4, comment: 'อร่อยมาก แต่คนเยอะไปหน่อยช่วงเที่ยง ควรไปก่อน 11 โมง', date: '15 ส.ค. 2569' },
  ]);
  const [writeReviewItem, setWriteReviewItem] = useState(null);
  const [writeReviewRating, setWriteReviewRating] = useState(0);
  const [writeReviewComment, setWriteReviewComment] = useState('');
  const handleSubmitReview = () => {
    setReviews((prev) => [{ id: Date.now(), itemName: writeReviewItem.name, itemType: writeReviewItem.type, rating: writeReviewRating, comment: writeReviewComment, date: 'วันนี้' }, ...prev]);
    setWriteReviewItem(null);
    setWriteReviewRating(0);
    setWriteReviewComment('');
    pop();
  };

  const toggleAiStyle = (s) => setAiStyles((prev) => (prev.includes(s) ? prev.filter((x) => x !== s) : [...prev, s]));

  const handleGenerateAi = () => {
    setAiGenerating(true);
    setAiSaved(false);
    setTimeout(() => {
      setAiResult(buildItinerary({ destinationName: aiDestination, days: aiDays, budget: aiBudget, styles: aiStyles }));
      setAiGenerating(false);
    }, 1700);
  };
  const handleResetAi = () => setAiResult(null);
  const handleSaveAiTrip = () => {
    setAiSaved(true);
    const total = aiResult.budgetBreakdown.reduce((s, b) => s + b.value, 0);
    setSavedTrips((prev) => [...prev, {
      id: Date.now(), destination: aiDestination, days: aiDays, budget: total,
      travelers: aiTravelers, itinerary: aiResult,
    }]);
  };
  const handleBookAiTrip = () => {
    const total = aiResult.budgetBreakdown.reduce((s, b) => s + b.value, 0);
    setBookingItem({ title: `ทริป ${aiDestination} ${aiDays} วัน`, subtitle: `${aiTravelers} ผู้เดินทาง · จัดโดย AI`, price: total, type: 'trip' });
    push('booking');
  };

  const filteredListings = LISTINGS.filter((l) => {
    const catMatch = searchCategory === 'ทั้งหมด' || TYPE_LABEL[l.type] === searchCategory;
    const qMatch = searchQuery === '' || l.name.includes(searchQuery) || l.location.includes(searchQuery);
    return catMatch && qMatch;
  });

  const handleSelectListing = (item) => { setSelectedListing(item); push('listing-detail'); };
  const handleBookListing = () => {
    setBookingItem({ title: selectedListing.name, subtitle: selectedListing.location, price: selectedListing.price, type: selectedListing.type });
    push('booking');
  };
  const handleQuickAction = (label) => { setSearchCategory(label); setSearchQuery(''); push('search'); };
  const handleDestinationTap = (d) => { setSearchQuery(d.name); setSearchCategory('ทั้งหมด'); push('search'); };

  const handleConfirmPayment = () => {
    setProcessingPayment(true);
    setTimeout(() => {
      setProcessingPayment(false);
      setBookingNumber('SB' + Math.floor(100000 + Math.random() * 900000));
      push('confirmation');
    }, 1600);
  };

  const handleBackToHome = () => {
    setStack(['home']);
    setAiResult(null);
    setAiSaved(false);
    setBookingItem(null);
  };

  const showTabBar = ['home', 'search', 'ai', 'trips', 'profile'].includes(screen);

  let content = null;
  if (screen === 'login') {
    content = <LoginScreen email={loginEmail} setEmail={setLoginEmail} password={loginPassword} setPassword={setLoginPassword} onLogin={() => gotoTab('home')} onGuest={() => gotoTab('home')} onRegister={() => push('register-1')} />;
  } else if (screen === 'register-1') {
    content = <RegisterScreen step={1} form={registerForm} onChange={updateRegisterForm} onToggleStyle={toggleRegisterStyle} onBack={pop} onNext={() => push('register-2')} />;
  } else if (screen === 'register-2') {
    content = <RegisterScreen step={2} form={registerForm} onChange={updateRegisterForm} onToggleStyle={toggleRegisterStyle} onBack={pop} onNext={() => push('register-3')} />;
  } else if (screen === 'register-3') {
    content = <RegisterScreen step={3} form={registerForm} onChange={updateRegisterForm} onToggleStyle={toggleRegisterStyle} onBack={pop} onFinish={handleFinishRegister} />;
  } else if (screen === 'wallet') {
    content = <WalletScreen balance={walletBalance} transactions={walletTransactions} onBack={pop} onTopUp={handleTopUp} />;
  } else if (screen === 'trip-detail') {
    content = <TripDetailScreen trip={selectedTrip} onBack={pop} />;
  } else if (screen === 'notifications') {
    content = <NotificationScreen notifications={notifications} onBack={pop} onMarkAll={handleMarkAllRead} onMarkOne={handleMarkOneRead} />;
  } else if (screen === 'reviews') {
    content = <ReviewsScreen reviews={reviews} onBack={pop} onWriteReview={() => push('write-review')} />;
  } else if (screen === 'write-review') {
    content = (
      <WriteReviewScreen
        selectedItem={writeReviewItem} onSelectItem={setWriteReviewItem}
        rating={writeReviewRating} setRating={setWriteReviewRating}
        comment={writeReviewComment} setComment={setWriteReviewComment}
        onBack={pop} onSubmit={handleSubmitReview}
      />
    );
  } else if (screen === 'home') {
    content = <HomeScreen onSearchTap={() => { setSearchCategory('ทั้งหมด'); setSearchQuery(''); push('search'); }} onQuickAction={handleQuickAction} onAiTap={() => push('ai')} onDestinationTap={handleDestinationTap} onNotificationsTap={() => push('notifications')} unreadCount={unreadCount} />;
  } else if (screen === 'search') {
    content = <SearchScreen query={searchQuery} setQuery={setSearchQuery} category={searchCategory} setCategory={setSearchCategory} results={filteredListings} onSelect={handleSelectListing} />;
  } else if (screen === 'listing-detail') {
    content = <ListingDetailScreen item={selectedListing} onBack={pop} onBook={handleBookListing} />;
  } else if (screen === 'ai') {
    content = (
      <AiPlannerScreen
        destination={aiDestination} setDestination={setAiDestination}
        days={aiDays} setDays={setAiDays}
        budget={aiBudget} setBudget={setAiBudget}
        styles={aiStyles} toggleStyle={toggleAiStyle}
        travelers={aiTravelers} setTravelers={setAiTravelers}
        generating={aiGenerating} result={aiResult}
        onGenerate={handleGenerateAi} onReset={handleResetAi}
        onSave={handleSaveAiTrip} onBookTrip={handleBookAiTrip} saved={aiSaved}
      />
    );
  } else if (screen === 'trips') {
    content = <TripsScreen savedTrips={savedTrips} onStartAi={() => push('ai')} onSelectTrip={(t) => { setSelectedTrip(t); push('trip-detail'); }} />;
  } else if (screen === 'profile') {
    content = <ProfileScreen onLogout={() => setStack(['login'])} onWalletTap={() => push('wallet')} onReviewsTap={() => push('reviews')} />;
  } else if (screen === 'booking') {
    content = <BookingScreen item={bookingItem} onBack={pop} onPay={() => push('payment')} />;
  } else if (screen === 'payment') {
    content = <PaymentScreen total={bookingItem ? Math.round(bookingItem.price * 1.05) : 0} method={paymentMethod} setMethod={setPaymentMethod} onBack={pop} onConfirm={handleConfirmPayment} processing={processingPayment} walletBalance={walletBalance} />;
  } else if (screen === 'confirmation') {
    content = <ConfirmationScreen bookingNumber={bookingNumber} item={bookingItem} onHome={handleBackToHome} />;
  }

  return (
    <div style={{ minHeight: '700px', width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'radial-gradient(circle at 25% 15%, #1C5C57 0%, #0B2422 55%, #071614 100%)', padding: '28px 14px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      <style>{FONT_CSS}</style>
      <div style={{ width: '100%', maxWidth: 390, height: 'min(830px, 92vh)', background: 'var(--paper)', borderRadius: 40, boxShadow: '0 40px 70px -25px rgba(0,0,0,0.55), 0 0 0 9px #0B2422', overflow: 'hidden', display: 'flex', flexDirection: 'column', position: 'relative' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px 24px 4px', fontSize: 12, fontWeight: 700, color: 'var(--ink)', flexShrink: 0 }}>
          <span>9:41</span>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <Wifi size={13} />
            <div style={{ width: 22, height: 11, border: '1.4px solid var(--ink)', borderRadius: 3, position: 'relative', display: 'flex', alignItems: 'center', padding: 1 }}>
              <div style={{ width: '75%', height: '100%', background: 'var(--ink)', borderRadius: 1 }} />
            </div>
          </div>
        </div>
        <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
          {content}
        </div>
        {showTabBar && <TabBar active={screen} onChange={gotoTab} />}
      </div>
    </div>
  );
}
