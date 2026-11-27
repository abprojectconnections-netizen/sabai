import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabai_app/src/app.dart';
import 'package:sabai_app/src/core/config/app_config.dart';
import 'package:sabai_app/src/core/errors/api_error.dart';
import 'package:sabai_app/src/data/models/support_models.dart';
import 'package:sabai_app/src/data/repositories/http_repository.dart';
import 'package:sabai_app/src/data/repositories/mock_repository.dart';
import 'package:sabai_app/src/state/tickets_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response json(int status, Object? body) => http.Response.bytes(utf8.encode(jsonEncode(body)), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

Future<MockRepository> signedIn(String email) async {
  final r = MockRepository();
  await r.login(email: email, password: 'password123');
  return r;
}

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Opens the app and, when [email] is given, signs in through the real sign-in screen so AppState knows about the session.
Future<void> pumpApp(WidgetTester tester, {String? email}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(SabaiApp(
    config: AppConfig.parse(const {}),
    repository: MockRepository(),
    prefs: await SharedPreferences.getInstance(),
  ));
  await tester.pumpAndSettle();
  if (email == null) return;
  await tester.tap(find.text('โปรไฟล์'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('เข้าสู่ระบบ / สมัครสมาชิก'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('emailField')), email);
  await tester.enterText(find.byKey(const Key('passwordField')), 'password123');
  await tester.tap(find.byKey(const Key('submitButton')));
  await tester.pumpAndSettle();
}

void main() {
  test('models parse the documented payloads and label statuses in Thai', () {
    final t = SupportTicket.fromJson({
      'id': 't1',
      'subject': 's',
      'category': 'BOOKING',
      'status': 'IN_PROGRESS',
      'booking_code': 'BK1',
      'created_at': '2030-01-10T01:02:03Z',
      'reply_count': 2,
    });
    expect(t.replyCount, 2);
    expect(t.isClosed, isFalse);
    expect(ticketStatusLabelTh('OPEN'), 'รอเจ้าหน้าที่');
    expect(ticketStatusLabelTh('CLOSED'), 'ปิดแล้ว');
    expect(ticketCategoryLabelTh('REFUND'), 'การคืนเงิน');
    expect(ticketDate('2030-01-10T01:02:03Z'), '2030-01-10');
    final d = SupportTicketDetail.fromJson({
      'id': 't1',
      'subject': 's',
      'category': 'OTHER',
      'status': 'OPEN',
      'description': 'd',
      'messages': [
        {'id': 'm1', 'author_kind': 'STAFF', 'body': 'hi', 'created_at': 'x'}
      ],
    });
    expect(d.messages.single.fromStaff, isTrue);
    expect(d.description, 'd');
    expect(SupportTicketDetail.fromJson({'id': 'x'}).messages, isEmpty);
  });

  test('HttpRepository: tickets use the documented routes and bodies', () async {
    final seen = <String>[];
    final bodies = <Object?>[];
    final r = HttpRepository(
      client: MockClient((req) async {
        seen.add('${req.method} ${req.url.path}${req.url.hasQuery ? '?${req.url.query}' : ''}');
        bodies.add(req.body.isEmpty ? null : jsonDecode(req.body));
        if (req.method == 'POST' && req.url.path == '/support/tickets') return json(201, {'data': {'id': 'new-1', 'status': 'OPEN'}});
        if (req.method == 'POST') return json(200, {'data': {}});
        if (req.url.path == '/support/tickets') {
          return json(200, {
            'data': {
              'items': [
                {'id': 't1', 'subject': 's', 'category': 'OTHER', 'status': 'OPEN', 'reply_count': 0}
              ],
              'total': 7,
              'limit': 20,
              'offset': 0
            }
          });
        }
        return json(200, {
          'data': {'id': 't1', 'subject': 's', 'category': 'OTHER', 'status': 'OPEN', 'description': 'd', 'messages': []}
        });
      }),
      baseUrl: 'https://api.test',
      mode: ApiMode.beta,
      pollDelay: Duration.zero,
    );
    final page = await r.myTickets(offset: 20, limit: 20);
    expect(page.total, 7);
    expect(page.items.single.id, 't1');
    expect((await r.myTicket('t1')).description, 'd');
    expect(await r.createTicket(subject: 'หัวข้อ', category: 'BOOKING', description: 'รายละเอียด'), 'new-1');
    await r.replyToMyTicket(id: 't1', body: 'ขอบคุณ');
    await r.closeMyTicket('t1');
    expect(seen, [
      'GET /support/tickets?limit=20&offset=20',
      'GET /support/tickets/t1',
      'POST /support/tickets',
      'POST /support/tickets/t1/messages',
      'POST /support/tickets/t1/close',
    ]);
    expect(bodies[2], {'subject': 'หัวข้อ', 'category': 'BOOKING', 'description': 'รายละเอียด'});
    expect(bodies[3], {'body': 'ขอบคุณ'});
  });

  test('MockRepository follows the backend rules: validation, privacy, open limit, closed, reopen', () async {
    final repo = await signedIn('user@example.com');
    for (final bad in [
      () => repo.createTicket(subject: 'ab', category: 'OTHER', description: 'x'),
      () => repo.createTicket(subject: 'หัวข้อ', category: 'OTHER', description: '  '),
      () => repo.createTicket(subject: 'หัวข้อ', category: 'HACK', description: 'x'),
    ]) {
      await expectLater(bad(), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'VALIDATION_ERROR')));
    }
    final ids = <String>[];
    for (var i = 0; i < 5; i++) {
      ids.add(await repo.createTicket(subject: 'ปัญหาที่ $i ของฉัน', category: 'OTHER', description: 'x'));
    }
    await expectLater(repo.createTicket(subject: 'ใบที่หก', category: 'OTHER', description: 'x'),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'CONFLICT')));
    expect((await repo.myTickets()).total, 5);
    expect((await repo.myTickets()).items.first.id, ids.last); // newest first
    expect((await repo.myTickets(offset: 4, limit: 20)).items.length, 1);
    expect((await repo.myTickets(offset: 9, limit: 20)).items, isEmpty);

    await repo.closeMyTicket(ids.first);
    await expectLater(repo.closeMyTicket(ids.first), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'CONFLICT')));
    await expectLater(repo.replyToMyTicket(id: ids.first, body: 'x'), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'CONFLICT')));
    await repo.createTicket(subject: 'หลังปิดหนึ่งใบ', category: 'OTHER', description: 'x'); // a slot was freed

    // Someone else's ticket looks like one that does not exist.
    repo.logout();
    await repo.login(email: 'other@example.com', password: 'password123');
    await expectLater(repo.myTicket(ids[1]), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'NOT_FOUND')));
    expect((await repo.myTickets()).total, 0);
  });

  test('TicketsController: create, reply, close, errors in Thai, reset on sign-out', () async {
    final repo = await signedIn('user@example.com');
    final c = TicketsController(repo);
    await c.load();
    expect(c.tickets, isEmpty);
    expect(c.loadedOnce, isTrue);

    final id = await c.create(subject: '  ห้องไม่ตรงที่จอง  ', category: 'BOOKING', description: 'รายละเอียด');
    expect(id, isNotNull);
    expect(c.tickets.single.subject, 'ห้องไม่ตรงที่จอง'); // trimmed, list reloaded
    expect(await c.create(subject: 'x', category: 'OTHER', description: 'y'), isNull);
    expect(c.actionError, isNotNull);

    await c.openDetail(id!);
    expect(c.detail!.description, 'รายละเอียด');
    expect(await c.reply(id, '  ขอบคุณค่ะ  '), isTrue);
    expect(c.detail!.messages.single.body, 'ขอบคุณค่ะ');
    expect(c.detail!.messages.single.fromStaff, isFalse);

    expect(await c.close(id), isTrue);
    expect(c.detail!.ticket.status, 'CLOSED');
    expect(await c.reply(id, 'อีกครั้ง'), isFalse);
    expect(c.actionError, 'คำขอนี้ถูกปิดแล้ว');
    expect(c.detail!.ticket.isClosed, isTrue); // the screen still shows what the server holds

    for (var i = 0; i < 5; i++) {
      expect(await c.create(subject: 'ปัญหาที่ $i ของฉัน', category: 'OTHER', description: 'x'), isNotNull);
    }
    expect(await c.create(subject: 'ใบที่หก', category: 'OTHER', description: 'x'), isNull);
    expect(c.actionError, contains('5 รายการ'));

    c.reset();
    await Future<void>.delayed(Duration.zero);
    expect(c.tickets, isEmpty);
    expect(c.detail, isNull);
    expect(c.loadedOnce, isFalse);
  });

  testWidgets('signed out: help shows the FAQ and asks to sign in, no ticket entry', (tester) async {
    tall(tester);
    await pumpApp(tester);
    await tester.tap(find.text('โปรไฟล์'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('helpTile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('myTicketsTile')), findsNothing);
    expect(find.textContaining('เข้าสู่ระบบเพื่อแจ้งปัญหา'), findsOneWidget);
  });

  testWidgets('signed in: open a ticket, see it, reply, close it', (tester) async {
    tall(tester);
    await pumpApp(tester, email: 'user@example.com');
    await tester.tap(find.byKey(const Key('helpTile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('myTicketsTile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ticketsEmpty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('newTicketButton')));
    await tester.pumpAndSettle();
    // Client-side checks come first and nothing is sent.
    await tester.tap(find.byKey(const Key('submitTicket')));
    await tester.pumpAndSettle();
    expect(find.text('หัวข้อต้องยาวอย่างน้อย 3 ตัวอักษร'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('ticketSubjectField')), 'ห้องไม่ตรงกับที่จอง');
    await tester.tap(find.byKey(const Key('submitTicket')));
    await tester.pumpAndSettle();
    expect(find.text('กรุณาอธิบายปัญหา'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ticketCategoryField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('การจอง').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ticketDescriptionField')), 'จองห้องคู่แต่ได้ห้องเดี่ยว');
    await tester.tap(find.byKey(const Key('submitTicket')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ticketsEmpty')), findsNothing);
    expect(find.text('ห้องไม่ตรงกับที่จอง'), findsOneWidget);
    expect(find.textContaining('รอเจ้าหน้าที่'), findsOneWidget);

    await tester.tap(find.text('ห้องไม่ตรงกับที่จอง'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ticketDescription')), findsOneWidget);
    expect(find.text('จองห้องคู่แต่ได้ห้องเดี่ยว'), findsOneWidget);
    expect(find.byKey(const Key('noMessages')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('replyField')), 'รบกวนช่วยตรวจสอบด้วยค่ะ');
    await tester.tap(find.byKey(const Key('sendReply')));
    await tester.pumpAndSettle();
    expect(find.text('รบกวนช่วยตรวจสอบด้วยค่ะ'), findsOneWidget);
    expect(find.byKey(const Key('noMessages')), findsNothing);

    // Cancelling the confirmation keeps it open; confirming closes it and removes the reply box.
    await tester.tap(find.byKey(const Key('closeTicketButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('replyField')), findsOneWidget);

    await tester.tap(find.byKey(const Key('closeTicketButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmCloseTicket')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ticketClosedNote')), findsOneWidget);
    expect(find.byKey(const Key('replyField')), findsNothing);
    expect(find.descendant(of: find.byKey(const Key('ticketStatus')), matching: find.text('ปิดแล้ว')), findsOneWidget);
  });
}
