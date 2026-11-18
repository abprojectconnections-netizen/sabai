/// Rule-based itinerary templates. This is NOT artificial intelligence and does not know opening hours,
/// distances or prices: it only lays out a sensible starter day plan for the user to edit.

class PlannedItem {
  const PlannedItem({required this.time, required this.text});
  final String time; // HH:MM
  final String text;
}

class PlannedDay {
  const PlannedDay({required this.title, required this.items});
  final String title;
  final List<PlannedItem> items;
}

const int maxPlannerDays = 7;

/// Interest tags the user can pick. They only influence the afternoon slot's wording.
const List<String> plannerStyles = ['ธรรมชาติ', 'อาหาร', 'คาเฟ่', 'ช้อปปิ้ง', 'วัฒนธรรม'];

List<PlannedDay> buildPlan({required String destination, required int days, List<String> styles = const []}) {
  final d = destination.trim();
  final count = days.clamp(1, maxPlannerDays);
  if (d == 'เชียงใหม่' && count == 3) return _chiangMai3Days;
  final firstSlot = <String Function(String)>[
    (x) => 'สำรวจแหล่งท่องเที่ยวสำคัญของ$x',
    (x) => 'ลิ้มลองอาหารท้องถิ่นชื่อดังของ$x',
    (_) => 'เดินเล่นตลาดและย่านคาเฟ่ยอดนิยม',
    (x) => 'กิจกรรมกลางแจ้งท่ามกลางธรรมชาติใกล้$x',
    (_) => 'พักผ่อนและช้อปปิ้งของฝาก',
  ];
  return [
    for (var i = 0; i < count; i++)
      PlannedDay(title: 'วันที่ ${i + 1} · $d', items: [
        PlannedItem(time: '09:00', text: firstSlot[i % firstSlot.length](d)),
        PlannedItem(time: '13:00', text: 'อาหารกลางวันร้านแนะนำใน$d'),
        PlannedItem(time: '16:00', text: styles.isEmpty ? 'เดินเล่นชมเมือง' : 'กิจกรรมตามความสนใจ: ${styles.join(', ')}'),
        const PlannedItem(time: '19:00', text: 'อาหารเย็นและพักผ่อน'),
      ]),
  ];
}

const List<PlannedDay> _chiangMai3Days = [
  PlannedDay(title: 'วันที่ 1 · เมืองเก่าเชียงใหม่', items: [
    PlannedItem(time: '09:00', text: 'เดินทางถึงสนามบินเชียงใหม่ เช็คอินที่พัก'),
    PlannedItem(time: '12:00', text: 'อาหารกลางวันข้าวซอยที่ร้านเมืองเก่า'),
    PlannedItem(time: '14:00', text: 'เที่ยววัดพระสิงห์และเดินเล่นถนนคนเดินท่าแพ'),
    PlannedItem(time: '18:30', text: 'อาหารเย็นที่ตลาดวโรรส'),
  ]),
  PlannedDay(title: 'วันที่ 2 · ดอยอินทนนท์', items: [
    PlannedItem(time: '07:00', text: 'ออกเดินทางสู่ดอยอินทนนท์'),
    PlannedItem(time: '09:30', text: 'ชมพระธาตุนภเมทนีดลและนภพลภูมิสิริ'),
    PlannedItem(time: '12:00', text: 'ปิคนิคอาหารกลางวันริมธารน้ำ'),
    PlannedItem(time: '15:00', text: 'เดินชมน้ำตกวชิรธาร'),
    PlannedItem(time: '19:00', text: 'กลับเข้าเมือง อาหารเย็นชิลๆ'),
  ]),
  PlannedDay(title: 'วันที่ 3 · คาเฟ่และตลาด', items: [
    PlannedItem(time: '09:00', text: 'จิบกาแฟที่คาเฟ่ย่านนิมมานเหมินท์'),
    PlannedItem(time: '11:00', text: 'ช้อปปิ้งที่ One Nimman'),
    PlannedItem(time: '14:00', text: 'เดินเล่นตลาดเมืองใหม่'),
    PlannedItem(time: '17:00', text: 'เดินทางกลับสนามบิน'),
  ]),
];
