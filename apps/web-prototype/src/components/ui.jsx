import { ArrowLeft, Briefcase, Home, Minus, Plus, Search, Sparkles, Star, User, Users } from 'lucide-react';

export function TopBar({ title, onBack, right }) {
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

export function TabBar({ active, onChange }) {
  const tabs = [
    { id: 'home', label: 'หน้าแรก', icon: Home },
    { id: 'search', label: 'ค้นหา', icon: Search },
    { id: 'ai', label: 'AI', icon: Sparkles },
    { id: 'trips', label: 'ทริป', icon: Briefcase },
    { id: 'community', label: 'ชุมชน', icon: Users },
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

export function Chip({ label, active, onClick }) {
  return (
    <button onClick={onClick} style={{
      padding: '8px 16px', borderRadius: 999, fontSize: 13, fontWeight: 600, whiteSpace: 'nowrap',
      border: active ? '1.5px solid var(--pine)' : '1.5px solid var(--border)',
      background: active ? 'var(--pine)' : 'var(--surface)',
      color: active ? '#fff' : 'var(--ink)', cursor: 'pointer',
    }}>{label}</button>
  );
}

export function Stepper({ value, onChange, min = 1, max = 14 }) {
  const btn = { width: 36, height: 36, borderRadius: 999, border: '1.5px solid var(--border)', background: 'var(--surface)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' };
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
      <button onClick={() => onChange(Math.max(min, value - 1))} style={btn}><Minus size={16} color="var(--ink)" /></button>
      <span className="font-display" style={{ fontSize: 20, fontWeight: 600, minWidth: 28, textAlign: 'center' }}>{value}</span>
      <button onClick={() => onChange(Math.min(max, value + 1))} style={btn}><Plus size={16} color="var(--ink)" /></button>
    </div>
  );
}

export function RatingStars({ value }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 3 }}>
      <Star size={13} fill="var(--amber)" color="var(--amber)" />
      <span style={{ fontSize: 12, fontWeight: 700, color: 'var(--ink)' }}>{value}</span>
    </div>
  );
}

export function TextField({ icon: Icon, type = 'text', placeholder, value, onChange, disabled }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, border: '1.5px solid var(--border)', borderRadius: 14, padding: '12px 14px', background: 'var(--surface)', opacity: disabled ? 0.55 : 1 }}>
      {Icon && <Icon size={18} color="var(--ink-soft)" />}
      <input type={type} placeholder={placeholder} value={value} onChange={onChange} disabled={disabled}
        style={{ border: 'none', outline: 'none', flex: 1, fontSize: 14, fontFamily: "'Plus Jakarta Sans', sans-serif", background: 'transparent', color: 'var(--ink)', width: '100%' }} />
    </div>
  );
}

export function PrimaryButton({ children, onClick, disabled }) {
  return (
    <button onClick={onClick} disabled={disabled} style={{ width: '100%', padding: '15px', borderRadius: 16, border: 'none', background: disabled ? 'var(--disabled)' : 'var(--pine)', color: '#fff', fontWeight: 700, fontSize: 15, cursor: disabled ? 'default' : 'pointer' }}>
      {children}
    </button>
  );
}

export function SecondaryButton({ children, onClick }) {
  return (
    <button onClick={onClick} style={{ width: '100%', padding: '15px', borderRadius: 16, border: '1.5px solid var(--pine)', background: 'transparent', color: 'var(--pine)', fontWeight: 700, fontSize: 15, cursor: 'pointer' }}>
      {children}
    </button>
  );
}

export function IconCircle({ icon: Icon, bg, color, onClick, label }) {
  return (
    <button onClick={onClick} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, background: 'transparent', border: 'none', cursor: 'pointer' }}>
      <div style={{ width: 52, height: 52, borderRadius: 18, background: bg, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Icon size={22} color={color} />
      </div>
      <span style={{ fontSize: 11, fontWeight: 600, color: 'var(--ink)' }}>{label}</span>
    </button>
  );
}

export function StepDots({ current, total }) {
  return (
    <div style={{ display: 'flex', gap: 6 }}>
      {Array.from({ length: total }).map((_, i) => (
        <div key={i} style={{ flex: 1, height: 4, borderRadius: 999, background: i < current ? 'var(--pine)' : 'var(--border)' }} />
      ))}
    </div>
  );
}

export function Toggle({ checked, onChange, label }) {
  return (
    <button role="switch" aria-checked={checked} aria-label={label} onClick={() => onChange(!checked)}
      style={{ width: 46, height: 28, borderRadius: 999, border: 'none', padding: 3, cursor: 'pointer', flexShrink: 0, background: checked ? 'var(--pine)' : 'var(--disabled)', display: 'flex', justifyContent: checked ? 'flex-end' : 'flex-start', transition: 'background .2s' }}>
      <span style={{ width: 22, height: 22, borderRadius: 999, background: '#fff', display: 'block' }} />
    </button>
  );
}

export function Toast({ message }) {
  if (!message) return null;
  return (
    <div role="status" className="fade-up" style={{ position: 'absolute', left: 20, right: 20, bottom: 92, zIndex: 50, background: 'var(--ink)', color: 'var(--paper)', padding: '12px 16px', borderRadius: 14, fontSize: 12.5, fontWeight: 600, textAlign: 'center', boxShadow: '0 10px 24px -8px rgba(0,0,0,0.4)' }}>
      {message}
    </div>
  );
}

export function EmptyState({ icon: Icon, title, hint, action }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12, textAlign: 'center', padding: '40px 20px' }}>
      <div style={{ width: 60, height: 60, borderRadius: 999, background: 'var(--pine-pale)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Icon size={24} color="var(--pine)" />
      </div>
      <p style={{ fontSize: 14, fontWeight: 700, color: 'var(--ink)' }}>{title}</p>
      {hint && <p style={{ fontSize: 12, color: 'var(--ink-soft)', maxWidth: 240, lineHeight: 1.6 }}>{hint}</p>}
      {action}
    </div>
  );
}
