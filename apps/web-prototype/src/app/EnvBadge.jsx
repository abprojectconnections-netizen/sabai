/** Shows which environment/API this build talks to. Hidden in PRODUCTION. */
export function EnvBadge({ config }) {
  if (config.isProduction) return null;
  const label = `${config.appEnv.toUpperCase()} · ${config.apiMode === 'mock' ? 'Mock API' : `${config.apiMode} API`} · v${config.version}${config.buildId !== 'local' ? ` · ${config.buildId}` : ''}`;
  return (
    <div role="status" data-testid="env-badge" style={{ position: 'fixed', top: 8, left: 8, zIndex: 100, padding: '4px 10px', borderRadius: 999, background: 'rgba(0,0,0,0.55)', color: '#fff', fontSize: 11, fontWeight: 700, fontFamily: 'system-ui, sans-serif', letterSpacing: 0.2, pointerEvents: 'none' }}>
      {label}
    </div>
  );
}
