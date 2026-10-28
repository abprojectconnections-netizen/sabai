export const TH_MONTHS = ['มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'];

export const TH_MONTHS_SHORT = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];

export const TH_DOW_SHORT = ['อา.', 'จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.'];

export const TH_DOW_FULL = ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'];

export const pad2 = (n) => String(n).padStart(2, '0');

export const toISO = (d) => `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;

export const fromISO = (s) => { const [y, m, d] = s.split('-').map(Number); return new Date(y, m - 1, d); };

export const addDaysISO = (s, n) => { const d = fromISO(s); d.setDate(d.getDate() + n); return toISO(d); };

export const diffDays = (a, b) => Math.round((fromISO(b) - fromISO(a)) / 86400000);

export const todayISO = () => toISO(new Date());

export const monthStartISO = (s) => `${s.slice(0, 7)}-01`;

export const addMonthsISO = (s, n) => { const d = fromISO(monthStartISO(s)); d.setMonth(d.getMonth() + n); return toISO(d); };

export const fmtDate = (s, { dow = false } = {}) => {
  const d = fromISO(s);
  return `${dow ? `${TH_DOW_SHORT[d.getDay()]} ` : ''}${d.getDate()} ${TH_MONTHS_SHORT[d.getMonth()]} ${d.getFullYear() + 543}`;
};

export const fmtRange = (a, b) => {
  if (a === b) return fmtDate(a);
  const da = fromISO(a); const db = fromISO(b);
  if (da.getMonth() === db.getMonth() && da.getFullYear() === db.getFullYear()) return `${da.getDate()}–${db.getDate()} ${TH_MONTHS_SHORT[db.getMonth()]} ${db.getFullYear() + 543}`;
  return `${da.getDate()} ${TH_MONTHS_SHORT[da.getMonth()]} – ${db.getDate()} ${TH_MONTHS_SHORT[db.getMonth()]} ${db.getFullYear() + 543}`;
};

export const relativeDay = (s) => {
  const n = diffDays(todayISO(), s);
  if (n === 0) return 'วันนี้';
  if (n === 1) return 'พรุ่งนี้';
  return fmtDate(s, { dow: true });
};

export const toMins = (hhmm) => { const [h, m] = hhmm.split(':').map(Number); return h * 60 + m; };

export const fmtMins = (m) => `${pad2(Math.floor(m / 60) % 24)}:${pad2(m % 60)}`;

export const fmtDuration = (m) => `${Math.floor(m / 60)} ชม. ${pad2(m % 60)} น.`;

export const hashStr = (str) => { let h = 7; for (let i = 0; i < str.length; i += 1) h = (h * 31 + str.charCodeAt(i)) >>> 0; return h; };

export const atLocal = (iso, hhmm) => { const d = fromISO(iso); const m = toMins(hhmm); d.setHours(Math.floor(m / 60), m % 60, 0, 0); return d.getTime(); };

export const fmtUntil = (ms, now) => {
  const mins = Math.round((ms - now) / 60000);
  if (mins <= 0) return 'ถึงเวลาแล้ว';
  if (mins < 60) return `อีก ${mins} นาที`;
  if (mins < 1440) return `อีก ${Math.floor(mins / 60)} ชม. ${mins % 60} น.`;
  return `อีก ${Math.floor(mins / 1440)} วัน ${Math.floor((mins % 1440) / 60)} ชม.`;
};
