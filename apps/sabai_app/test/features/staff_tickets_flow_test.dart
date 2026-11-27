import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabai_app/src/app.dart';
import 'package:sabai_app/src/core/config/app_config.dart';
import 'package:sabai_app/src/core/errors/api_error.dart';
import 'package:sabai_app/src/data/models/staff_models.dart';
import 'package:sabai_app/src/data/repositories/http_repository.dart';
import 'package:sabai_app/src/data/repositories/mock_repository.dart';
import 'package:sabai_app/src/state/staff_queues_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response json(int status, Object? body) => http.Response.bytes(utf8.encode(jsonEncode(body)), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A repository that already holds one open ticket written by a customer, and is signed out.
Future<MockRepository> repoWithCustomerTicket() async {
  final repo = MockRepository();
  await repo.login(email: 'user@example.com', password: 'password123');
  await repo.createTicket(subject: 'ห้องไม่ตรงกับที่จอง', category: 'BOOKING', description: 'จองห้องคู่แต่ได้ห้องเดี่ยว');
  repo.logout();
  return repo;
}

Future<void> signInAsStaff(WidgetTester tester, MockRepository repo) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(SabaiApp(config: AppConfig.parse(const {}), repository: repo, prefs: await SharedPreferences.getInstance()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('โปรไฟล์'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('เข้าสู่ระบบ / สมัครสมาชิก'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('emailField')), 'staff@example.com');
  await tester.enterText(find.byKey(const Key('passwordField')), 'password123');
  await tester.tap(find.byKey(const Key('submitButton')));
  await tester.pumpAndSettle();
}

Finder chipText(String key, String text) => find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

void main() {
  test('QueueTicket and StaffTicketDetail parse the documented payload; ticket labels', () {
    final t = QueueTicket.fromJson({
      'id': 't1',
      'subject': 's',
      'category': 'BOOKING',
      'priority': 'NORMAL',
      'status': 'OPEN',
      'customer_email': 'a@b.co',
      'booking_code': 'BK1',
      'assigned_staff_id': '',
      'created_at': '2030-01-10T01:02:03Z',
      'message_count': 3,
      'next_statuses': ['IN_PROGRESS', 'CLOSED'],
    });
    expect(t.messageCount, 3);
    expect(t.nextStatuses, ['IN_PROGRESS', 'CLOSED']);
    final d = StaffTicketDetail.fromJson({
      'id': 't1',
      'status': 'OPEN',
      'customer_email': 'a@b.co',
      'description': 'd',
      'messages': [
        {'id': 'm1', 'author_kind': 'CUSTOMER', 'body': 'hi', 'created_at': 'x'}
      ],
      'next_statuses': ['CLOSED'],
    });
    expect(d.messages.single.fromStaff, isFalse);
    expect(d.ticket.nextStatuses, ['CLOSED']);
    expect(statusActionTh('ticket', 'OPEN', 'IN_PROGRESS'), 'เริ่มดำเนินการ');
    expect(statusActionTh('ticket', 'RESOLVED', 'IN_PROGRESS'), 'เปิดใหม่');
    expect(statusActionTh('ticket', 'IN_PROGRESS', 'RESOLVED'), 'ทำเครื่องหมายว่าแก้ไขแล้ว');
    expect(statusLabelTh('IN_PROGRESS'), 'กำลังดำเนินการ');
    expect(isDestructiveStatus('CLOSED'), isTrue); // closing locks the customer out
    expect(isDestructiveStatus('IN_PROGRESS'), isFalse);
  });

  test('HttpRepository: staff ticket routes, filter and bodies', () async {
    final seen = <String>[];
    final bodies = <Object?>[];
    final r = HttpRepository(
      client: MockClient((req) async {
        seen.add('${req.method} ${req.url.path}${req.url.hasQuery ? '?${req.url.query}' : ''}');
        bodies.add(req.body.isEmpty ? null : jsonDecode(req.body));
        if (req.method != 'GET') return json(200, {'data': {}});
        if (req.url.path == '/portal/tickets') {
          return json(200, {
            'data': {
              'items': [
                {'id': 't1', 'subject': 's', 'category': 'OTHER', 'status': 'OPEN', 'customer_email': 'a@b.co', 'next_statuses': ['CLOSED']}
              ],
              'total': 4,
              'limit': 20,
              'offset': 0
            }
          });
        }
        return json(200, {'data': {'id': 't1', 'subject': 's', 'category': 'OTHER', 'status': 'OPEN', 'customer_email': 'a@b.co', 'description': 'd', 'messages': []}});
      }),
      baseUrl: 'https://api.test',
      mode: ApiMode.beta,
      pollDelay: Duration.zero,
    );
    final page = await r.staffTickets(status: 'OPEN', offset: 20, limit: 20);
    expect(page.total, 4);
    expect(page.items.single.customerEmail, 'a@b.co');
    expect((await r.staffTicket('t1')).description, 'd');
    await r.replyAsStaff(id: 't1', body: 'ตรวจสอบแล้วค่ะ');
    await r.changeTicketStatus(id: 't1', to: 'RESOLVED', note: 'เรียบร้อย');
    expect(seen, [
      'GET /portal/tickets?limit=20&offset=20&status=OPEN',
      'GET /portal/tickets/t1',
      'POST /portal/tickets/t1/messages',
      'PATCH /portal/tickets/t1/status',
    ]);
    expect(bodies[2], {'body': 'ตรวจสอบแล้วค่ะ'});
    expect(bodies[3], {'status': 'RESOLVED', 'note': 'เรียบร้อย'});
  });

  test('StaffQueuesController: reply assigns and moves OPEN on; the customer sees a nameless STAFF reply; closed is final', () async {
    final repo = await repoWithCustomerTicket();

    // A customer cannot use the staff queue.
    await repo.login(email: 'user@example.com', password: 'password123');
    final denied = StaffQueuesController(repo);
    await denied.loadTickets();
    expect(denied.tickets.error, isNotNull);
    expect(denied.tickets.items, isEmpty);
    repo.logout();

    await repo.login(email: 'staff@example.com', password: 'password123');
    final c = StaffQueuesController(repo);
    await c.loadTickets(status: '');
    expect(c.tickets.items.single.customerEmail, 'user@example.com');
    expect(c.tickets.items.single.nextStatuses, ['IN_PROGRESS', 'CLOSED']);
    final id = c.tickets.items.single.id;

    await c.openTicket(id);
    expect(c.ticketDetail!.description, 'จองห้องคู่แต่ได้ห้องเดี่ยว');
    expect(await c.replyToTicket(id, '  กำลังตรวจสอบกับโรงแรมค่ะ  '), isTrue);
    expect(c.ticketDetail!.ticket.status, 'IN_PROGRESS');
    expect(c.ticketDetail!.messages.single.fromStaff, isTrue);
    expect(c.ticketDetail!.messages.single.body, 'กำลังตรวจสอบกับโรงแรมค่ะ');
    expect(c.tickets.items.single.status, 'IN_PROGRESS'); // the list followed

    expect(await c.changeTicketStatus(id, 'OPEN'), isFalse); // not a valid target
    expect(await c.changeTicketStatus(id, 'RESOLVED'), isTrue);
    expect(c.ticketDetail!.ticket.nextStatuses, ['IN_PROGRESS', 'CLOSED']);
    expect(await c.changeTicketStatus(id, 'CLOSED', note: 'ลูกค้ายืนยันแล้ว'), isTrue);
    expect(c.ticketDetail!.ticket.nextStatuses, isEmpty);
    expect(await c.replyToTicket(id, 'ตอบอีกครั้ง'), isFalse);
    expect(c.actionError, contains('ปิดหรือเปลี่ยนสถานะไปแล้ว'));
    expect(c.ticketDetail!.ticket.status, 'CLOSED'); // still shows what the server holds
    await expectLater(repo.replyAsStaff(id: id, body: '   '), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'VALIDATION_ERROR')));

    // The customer sees the reply as STAFF and nothing that identifies the author.
    repo.logout();
    await repo.login(email: 'user@example.com', password: 'password123');
    final mine = await repo.myTicket(id);
    expect(mine.ticket.status, 'CLOSED');
    expect(mine.messages.single.authorKind, 'STAFF');
    expect(jsonEncode([mine.messages.single.id, mine.messages.single.authorKind, mine.messages.single.body]), isNot(contains('staff@example.com')));

    c.reset();
    await Future<void>.delayed(Duration.zero);
    expect(c.tickets.items, isEmpty);
    expect(c.ticketDetail, isNull);
  });

  testWidgets('staff: open a customer ticket, reply, resolve and close it', (tester) async {
    tall(tester);
    await signInAsStaff(tester, await repoWithCustomerTicket());
    await tester.tap(find.byKey(const Key('staffQueuesTile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-tickets')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tk-mock-t-1')), findsOneWidget);
    expect(chipText('tk-mock-t-1-status', 'เปิดอยู่'), findsOneWidget);
    expect(find.textContaining('user@example.com'), findsOneWidget);

    await tester.tap(find.text('ห้องไม่ตรงกับที่จอง'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('staffTicketDescription')), findsOneWidget);
    expect(find.text('จองห้องคู่แต่ได้ห้องเดี่ยว'), findsOneWidget);
    expect(find.byKey(const Key('staffNoMessages')), findsOneWidget);
    expect(find.byKey(const Key('tkd-to-IN_PROGRESS')), findsOneWidget);
    expect(find.byKey(const Key('tkd-to-RESOLVED')), findsNothing); // not allowed from OPEN

    await tester.enterText(find.byKey(const Key('staffReplyField')), 'กำลังตรวจสอบกับโรงแรมค่ะ');
    await tester.tap(find.byKey(const Key('staffSendReply')));
    await tester.pumpAndSettle();
    expect(find.text('กำลังตรวจสอบกับโรงแรมค่ะ'), findsOneWidget);
    expect(chipText('staffTicketStatus', 'กำลังดำเนินการ'), findsOneWidget); // the first reply moved it on
    expect(find.byKey(const Key('tkd-to-RESOLVED')), findsOneWidget);
    expect(find.byKey(const Key('tkd-to-IN_PROGRESS')), findsNothing);

    await tester.tap(find.byKey(const Key('tkd-to-RESOLVED')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmStatus')));
    await tester.pumpAndSettle();
    expect(chipText('staffTicketStatus', 'แก้ไขแล้ว'), findsOneWidget);

    // Closing is final: it asks first, and afterwards there is no reply box and no further action.
    await tester.tap(find.byKey(const Key('tkd-to-CLOSED')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(chipText('staffTicketStatus', 'แก้ไขแล้ว'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tkd-to-CLOSED')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmStatus')));
    await tester.pumpAndSettle();
    expect(chipText('staffTicketStatus', 'ปิดแล้ว'), findsOneWidget);
    expect(find.byKey(const Key('staffTicketClosedNote')), findsOneWidget);
    expect(find.byKey(const Key('staffReplyField')), findsNothing);
    expect(find.byKey(const Key('tkd-to-CLOSED')), findsNothing);
  });
}
