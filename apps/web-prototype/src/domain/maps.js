export const TRAVEL_MODES = [
  { id: 'driving', label: 'ขับรถ' },
  { id: 'two-wheeler', label: 'มอเตอร์ไซค์' },
  { id: 'transit', label: 'ขนส่งสาธารณะ' },
  { id: 'walking', label: 'เดิน' },
];

export const MAPS_BASE = 'https://www.google.com/maps';

export const placeQuery = (place, destination) => (destination && !place.includes(destination) ? `${place} ${destination}` : place);

export const mapsSearchUrl = (query) => `${MAPS_BASE}/search/?api=1&query=${encodeURIComponent(query)}`;

// ปลายทางเดียว: ถ้าไม่ระบุต้นทาง Google Maps จะใช้ตำแหน่งปัจจุบันของผู้ใช้
export const mapsDirUrl = ({ origin, destination, waypoints = [], mode = 'driving' }) => {
  const params = [`api=1`, `destination=${encodeURIComponent(destination)}`, `travelmode=${mode}`];
  if (origin) params.push(`origin=${encodeURIComponent(origin)}`);
  if (waypoints.length) params.push(`waypoints=${waypoints.map(encodeURIComponent).join('%7C')}`);
  return `${MAPS_BASE}/dir/?${params.join('&')}`;
};

export const mapsEmbedUrl = (query) => `${MAPS_BASE}?q=${encodeURIComponent(query)}&output=embed&hl=th`;

// Google Maps รองรับจุดแวะสูงสุด 9 จุดต่อเส้นทาง
export const MAX_WAYPOINTS = 9;
