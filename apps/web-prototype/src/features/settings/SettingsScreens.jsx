import { useState } from 'react';
import { Banknote, Bell, ChevronRight, Globe, KeyRound, Lock, Palette, Trash2 } from 'lucide-react';
import { Chip, PrimaryButton, SecondaryButton, TextField, Toggle, TopBar } from '../../components/ui';

export function SettingRow({ icon: Icon, label, hint, right, onClick, last }) {
  const inner = (
    <>
      <Icon size={17} color="var(--pine)" style={{ flexShrink: 0 }} />
      <div style={{ flex: 1, minWidth: 0, textAlign: 'left' }}>
        <p style={{ fontSize: 13.5, color: 'var(--ink)' }}>{label}</p>
        {hint && <p style={{ fontSize: 11, color: 'var(--ink-soft)', marginTop: 1 }}>{hint}</p>}
      </div>
      {right}
    </>
  );
  const style = { display: 'flex', alignItems: 'center', gap: 12, padding: '13px 16px', borderBottom: last ? 'none' : '1px solid var(--border)', width: '100%', background: 'none', borderTop: 'none', borderLeft: 'none', borderRight: 'none' };
  return onClick
    ? <button onClick={onClick} style={{ ...style, cursor: 'pointer' }}>{inner}</button>
    : <div style={style}>{inner}</div>;
}

export function SettingsScreen({ settings, onChange, onChangePassword, onDeleteAccount, onBack }) {
  const [confirmDelete, setConfirmDelete] = useState(false);
  const group = (title, children) => (
    <div>
      <p style={{ fontSize: 12, fontWeight: 700, color: 'var(--ink-soft)', marginBottom: 8, paddingLeft: 4 }}>{title}</p>
      <div style={{ border: '1px solid var(--border)', borderRadius: 18, overflow: 'hidden', background: 'var(--surface)' }}>{children}</div>
    </div>
  );
  const chips = (key, options) => (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, padding: '0 16px 14px' }}>
      {options.map((o) => <Chip key={o} label={o} active={settings[key] === o} onClick={() => onChange({ [key]: o })} />)}
    </div>
  );
  const notif = (key, label, hint, last) => (
    <SettingRow key={key} icon={Bell} label={label} hint={hint} last={last}
      right={<Toggle checked={settings.notif[key]} label={label} onChange={(v) => onChange({ notif: { ...settings.notif, [key]: v } })} />} />
  );
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden', position: 'relative' }}>
      <TopBar title="การตั้งค่า" onBack={onBack} />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 22 }}>
        {group('ทั่วไป', (
          <>
            <SettingRow icon={Globe} label="ภาษา" last />
            {chips('language', ['ไทย', 'English', '中文', '日本語'])}
            <SettingRow icon={Banknote} label="สกุลเงิน" last />
            {chips('currency', ['THB ฿', 'USD $', 'JPY ¥'])}
            <SettingRow icon={Palette} label="ธีม" last />
            {chips('theme', ['สว่าง', 'มืด', 'ตามระบบ'])}
          </>
        ))}
        {group('การแจ้งเตือน', (
          <>
            {notif('push', 'การแจ้งเตือนในแอป', 'การจอง การชำระเงิน และข่าวสารบัญชี')}
            {notif('email', 'อีเมล', 'ใบยืนยันการจองและใบเสร็จ')}
            {notif('trip', 'เตือนก่อนเดินทาง', 'แจ้งเตือนล่วงหน้า 3 วัน')}
            {notif('promo', 'โปรโมชั่นและคูปอง', 'ข้อเสนอพิเศษที่เหมาะกับคุณ', true)}
          </>
        ))}
        {group('ความปลอดภัย', (
          <SettingRow icon={KeyRound} label="เปลี่ยนรหัสผ่าน" onClick={onChangePassword} last right={<ChevronRight size={16} color="var(--ink-soft)" />} />
        ))}
        <button onClick={() => setConfirmDelete(true)} style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, padding: 14, borderRadius: 16, border: '1.5px solid var(--danger)', background: 'transparent', color: 'var(--danger)', fontWeight: 700, fontSize: 13.5, cursor: 'pointer' }}>
          <Trash2 size={16} /> ลบบัญชี
        </button>
      </div>
      {confirmDelete && (
        <div role="dialog" aria-modal="true" aria-label="ยืนยันการลบบัญชี" style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 28, zIndex: 40 }}>
          <div style={{ background: 'var(--surface)', borderRadius: 20, padding: 22, width: '100%', display: 'flex', flexDirection: 'column', gap: 14 }}>
            <p className="font-display" style={{ fontSize: 17, fontWeight: 600 }}>ลบบัญชีถาวร?</p>
            <p style={{ fontSize: 12.5, color: 'var(--ink-soft)', lineHeight: 1.6 }}>ข้อมูลทริป การจอง คูปอง และยอด Sabai Wallet จะถูกลบและกู้คืนไม่ได้</p>
            <div style={{ display: 'flex', gap: 10 }}>
              <div style={{ flex: 1 }}><SecondaryButton onClick={() => setConfirmDelete(false)}>ยกเลิก</SecondaryButton></div>
              <button onClick={onDeleteAccount} style={{ flex: 1, padding: 15, borderRadius: 16, border: 'none', background: 'var(--danger)', color: '#fff', fontWeight: 700, fontSize: 15, cursor: 'pointer' }}>ลบบัญชี</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export function ChangePasswordScreen({ onBack, onSubmit }) {
  const [current, setCurrent] = useState('');
  const [next, setNext] = useState('');
  const [confirm, setConfirm] = useState('');
  const errors = [];
  if (next && next.length < 8) errors.push('รหัสผ่านใหม่ต้องมีอย่างน้อย 8 ตัวอักษร');
  if (next && current && next === current) errors.push('รหัสผ่านใหม่ต้องไม่ซ้ำกับรหัสผ่านเดิม');
  if (confirm && next !== confirm) errors.push('ยืนยันรหัสผ่านไม่ตรงกัน');
  const valid = current && next.length >= 8 && next === confirm && next !== current;
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="เปลี่ยนรหัสผ่าน" onBack={onBack} />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 14 }}>
        <TextField icon={Lock} type="password" placeholder="รหัสผ่านปัจจุบัน" value={current} onChange={(e) => setCurrent(e.target.value)} />
        <TextField icon={Lock} type="password" placeholder="รหัสผ่านใหม่ (อย่างน้อย 8 ตัว)" value={next} onChange={(e) => setNext(e.target.value)} />
        <TextField icon={Lock} type="password" placeholder="ยืนยันรหัสผ่านใหม่" value={confirm} onChange={(e) => setConfirm(e.target.value)} />
        {errors.map((e) => <p key={e} style={{ fontSize: 11.5, color: 'var(--danger)' }}>{e}</p>)}
      </div>
      <div style={{ padding: '14px 20px', borderTop: '1px solid var(--border)', flexShrink: 0 }}>
        <PrimaryButton onClick={onSubmit} disabled={!valid}>บันทึกรหัสผ่านใหม่</PrimaryButton>
      </div>
    </div>
  );
}
