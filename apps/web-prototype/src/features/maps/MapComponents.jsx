import { useState } from 'react';
import { Map as MapIcon, MapPin, Navigation, Route as RouteIcon, X } from 'lucide-react';
import { MAX_WAYPOINTS, TRAVEL_MODES, mapsDirUrl, mapsEmbedUrl, mapsSearchUrl, placeQuery } from '../../domain/maps';

export function MapLink({ href, icon: Icon, label, ariaLabel, solid }) {
  return (
    <a href={href} target="_blank" rel="noopener noreferrer" aria-label={ariaLabel || label}
      style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '6px 12px', borderRadius: 999, fontSize: 11.5, fontWeight: 700, textDecoration: 'none', border: '1.5px solid var(--pine)', background: solid ? 'var(--pine)' : 'transparent', color: solid ? '#fff' : 'var(--pine)' }}>
      <Icon size={13} /> {label}
    </a>
  );
}

export function MapPreview({ query, onClose }) {
  return (
    <div style={{ border: '1px solid var(--border)', borderRadius: 16, overflow: 'hidden', background: 'var(--surface)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '10px 12px' }}>
        <MapPin size={15} color="var(--pine)" />
        <span style={{ flex: 1, minWidth: 0, fontSize: 12.5, fontWeight: 700, color: 'var(--ink)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{query}</span>
        <button onClick={onClose} aria-label="ปิดแผนที่" style={{ background: 'none', border: 'none', cursor: 'pointer', display: 'flex', padding: 4 }}><X size={16} color="var(--ink-soft)" /></button>
      </div>
      <iframe title={`แผนที่ ${query}`} src={mapsEmbedUrl(query)} loading="lazy" referrerPolicy="no-referrer-when-downgrade" style={{ width: '100%', height: 200, border: 0, display: 'block', background: 'var(--muted-bg)' }} />
      <div style={{ padding: '10px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
        <span style={{ fontSize: 11, color: 'var(--ink-soft)' }}>หากแผนที่ไม่แสดง ให้เปิดใน Google Maps</span>
        <MapLink href={mapsSearchUrl(query)} icon={MapIcon} label="เปิดแอป" ariaLabel={`เปิด ${query} ใน Google Maps`} />
      </div>
    </div>
  );
}

export function TripItinerary({ itinerary, destination }) {
  const [mode, setMode] = useState('driving');
  const [focus, setFocus] = useState(null);
  const hasPlaces = itinerary.days.some((d) => d.items.some((it) => it.place));
  return (
    <>
      {hasPlaces && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <Navigation size={16} color="var(--pine)" />
            <p className="font-display" style={{ fontSize: 15, fontWeight: 600 }}>นำทางด้วย Google Maps</p>
          </div>
          <p style={{ fontSize: 11.5, color: 'var(--ink-soft)', lineHeight: 1.6 }}>เลือกวิธีเดินทาง แล้วกด "นำทาง" ที่แต่ละจุด หรือดูเส้นทางทั้งวัน ระบบจะเปิด Google Maps ในแท็บใหม่</p>
          <div role="radiogroup" aria-label="วิธีเดินทาง" className="scrollbar-hide" style={{ display: 'flex', gap: 8, overflowX: 'auto' }}>
            {TRAVEL_MODES.map((m) => (
              <button key={m.id} role="radio" aria-checked={mode === m.id} onClick={() => setMode(m.id)}
                style={{ padding: '7px 14px', borderRadius: 999, fontSize: 12, fontWeight: 600, whiteSpace: 'nowrap', cursor: 'pointer', border: mode === m.id ? '1.5px solid var(--pine)' : '1.5px solid var(--border)', background: mode === m.id ? 'var(--pine)' : 'var(--surface)', color: mode === m.id ? '#fff' : 'var(--ink)' }}>
                {m.label}
              </button>
            ))}
          </div>
          {focus && <MapPreview query={focus} onClose={() => setFocus(null)} />}
        </div>
      )}
      {itinerary.days.map((day, i) => {
        const stops = day.items.filter((it) => it.place).map((it) => placeQuery(it.place, destination));
        const canRoute = stops.length >= 2;
        const routeUrl = canRoute ? mapsDirUrl({ origin: stops[0], destination: stops[stops.length - 1], waypoints: stops.slice(1, -1).slice(0, MAX_WAYPOINTS), mode }) : null;
        return (
          <div key={i}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, marginBottom: 10 }}>
              <p style={{ fontSize: 13.5, fontWeight: 700, color: 'var(--pine)' }}>{day.title}</p>
              {canRoute && <MapLink href={routeUrl} icon={RouteIcon} label={`เส้นทางทั้งวัน (${stops.length} จุด)`} ariaLabel={`ดูเส้นทางทั้งวัน ${day.title}`} />}
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {day.items.map((it, j) => {
                const query = it.place ? placeQuery(it.place, destination) : null;
                // จุดแรกของทริปใช้ตำแหน่งปัจจุบันเป็นต้นทาง จุดถัดไปเริ่มจากจุดก่อนหน้าในวันเดียวกัน
                const prev = day.items.slice(0, j).reverse().find((x) => x.place);
                const navUrl = query ? mapsDirUrl({ origin: prev ? placeQuery(prev.place, destination) : undefined, destination: query, mode }) : null;
                return (
                  <div key={j} style={{ display: 'flex', gap: 12 }}>
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                      <div style={{ width: 8, height: 8, borderRadius: 999, background: 'var(--amber)', marginTop: 5 }} />
                      {j < day.items.length - 1 && <div style={{ width: 1.5, flex: 1, background: 'var(--border)', marginTop: 2 }} />}
                    </div>
                    <div style={{ paddingBottom: 10, flex: 1, minWidth: 0 }}>
                      <p style={{ fontSize: 11.5, fontWeight: 700, color: 'var(--ink-soft)' }}>{it.time}</p>
                      <p style={{ fontSize: 13, color: 'var(--ink)', marginTop: 1 }}>{it.text}</p>
                      {query && (
                        <div style={{ display: 'flex', gap: 8, marginTop: 8, flexWrap: 'wrap' }}>
                          <MapLink href={navUrl} icon={Navigation} label="นำทาง" ariaLabel={`นำทางไป ${it.place}`} solid />
                          <button onClick={() => setFocus(query)} aria-label={`ดูแผนที่ ${it.place}`}
                            style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '6px 12px', borderRadius: 999, fontSize: 11.5, fontWeight: 700, cursor: 'pointer', border: '1.5px solid var(--border)', background: 'transparent', color: 'var(--ink)' }}>
                            <MapIcon size={13} /> ดูแผนที่
                          </button>
                        </div>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        );
      })}
    </>
  );
}
