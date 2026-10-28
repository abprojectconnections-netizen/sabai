import { useEffect, useMemo, useState } from 'react';
import { loadConfig } from '../config/env';
import { createRepository } from '../repositories';
import { validateAccountSnapshot } from '../repositories/contract';
import { FONT_CSS } from '../theme/fontCss';
import { EnvBadge } from './EnvBadge';
import SabaiTravelApp from './SabaiTravelApp';

const page = { minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24, background: 'radial-gradient(circle at 25% 15%, #1C5C57 0%, #0B2422 55%, #071614 100%)', fontFamily: "'Plus Jakarta Sans', sans-serif" };
const card = { width: '100%', maxWidth: 390, borderRadius: 28, background: 'var(--surface)', color: 'var(--ink)', padding: 28, textAlign: 'center', boxShadow: '0 30px 60px -20px rgba(0,0,0,0.5)' };

function Shell({ children, config }) {
  return (
    <div style={page}>
      <style>{FONT_CSS}</style>
      {config && <EnvBadge config={config} />}
      <div style={card}>{children}</div>
    </div>
  );
}

export function ConfigErrorScreen({ problems }) {
  return (
    <Shell>
      <h1 className="font-display" style={{ fontSize: 20, margin: '0 0 8px' }}>ตั้งค่าระบบไม่ถูกต้อง</h1>
      <p style={{ fontSize: 13, color: 'var(--ink-soft)', margin: '0 0 12px' }}>แอปไม่เริ่มทำงานเพื่อความปลอดภัย กรุณาแก้ไขการตั้งค่า environment</p>
      <ul role="alert" style={{ textAlign: 'left', fontSize: 12.5, lineHeight: 1.6, color: 'var(--danger)', paddingLeft: 18, margin: 0 }}>
        {problems.map((p) => <li key={p}>{p}</li>)}
      </ul>
    </Shell>
  );
}

/**
 * Entry gate: validates configuration, selects the repository (mock / BETA / PRODUCTION),
 * loads the account snapshot with loading, error and retry states, then renders the app.
 */
export default function BootGate({ configOverride, repositoryOverride }) {
  const parsed = useMemo(() => {
    if (configOverride) return { config: configOverride };
    try { return { config: loadConfig() }; } catch (e) { return { problems: e.problems || [e.message] }; }
  }, [configOverride]);
  const repo = useMemo(() => (parsed.config ? (repositoryOverride || createRepository(parsed.config)) : null), [parsed, repositoryOverride]);
  const [state, setState] = useState({ status: 'loading' });
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    if (!repo) return undefined;
    let cancelled = false;
    setState({ status: 'loading' });
    repo.loadAccountSnapshot().then((snapshot) => {
      if (cancelled) return;
      const problems = validateAccountSnapshot(snapshot);
      if (problems.length) setState({ status: 'error', message: `ข้อมูลเริ่มต้นไม่ถูกต้อง (${problems[0]})` });
      else setState({ status: 'ready', snapshot });
    }).catch(() => { if (!cancelled) setState({ status: 'error', message: 'โหลดข้อมูลเริ่มต้นไม่สำเร็จ' }); });
    return () => { cancelled = true; };
  }, [repo, attempt]);

  if (parsed.problems) return <ConfigErrorScreen problems={parsed.problems} />;
  if (state.status === 'loading') {
    return (
      <Shell config={parsed.config}>
        <p role="status" style={{ fontSize: 14, fontWeight: 700, margin: 0 }}>กำลังโหลด Sabai...</p>
      </Shell>
    );
  }
  if (state.status === 'error') {
    return (
      <Shell config={parsed.config}>
        <p role="alert" style={{ fontSize: 14, fontWeight: 700, margin: '0 0 6px' }}>{state.message}</p>
        <p style={{ fontSize: 12.5, color: 'var(--ink-soft)', margin: '0 0 16px' }}>ตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง</p>
        <button onClick={() => setAttempt((n) => n + 1)} style={{ padding: '12px 22px', borderRadius: 14, border: 'none', background: 'var(--pine)', color: '#fff', fontWeight: 700, cursor: 'pointer' }}>ลองอีกครั้ง</button>
      </Shell>
    );
  }
  return (
    <>
      <EnvBadge config={parsed.config} />
      <SabaiTravelApp repo={repo} snapshot={state.snapshot} config={parsed.config} />
    </>
  );
}
