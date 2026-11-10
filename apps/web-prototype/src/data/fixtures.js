import { addDaysISO, todayISO } from '../domain/dates';

export const INITIAL_COUPONS = [
  { id: 1, code: 'SABAI20', title: 'ลด 20% ทริปแรก', detail: 'ใช้ได้กับการจองที่พักและเที่ยวบินทุกรายการ', minSpend: 1000, maxDiscount: 500, expiry: '31 ต.ค. 2569', status: 'available' },
  { id: 2, code: 'HOTEL150', title: 'ลด ฿150 ที่พัก', detail: 'สำหรับการจองที่พักขั้นต่ำ ฿1,500 ขึ้นไป', minSpend: 1500, maxDiscount: 150, expiry: '15 พ.ย. 2569', status: 'available' },
  { id: 3, code: 'FOOD50', title: 'ลด ฿50 ร้านอาหาร', detail: 'ใช้ได้กับร้านอาหารที่ร่วมรายการ', minSpend: 200, maxDiscount: 50, expiry: '20 ต.ค. 2569', status: 'available' },
  { id: 4, code: 'WELCOME100', title: 'ลด ฿100 สมาชิกใหม่', detail: 'สำหรับสมาชิกใหม่ในการจองครั้งแรก', minSpend: 500, maxDiscount: 100, expiry: '5 ก.ย. 2569', status: 'used' },
  { id: 5, code: 'FLASH30', title: 'ลด 30% แฟลชเซล', detail: 'โปรโมชั่นพิเศษช่วงเทศกาล', minSpend: 1000, maxDiscount: 800, expiry: '1 ส.ค. 2569', status: 'expired' },
];

export const INITIAL_POSTS = [
  { id: 'p1', authorId: 'm1', type: 'tip', destination: 'เชียงใหม่', groupId: 'g1', time: '2 ชม.', likes: 248, text: 'ถ้าจะขึ้นดอยสุเทพ แนะนำให้ไปถึงก่อน 7 โมงเช้า รถยังไม่ติด อากาศเย็น และมีโอกาสเจอทะเลหมกด้านล่าง ลงมาแล้วแวะกินข้าวซอยร้านแถวเมืองเก่าต่อได้พอดี' },
  { id: 'p2', authorId: 'm3', type: 'story', destination: 'เชียงใหม่', groupId: 'g2', time: '5 ชม.', likes: 512, hasImage: true, text: 'เจอคาเฟ่ริมนาที่แม่ริม นั่งมองทุ่งข้าวได้ทั้งบ่าย เครื่องดื่มรสละมุน ขนมโฮมเมดอร่อย บรรยากาศเงียบ เหมาะกับคนที่อยากพักจากความวุ่นวายในเมือง' },
  { id: 'p3', authorId: 'm2', type: 'trip', destination: 'ภูเก็ต', groupId: 'g3', time: 'เมื่อวาน', likes: 186, sharedTrip: { days: 4, budget: 12000, styles: ['ธรรมชาติ', 'ผจญภัย'] }, text: 'สรุปทริปภูเก็ต 4 วันแบบไม่ใช้ทัวร์ เช่ามอเตอร์ไซค์เที่ยวหาดทางใต้ ดูพระอาทิตย์ตกที่แหลมพรหมเทพ และกินอาหารทะเลตลาดท้องถิ่น' },
  { id: 'p4', authorId: 'm4', type: 'question', destination: 'ภูเก็ต', groupId: 'g3', time: 'เมื่อวาน', likes: 34, text: 'จะพาลูกอายุ 5 ขวบไปภูเก็ตช่วงพฤศจิกายน ควรพักหาดไหนดีคะ อยากได้หาดที่คลื่นไม่แรงและมีร้านอาหารใกล้ๆ' },
  { id: 'p5', authorId: 'm2', type: 'question', destination: 'กระบี่', groupId: null, time: '3 ชม.', likes: 9, text: 'ไปเกาะพีพีจากอ่าวนางต้องจองทัวร์ล่วงหน้าไหม หรือไปซื้อหน้างานได้เลย' },
  { id: 'p6', authorId: 'm1', type: 'trip', destination: 'เชียงใหม่', groupId: 'g1', time: '2 วัน', likes: 421, sharedTrip: { days: 3, budget: 10000, styles: ['ธรรมชาติ', 'อาหารท้องถิ่น'] }, text: 'แผนเที่ยวเชียงใหม่ 3 วัน เมืองเก่า ดอยอินทนนท์ และคาเฟ่ย่านนิมมาน เหมาะกับคู่รักที่ชอบธรรมชาติและของกิน' },
  { id: 'p7', authorId: 'm3', type: 'tip', destination: 'กรุงเทพฯ', groupId: 'g2', time: '3 วัน', likes: 97, text: 'เดินเที่ยวย่านเจริญกรุงช่วงเย็นกำลังดี แดดอ่อน ร้านอาหารและแกลเลอรีเปิดหลายที่ ใช้เรือข้ามฟากสลับกับเดินจะประหยัดเวลากว่านั่งรถ' },
  { id: 'p8', authorId: 'me', type: 'story', destination: 'ปาย', groupId: null, time: '1 สัปดาห์', likes: 23, text: 'ไปปายครั้งแรกแล้วติดใจ ตื่นเช้ามานั่งจิบกาแฟมองหมอกบนเขา เดินเล่นถนนคนเดินตอนเย็น ช้าๆ แต่ชีวิตดีมาก' },
];

export const INITIAL_COMMENTS = {
  p1: [
    { id: 'c1', authorId: 'm2', text: 'ขอบคุณค่ะ ไปมาแล้วจริง ไปสายหน่อยรถติดมาก', time: '1 ชม.', likes: 6 },
    { id: 'c2', authorId: 'm3', text: 'ลงมาแล้วแนะนำร้านข้าวซอยที่อยู่ในซอยเล็กๆ ใกล้ประตูช้างเผือก', time: '45 นาที', likes: 3 },
  ],
  p2: [{ id: 'c3', authorId: 'm1', text: 'ชอบมากค่ะ ช่วงเย็นแสงสวยสุด', time: '3 ชม.', likes: 4 }],
  p4: [
    { id: 'c4', authorId: 'm1', text: 'ลองหาดกะตะหรือหาดในหาน ช่วงพฤศจิกายนทะเลเริ่มสงบ เด็กเล็กเล่นน้ำตื้นได้สบาย', time: '20 ชม.', likes: 11, best: true },
    { id: 'c5', authorId: 'm2', text: 'หาดกะรนก็ดี ร้านอาหารเยอะ เดินจากที่พักมาได้', time: '18 ชม.', likes: 5 },
    { id: 'c6', authorId: 'm3', text: 'แนะนำดูสภาพคลื่นล่วงหน้า บางวันมีธงแดง', time: '15 ชม.', likes: 2 },
  ],
  p6: [{ id: 'c7', authorId: 'm4', text: 'เซฟไว้เลย ขอบคุณที่แชร์แผนละเอียดนะคะ', time: '1 วัน', likes: 2 }],
};

export function seedEvents() {
  const t = todayISO();
  return [
    { id: 'ev-seed-1', title: 'ประชุมบอร์ดบริหาร', date: addDaysISO(t, 3), time: '10:00', place: 'สำนักงานใหญ่', kind: 'meeting' },
    { id: 'ev-seed-2', title: 'ทานมื้อกลางวันกับลูกค้า', date: addDaysISO(t, 9), time: '12:30', place: '', kind: 'client' },
  ];
}

/* ---- mock account snapshot (DEV / mock mode only — never copied into BETA or PRODUCTION data) ---- */
export const seedWalletTransactions = () => [
    { id: 1, type: 'in', label: 'เงินคืนจากการยกเลิก (เครดิต)', date: '5 ก.ย. 2569', amount: 2000 },
    { id: 2, type: 'out', label: 'ชำระค่าที่พัก ล้านนา วิว รีสอร์ท', date: '2 ก.ย. 2569', amount: 1490 },
    { id: 3, type: 'in', label: 'เงินคืนจากการยกเลิกจอง', date: '28 ส.ค. 2569', amount: 990 },
    { id: 4, type: 'out', label: 'ชำระค่าอาหาร ข้าวซอยแม่สาย', date: '20 ส.ค. 2569', amount: 120 },
  ];

export const seedNotifications = () => [
    { id: 1, type: 'booking', title: 'ยืนยันการจองสำเร็จ', message: 'การจองที่ ล้านนา วิว รีสอร์ท ของคุณได้รับการยืนยันแล้ว', time: '5 นาทีที่แล้ว', read: false },
    { id: 2, type: 'payment', title: 'ชำระเงินสำเร็จ', message: 'ชำระเงิน ฿1,564 ผ่านพร้อมเพย์เรียบร้อยแล้ว', time: '5 นาทีที่แล้ว', read: false },
    { id: 3, type: 'promotion', title: 'โปรโมชั่นใหม่! ลด 20%', message: 'ใช้โค้ด SABAI20 สำหรับทริปแรกของคุณ ก่อนสิ้นเดือนนี้', time: '2 ชั่วโมงที่แล้ว', read: false },
    { id: 4, type: 'trip', title: 'ทริปของคุณใกล้ถึงแล้ว', message: 'อีก 3 วัน ทริปเชียงใหม่ของคุณจะเริ่มต้น เตรียมตัวให้พร้อม', time: 'เมื่อวาน', read: true },
    { id: 5, type: 'system', title: 'อัปเดตนโยบายความเป็นส่วนตัว', message: 'เราปรับปรุงนโยบายความเป็นส่วนตัวใหม่ อ่านรายละเอียดเพิ่มเติมได้ในการตั้งค่า', time: '3 วันที่แล้ว', read: true },
  ];

export const seedReviews = () => [
    { id: 1, itemName: 'ล้านนา วิว รีสอร์ท', itemType: 'hotel', rating: 5, comment: 'ที่พักสวยมาก บรรยากาศดี พนักงานเป็นกันเอง จะกลับมาพักอีกแน่นอน', date: '28 ส.ค. 2569' },
    { id: 2, itemName: 'ข้าวซอยแม่สาย', itemType: 'restaurant', rating: 4, comment: 'อร่อยมาก แต่คนเยอะไปหน่อยช่วงเที่ยง ควรไปก่อน 11 โมง', date: '15 ส.ค. 2569' },
  ];

export const seedBookings = () => [
    { id: 'b3', number: 'SB495530', type: 'flight', title: 'กรุงเทพฯ → เชียงใหม่', subtitle: 'Sabai Air · เดินทาง 25 ต.ค. 2569', amount: 1040, method: 'บัตรเครดิต/เดบิต', date: '10 ต.ค. 2569', status: 'confirmed' },
    { id: 'b1', number: 'SB482913', type: 'hotel', title: 'ล้านนา วิว รีสอร์ท', subtitle: 'นิมมานเหมินท์, เชียงใหม่', amount: 1564, method: 'พร้อมเพย์ (PromptPay)', date: '2 ก.ย. 2569', status: 'completed' },
    { id: 'b2', number: 'SB471225', type: 'restaurant', title: 'ข้าวซอยแม่สาย', subtitle: 'เมืองเก่า, เชียงใหม่', amount: 126, method: 'Sabai Wallet', date: '20 ส.ค. 2569', status: 'completed' },
  ];

