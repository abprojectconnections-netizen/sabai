import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import 'my_tickets_screen.dart';

/// FAQ plus, once signed in, the customer's support requests. Every answer describes what this app and its server actually do
/// today and states no policy numbers (refund windows, fees), because none is defined yet.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const List<({String q, String a})> faqs = [
    (
      q: 'ราคาที่แสดงตอนจองคิดอย่างไร?',
      a: 'ราคาและยอดรวมคำนวณโดยเซิร์ฟเวอร์ แอปส่งเพียงรายการ วันที่ จำนวน และวิธีชำระ จึงไม่สามารถแก้ราคาจากฝั่งแอปได้'
    ),
    (
      q: 'จองสำเร็จเมื่อไหร่?',
      a: 'การจองสำเร็จเมื่อเซิร์ฟเวอร์ยืนยันผลการชำระเงินแล้วเท่านั้น แอปจะไม่แสดงว่าสำเร็จก่อนได้รับผลจากเซิร์ฟเวอร์'
    ),
    (
      q: 'ขอคืนเงินได้อย่างไร?',
      a: 'เปิดหน้าการจองแล้วกดขอคืนเงินในรายการที่ต้องการ การขอคืนเงินเป็นเพียงคำขอ ระบบจะคำนวณยอดจากราคาของการจองนั้นและเป็นผู้ตัดสินว่าอนุมัติหรือไม่'
    ),
    (
      q: 'คูปองใช้ลดราคาได้ไหม?',
      a: 'ตอนนี้บันทึกรหัสคูปองไว้ดูสถานะได้อย่างเดียว ยังใช้ลดราคาในแอปไม่ได้'
    ),
    (
      q: 'โพสต์ในชุมชนถูกตรวจก่อนแสดงไหม?',
      a: 'ไม่ โพสต์แสดงทันที หากพบโพสต์ที่ไม่เหมาะสมให้กดรายงาน โพสต์ที่คุณรายงานจะไม่แสดงให้คุณเห็นอีก'
    ),
    (
      q: 'แท็กคืออะไร?',
      a: 'แท็กคือคำสั้น ๆ ที่คุณใส่ให้รีวิวหรือโพสต์ของคุณเอง (สูงสุด 10 แท็ก แท็กละไม่เกิน 30 ตัวอักษร) เพื่อให้จัดหมวดและค้นหาได้'
    ),
    (
      q: 'ข้อมูลทริปและรีวิวของฉันใครเห็นได้บ้าง?',
      a: 'ทริปเป็นของคุณคนเดียว รีวิวและโพสต์ในชุมชนแสดงชื่อที่ใช้แสดง ไม่แสดงอีเมลของคุณ'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<AppState>().signedIn;
    return Scaffold(
      appBar: AppBar(title: const Text('ช่วยเหลือ')),
      body: ListView(
        children: [
          if (signedIn)
            ListTile(
              key: const Key('myTicketsTile'),
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('คำขอความช่วยเหลือของฉัน'),
              subtitle: const Text('แจ้งปัญหากับเจ้าหน้าที่ และติดตามคำตอบ'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MyTicketsScreen())),
            ),
          for (var i = 0; i < faqs.length; i++)
            ExpansionTile(
              key: Key('faq-$i'),
              title: Text(faqs[i].q),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(faqs[i].a)],
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(signedIn ? 'ไม่พบคำตอบที่ต้องการ? แจ้งปัญหาได้ที่ "คำขอความช่วยเหลือของฉัน" ด้านบน' : 'ไม่พบคำตอบที่ต้องการ? เข้าสู่ระบบเพื่อแจ้งปัญหากับเจ้าหน้าที่', key: const Key('helpFooter')),
          ),
        ],
      ),
    );
  }
}
