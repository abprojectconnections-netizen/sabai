import { TopBar } from '../../components/ui';
import { NOTIF_ICON } from '../../ui/typeMeta';

export function NotificationScreen({ notifications, onBack, onMarkAll, onMarkOne }) {
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
