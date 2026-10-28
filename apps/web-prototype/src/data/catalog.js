
export const DESTINATIONS = [
  { id: 'chiangmai', name: 'เชียงใหม่', sub: 'ภูเขา ธรรมชาติ วัฒนธรรมล้านนา', gradient: 'linear-gradient(135deg,#1C5C57,#89A66B)' },
  { id: 'phuket', name: 'ภูเก็ต', sub: 'ทะเลอันดามัน ชายหาดสวย', gradient: 'linear-gradient(135deg,#0B4F6C,#01BAEF)' },
  { id: 'krabi', name: 'กระบี่', sub: 'หน้าผาหินปูน เกาะแก่ง', gradient: 'linear-gradient(135deg,#123C69,#3E92CC)' },
  { id: 'pai', name: 'ปาย', sub: 'หมอกยามเช้า คาเฟ่ริมเขา', gradient: 'linear-gradient(135deg,#7A4B22,#E3A23C)' },
  { id: 'bangkok', name: 'กรุงเทพฯ', sub: 'เมืองหลวง สตรีทฟู้ด ช้อปปิ้ง', gradient: 'linear-gradient(135deg,#3B2352,#A768C9)' },
  { id: 'samui', name: 'เกาะสมุย', sub: 'เกาะสวรรค์ มะพร้าว ทะเลใส', gradient: 'linear-gradient(135deg,#0E6E55,#59C9A5)' },
];

export const LISTINGS = [
  { id: 1, type: 'hotel', name: 'ล้านนา วิว รีสอร์ท', location: 'นิมมานเหมินท์, เชียงใหม่', rating: 4.8, reviews: 342, price: 1490 },
  { id: 2, type: 'restaurant', name: 'ข้าวซอยแม่สาย', location: 'เมืองเก่า, เชียงใหม่', rating: 4.6, reviews: 891, price: 120 },
  { id: 3, type: 'attraction', name: 'วัดพระธาตุดอยสุเทพ', location: 'ดอยสุเทพ, เชียงใหม่', rating: 4.9, reviews: 5210, price: 50 },
  { id: 4, type: 'hotel', name: 'อันดามัน บีช วิลลา', location: 'ป่าตอง, ภูเก็ต', rating: 4.7, reviews: 206, price: 2350 },
  { id: 5, type: 'flight', name: 'กรุงเทพฯ → เชียงใหม่', location: 'สายการบิน Sabai Air', rating: 4.4, reviews: 1032, price: 990 },
  { id: 6, type: 'restaurant', name: 'ครัวทะเลกระบี่', location: 'อ่าวนาง, กระบี่', rating: 4.5, reviews: 410, price: 250 },
];

export const STYLE_OPTIONS = ['ธรรมชาติ', 'อาหารท้องถิ่น', 'วัฒนธรรม', 'ผจญภัย', 'ช้อปปิ้ง', 'พักผ่อนสบายๆ'];

export const TRAVEL_WITH_OPTIONS = ['คนเดียว', 'คู่รัก', 'ครอบครัว', 'เพื่อน', 'กลุ่มทัวร์'];

export const BUDGET_LEVELS = ['ประหยัด', 'ปานกลาง', 'หรูหรา'];

export const FAQS = [
  { id: 1, q: 'ยกเลิกการจองได้อย่างไร?', a: 'ไปที่ "ทริป" หรือ "การจองของฉัน" เลือกรายการที่ต้องการยกเลิก แล้วกด "ยกเลิกการจอง" ระบบจะคืนเงินตามเงื่อนไขของแต่ละที่พัก/ร้านค้า' },
  { id: 2, q: 'เงินคืนใช้เวลากี่วัน?', a: 'เงินคืนเข้า Sabai Wallet ทันทีหลังอนุมัติ หรือเข้าบัญชีธนาคาร/บัตรเครดิตภายใน 5-10 วันทำการ ขึ้นอยู่กับวิธีชำระเงินเดิม' },
  { id: 3, q: 'ใช้คูปองส่วนลดอย่างไร?', a: 'กรอกรหัสคูปองในขั้นตอน "สรุปการจอง" ก่อนชำระเงิน หรือเลือกจากหน้า "คูปองของฉัน" แล้วกดใช้งาน ระบบจะคำนวณส่วนลดให้อัตโนมัติ' },
  { id: 4, q: 'เปลี่ยนวันเดินทางได้ไหม?', a: 'ขึ้นอยู่กับนโยบายของแต่ละที่พัก/สายการบิน บางรายการเปลี่ยนแปลงได้ฟรี บางรายการมีค่าธรรมเนียม ตรวจสอบได้ที่หน้ารายละเอียดการจอง' },
  { id: 5, q: 'ติดต่อฝ่ายสนับสนุนได้ช่องทางไหนบ้าง?', a: 'แชทผ่านแอปได้ตลอด 24 ชั่วโมง หรือสร้างตั๋วสนับสนุน (Support Ticket) ทีมงานจะตอบกลับภายใน 24 ชั่วโมง' },
];

export const MEMBERS = [
  { id: 'me', name: 'หนาน ใจดี', initial: 'น', color: '#10403D', level: 'นักเดินทางใหม่', bio: 'ชอบเที่ยวธรรมชาติและตามหาคาเฟ่เงียบๆ', followers: 12 },
  { id: 'm1', name: 'มะลิ ทองดี', initial: 'ม', color: '#B5651D', level: 'Local Guide เชียงใหม่', bio: 'อยู่เชียงใหม่มา 8 ปี พาเที่ยวมุมที่นักท่องเที่ยวไม่ค่อยรู้จัก', followers: 2840 },
  { id: 'm2', name: 'ต้น สายลุย', initial: 'ต', color: '#123C69', level: 'นักเดินทางสายลุย', bio: 'เดินป่า ดำน้ำ ปั่นจักรยาน งบน้อยแต่ไปได้ไกล', followers: 1530 },
  { id: 'm3', name: 'ฝ้าย คาเฟ่ฮอป', initial: 'ฝ', color: '#7A3B6B', level: 'นักชิมตัวยง', bio: 'รีวิวคาเฟ่และร้านอาหารท้องถิ่นทั่วไทย', followers: 4120 },
  { id: 'm4', name: 'ภูมิ ทริปครอบครัว', initial: 'ภ', color: '#0E6E55', level: 'Local Guide ภูเก็ต', bio: 'พ่อลูกสองที่ชอบวางแผนทริปให้ทุกคนสนุก', followers: 960 },
];

export const GROUP_RULES = [
  'พูดจาสุภาพและให้เกียรติสมาชิกทุกคน',
  'ห้ามโฆษณาหรือขายสินค้าโดยไม่ได้รับอนุญาตจากผู้ดูแลกลุ่ม',
  'แชร์ข้อมูลจากประสบการณ์จริง และระบุเดือนที่ไปเมื่อพูดถึงราคา',
];

export const GROUPS = [
  { id: 'g1', name: 'เที่ยวเชียงใหม่ไม่ซ้ำใคร', desc: 'แลกเปลี่ยนที่เที่ยว ร้านอาหาร และเส้นทางในเชียงใหม่และจังหวัดใกล้เคียง', destination: 'เชียงใหม่', members: 12840, gradient: 'linear-gradient(135deg,#1C5C57,#89A66B)', rules: GROUP_RULES },
  { id: 'g2', name: 'สายคาเฟ่และของกิน', desc: 'รวมคาเฟ่และร้านอาหารท้องถิ่นที่อยากแนะนำ พร้อมรูปและเมนูเด็ด', destination: null, members: 9320, gradient: 'linear-gradient(135deg,#B5651D,#7A4B22)', rules: GROUP_RULES },
  { id: 'g3', name: 'เที่ยวทะเลงบประหยัด', desc: 'เคล็ดลับเที่ยวทะเลอันดามันและอ่าวไทยแบบไม่เสียเงินเกินจำเป็น', destination: 'ภูเก็ต', members: 7410, gradient: 'linear-gradient(135deg,#0B4F6C,#01BAEF)', rules: GROUP_RULES },
  { id: 'g4', name: 'เที่ยวคนเดียว', desc: 'พื้นที่สำหรับคนที่ชอบเดินทางคนเดียว แชร์ความปลอดภัย ที่พัก และการเดินทาง', destination: null, members: 5280, gradient: 'linear-gradient(135deg,#3B2352,#A768C9)', rules: GROUP_RULES },
];
