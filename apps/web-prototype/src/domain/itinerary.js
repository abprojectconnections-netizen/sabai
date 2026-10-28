export function buildItinerary({ destinationName, days, budget, styles }) {
  if (destinationName === 'เชียงใหม่' && days === 3) {
    return {
      days: [
        { title: 'วันที่ 1 · เมืองเก่าเชียงใหม่', items: [
          { time: '09:00', text: 'เดินทางถึงสนามบินเชียงใหม่ เช็คอินที่พัก', place: 'สนามบินเชียงใหม่' },
          { time: '12:00', text: 'อาหารกลางวันข้าวซอยที่ร้านเมืองเก่า', place: 'ข้าวซอย เมืองเก่า เชียงใหม่' },
          { time: '14:00', text: 'เที่ยววัดพระสิงห์และเดินเล่นถนนคนเดินท่าแพ', place: 'วัดพระสิงห์ เชียงใหม่' },
          { time: '18:30', text: 'อาหารเย็นที่ตลาดวโรรส', place: 'ตลาดวโรรส เชียงใหม่' },
        ]},
        { title: 'วันที่ 2 · ดอยอินทนนท์', items: [
          { time: '07:00', text: 'ออกเดินทางสู่ดอยอินทนนท์' },
          { time: '09:30', text: 'ชมพระธาตุนภเมทนีดลและนภพลภูมิสิริ', place: 'พระมหาธาตุนภเมทนีดล ดอยอินทนนท์' },
          { time: '12:00', text: 'ปิคนิคอาหารกลางวันริมธารน้ำ' },
          { time: '15:00', text: 'เดินชมน้ำตกวชิรธาร', place: 'น้ำตกวชิรธาร ดอยอินทนนท์' },
          { time: '19:00', text: 'กลับเข้าเมือง อาหารเย็นชิลๆ' },
        ]},
        { title: 'วันที่ 3 · คาเฟ่และตลาด', items: [
          { time: '09:00', text: 'จิบกาแฟที่คาเฟ่ย่านนิมมานเหมินท์', place: 'คาเฟ่ นิมมานเหมินท์ เชียงใหม่' },
          { time: '11:00', text: 'ช้อปปิ้งที่ One Nimman', place: 'One Nimman เชียงใหม่' },
          { time: '14:00', text: 'เดินเล่นตลาดเมืองใหม่', place: 'ตลาดเมืองใหม่ เชียงใหม่' },
          { time: '17:00', text: 'เดินทางกลับสนามบิน', place: 'สนามบินเชียงใหม่' },
        ]},
      ],
      budgetBreakdown: [
        { label: 'เที่ยวบิน', value: 3000 },
        { label: 'ที่พัก', value: 4000 },
        { label: 'อาหาร', value: 1500 },
        { label: 'กิจกรรม', value: 1000 },
        { label: 'การเดินทางในพื้นที่', value: 500 },
      ],
    };
  }
  const templates = [
    (d) => ({ text: `สำรวจแหล่งท่องเที่ยวสำคัญของ${d}`, place: `สถานที่ท่องเที่ยว ${d}` }),
    (d) => ({ text: `ลิ้มลองอาหารท้องถิ่นชื่อดังของ${d}`, place: `อาหารท้องถิ่น ${d}` }),
    (d) => ({ text: 'เดินเล่นตลาดและย่านคาเฟ่ยอดนิยม', place: `ตลาด คาเฟ่ ${d}` }),
    (d) => ({ text: `กิจกรรมกลางแจ้งท่ามกลางธรรมชาติใกล้${d}`, place: `ธรรมชาติ จุดชมวิว ${d}` }),
    (d) => ({ text: 'พักผ่อนและช้อปปิ้งของฝาก', place: `ของฝาก ${d}` }),
  ];
  const dayList = Array.from({ length: Math.min(days, 7) }).map((_, i) => {
    const first = templates[i % templates.length](destinationName);
    return {
      title: `วันที่ ${i + 1} · ${destinationName}`,
      items: [
        { time: '09:00', ...first },
        { time: '13:00', text: `อาหารกลางวันร้านแนะนำใน${destinationName}`, place: `ร้านอาหาร ${destinationName}` },
        { time: '16:00', text: styles.length ? `กิจกรรมตามความสนใจ: ${styles.join(', ')}` : 'เดินเล่นชมเมือง', place: `${styles[0] || 'สถานที่ท่องเที่ยว'} ${destinationName}` },
        { time: '19:00', text: 'อาหารเย็นและพักผ่อน', place: `ร้านอาหารมื้อเย็น ${destinationName}` },
      ],
    };
  });
  const b = Math.max(budget, 3000);
  return {
    days: dayList,
    budgetBreakdown: [
      { label: 'เที่ยวบิน', value: Math.round((b * 0.28) / 100) * 100 },
      { label: 'ที่พัก', value: Math.round((b * 0.35) / 100) * 100 },
      { label: 'อาหาร', value: Math.round((b * 0.2) / 100) * 100 },
      { label: 'กิจกรรม', value: Math.round((b * 0.1) / 100) * 100 },
      { label: 'การเดินทางในพื้นที่', value: Math.round((b * 0.07) / 100) * 100 },
    ],
  };
}
