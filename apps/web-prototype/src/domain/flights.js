import { fmtMins, fromISO, hashStr, toMins } from './dates';

export const AIRLINES = [
  { code: 'TG', name: 'Thai Airways', color: '#5B2C83', factor: 1.35, bag: 'สัมภาระ 20 กก. + อาหารว่าง', deps: ['07:00', '12:30', '18:15'] },
  { code: 'PG', name: 'Bangkok Airways', color: '#00539B', factor: 1.2, bag: 'สัมภาระ 20 กก.', deps: ['08:20', '14:10', '19:40'] },
  { code: 'FD', name: 'Thai AirAsia', color: '#C8102E', factor: 0.8, bag: 'ถือขึ้นเครื่อง 7 กก.', deps: ['06:15', '10:45', '16:30', '20:50'] },
  { code: 'SL', name: 'Thai Lion Air', color: '#A4342C', factor: 0.78, bag: 'ถือขึ้นเครื่อง 7 กก.', deps: ['06:55', '13:05', '21:10'] },
  { code: 'DD', name: 'Nok Air', color: '#B7791F', factor: 0.86, bag: 'สัมภาระ 15 กก.', deps: ['09:10', '15:25'] },
  { code: 'VZ', name: 'Thai Vietjet', color: '#B5651D', factor: 0.82, bag: 'ถือขึ้นเครื่อง 7 กก.', deps: ['07:35', '17:05'] },
];

export const AIRLINE_BY_CODE = Object.fromEntries(AIRLINES.map((a) => [a.code, a]));

export const ROUTES = {
  เชียงใหม่: { code: 'CNX', airport: 'เชียงใหม่', mins: 75, base: 1700 },
  ภูเก็ต: { code: 'HKT', airport: 'ภูเก็ต', mins: 90, base: 2300 },
  กระบี่: { code: 'KBV', airport: 'กระบี่', mins: 85, base: 2100 },
  เกาะสมุย: { code: 'USM', airport: 'เกาะสมุย', mins: 80, base: 2700 },
  ปาย: { code: 'CNX', airport: 'เชียงใหม่ (ต่อรถไปปาย)', mins: 75, base: 1700 },
  กรุงเทพฯ: { code: 'BKK', airport: 'กรุงเทพฯ (สุวรรณภูมิ)', mins: 75, base: 1700 },
};

export const BKK = { code: 'BKK', airport: 'กรุงเทพฯ (สุวรรณภูมิ)' };

export const CNX = { code: 'CNX', airport: 'เชียงใหม่' };

export function flightRouteFor(destination) {
  const r = ROUTES[destination] || { code: 'DST', airport: destination, mins: 80, base: 2000 };
  const dest = { code: r.code, airport: r.airport };
  // ปลายทางกรุงเทพฯ ให้เดินทางมาจากเชียงใหม่
  const origin = destination === 'กรุงเทพฯ' ? CNX : BKK;
  return { origin, dest, mins: r.mins, base: r.base };
}

export function genFlights({ origin, dest, mins, base }, dateISO) {
  const dow = fromISO(dateISO).getDay();
  const weekend = dow === 5 || dow === 6 || dow === 0;
  const list = [];
  AIRLINES.forEach((a) => {
    a.deps.forEach((dep) => {
      const h = hashStr(`${a.code}${origin.code}${dest.code}${dateISO}${dep}`);
      const dur = mins + (h % 9);
      const price = Math.round((base * a.factor * (1 + (h % 15) / 100) * (weekend ? 1.12 : 1)) / 10) * 10;
      list.push({
        id: `${a.code}-${origin.code}${dest.code}-${dateISO}-${dep}`,
        code: a.code, airline: a.name, number: `${a.code} ${100 + (h % 900)}`,
        from: origin.code, to: dest.code, fromName: origin.airport, toName: dest.airport,
        date: dateISO, dep, arr: fmtMins(toMins(dep) + dur), mins: dur, price, bag: a.bag,
      });
    });
  });
  return list;
}

export const SORTS = [
  { id: 'price', label: 'ราคาถูกสุด', fn: (a, b) => a.price - b.price || a.dep.localeCompare(b.dep) },
  { id: 'fast', label: 'เร็วที่สุด', fn: (a, b) => a.mins - b.mins || a.price - b.price },
  { id: 'early', label: 'ออกเช้าสุด', fn: (a, b) => a.dep.localeCompare(b.dep) },
];

export const flightSummary = (f) => `${f.airline} ${f.number} · ${f.dep}–${f.arr} (${f.from}→${f.to})`;
