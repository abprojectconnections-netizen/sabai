import { Calendar, Lock, Mail, Phone, Sparkles, User } from 'lucide-react';
import { Chip, PrimaryButton, StepDots, TextField, TopBar } from '../../components/ui';
import { BUDGET_LEVELS, DESTINATIONS, STYLE_OPTIONS, TRAVEL_WITH_OPTIONS } from '../../data/catalog';

export function LoginScreen({ email, setEmail, password, setPassword, onLogin, onGuest, onRegister, error = '', busy = false }) {
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
        {error && <p role="alert" style={{ fontSize: 12.5, color: 'var(--danger)', lineHeight: 1.5 }}>{error}</p>}
        <div style={{ marginTop: 4 }}><PrimaryButton onClick={onLogin} disabled={busy}>{busy ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบ'}</PrimaryButton></div>
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

export function RegisterScreen({ step, form, onChange, onToggleStyle, onBack, onNext, onFinish, error = '', busy = false }) {
  const step1Valid = form.firstName && form.lastName && form.email.includes('@') && form.password.length >= 8 && form.password === form.confirmPassword;
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
            {form.password && form.password.length < 8 && (
              <p style={{ fontSize: 11.5, color: 'var(--danger)' }}>รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร</p>
            )}
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
        {error && <p role="alert" style={{ fontSize: 12.5, color: 'var(--danger)', lineHeight: 1.5, marginBottom: 10 }}>{error}</p>}
        {step < 3 ? (
          <PrimaryButton onClick={onNext} disabled={step === 1 && !step1Valid}>ถัดไป</PrimaryButton>
        ) : (
          <PrimaryButton onClick={onFinish} disabled={busy}>{busy ? 'กำลังสร้างบัญชี...' : 'เริ่มต้นใช้งาน 🎉'}</PrimaryButton>
        )}
      </div>
    </div>
  );
}
