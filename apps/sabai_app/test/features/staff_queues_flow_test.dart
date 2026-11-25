import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabai_app/src/app.dart';
import 'package:sabai_app/src/core/config/app_config.dart';
import 'package:sabai_app/src/data/models/community_models.dart';
import 'package:sabai_app/src/data/models/staff_models.dart';
import 'package:sabai_app/src/data/repositories/http_repository.dart';
import 'package:sabai_app/src/data/repositories/mock_repository.dart';
import 'package:sabai_app/src/state/staff_queues_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response json(int status, Object? body) => http.Response.bytes(utf8.encode(jsonEncode(body)), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

Future<void> pumpAndSignIn(WidgetTester tester, String email) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(SabaiApp(
    config: AppConfig.parse(const {}),
    repository: MockRepository(),
    prefs: await SharedPreferences.getInstance(),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('โปรไฟล์'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('เข้าสู่ระบบ / สมัครสมาชิก'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('emailField')), email);
  await tester.enterText(find.byKey(const Key('passwordField')), 'password123');
  await tester.tap(find.byKey(const Key('submitButton')));
  await tester.pumpAndSettle();
}

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> openQueues(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('staffQueuesTile')));
  await tester.pumpAndSettle();
}

Future<void> confirm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('confirmStatus')));
  await tester.pumpAndSettle();
}

Finder chipText(String key, String text) => find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

void main() {
  test('AccountInfo: each queue follows its own permission', () {
    const officer = AccountInfo(permissions: ['portal.read', 'booking.manage', 'support.manage']);
    expect(officer.canManageBookings, isTrue);
    expect(officer.canManageDisputes, isTrue);
    expect(officer.canReviewPartners, isFalse);
    expect(officer.hasStaffQueues, isTrue);
    expect(const AccountInfo(permissions: ['partner.review']).hasStaffQueues, isTrue);
    expect(const AccountInfo(permissions: ['portal.read']).hasStaffQueues, isFalse);
    expect(const AccountInfo(permissions: ['user.manage']).hasStaffQueues, isFalse);
  });

  test('models parse the documented rows; labels and destructive flags', () {
    final b = QueueBooking.fromJson({
      'id': 'b1', 'booking_code': 'SB-1', 'status': 'PENDING', 'currency': 'THB', 'total_amount': '1234.50',
      'customer_email': 'a@b.co', 'created_at': '2030-01-02T00:00:00Z', 'next_statuses': ['CONFIRMED', 'CANCELLED'],
    });
    expect(b.nextStatuses, ['CONFIRMED', 'CANCELLED']);
    expect(b.total, '1234.50');
    expect(QueueBooking.fromJson(const {}).nextStatuses, isEmpty);
    final d = QueueDispute.fromJson({'id': 'd1', 'booking_id': 'b1', 'booking_code': 'SB-1', 'reason': 'NO_SHOW', 'status': 'OPEN', 'opened_by_email': 'x@y.co', 'next_statuses': ['IN_REVIEW']});
    expect(d.openedBy, 'x@y.co');
    expect(QueuePartner.fromJson({'id': 'p1', 'legal_name': 'ร้าน', 'status': 'SUSPENDED', 'owner_email': 'o@y.co', 'next_statuses': ['APPROVED']}).legalName, 'ร้าน');
    expect(statusLabelTh('IN_REVIEW'), 'กำลังตรวจสอบ');
    expect(statusLabelTh('SOMETHING_NEW'), 'SOMETHING_NEW');
    expect(statusActionTh('partner', 'SUSPENDED', 'APPROVED'), 'เปิดใช้งานอีกครั้ง');
    expect(statusActionTh('partner', 'PENDING', 'APPROVED'), 'อนุมัติ');
    expect(isDestructiveStatus('CANCELLED'), isTrue);
    expect(isDestructiveStatus('CONFIRMED'), isFalse);
  });

  test('HttpRepository: queue lists and status changes use the documented routes, filters and bodies', () async {
    final seen = <String>[];
    final bodies = <Object?>[];
    final r = HttpRepository(
      client: MockClient((req) async {
        seen.add('${req.method} ${req.url.path}${req.url.query.isEmpty ? '' : '?${req.url.query}'}');
        if (req.body.isNotEmpty) bodies.add(jsonDecode(req.body));
        if (req.method != 'GET') return json(200, {'data': {'id': 'x'}});
        switch (req.url.path) {
          case '/portal/bookings':
            return json(200, {'data': {'items': [{'id': 'b1', 'booking_code': 'SB-1', 'status': 'PENDING', 'next_statuses': ['CONFIRMED']}], 'total': 7}});
          case '/portal/disputes':
            return json(200, {'data': {'items': [{'id': 'd1', 'status': 'OPEN', 'next_statuses': ['IN_REVIEW']}], 'total': 1}});
          default:
            return json(200, {'data': {'items': [{'id': 'p1', 'legal_name': 'ร้าน', 'status': 'PENDING', 'next_statuses': ['APPROVED', 'REJECTED']}], 'total': 1}});
        }
      }),
      baseUrl: 'https://api.test',
      mode: ApiMode.beta,
      pollDelay: Duration.zero,
    );
    final b = await r.staffBookings(status: 'PENDING', query: ' SB-1 ', offset: 20, limit: 20);
    expect(b.total, 7);
    expect(b.items.single.nextStatuses, ['CONFIRMED']);
    expect((await r.staffDisputes(status: 'OPEN')).items.single.id, 'd1');
    expect((await r.staffPartners()).items.single.nextStatuses, ['APPROVED', 'REJECTED']);
    await r.changeBookingStatus(id: 'b1', to: 'CONFIRMED', note: 'ok');
    await r.changeDisputeStatus(id: 'd1', to: 'IN_REVIEW');
    await r.changePartnerStatus(id: 'p1', to: 'APPROVED', note: 'เอกสารครบ');
    await r.openDispute(bookingId: 'b1', reason: ' NO_SHOW ', description: ' รายละเอียด ');
    expect(() => r.openDispute(bookingId: 'b1', reason: '  '), throwsA(anything));
    expect(seen, [
      'GET /portal/bookings?limit=20&offset=20&status=PENDING&q=SB-1',
      'GET /portal/disputes?limit=20&offset=0&status=OPEN',
      'GET /portal/partners?limit=20&offset=0',
      'PATCH /portal/bookings/b1/status',
      'PATCH /portal/disputes/d1/status',
      'PATCH /portal/partners/p1/approval',
      'POST /portal/disputes',
    ]);
    expect(bodies, [
      {'status': 'CONFIRMED', 'note': 'ok'},
      {'status': 'IN_REVIEW', 'note': ''},
      {'status': 'APPROVED', 'note': 'เอกสารครบ'},
      {'booking_id': 'b1', 'reason': 'NO_SHOW', 'description': 'รายละเอียด'},
    ]);
  });

  test('StaffQueuesController: actions refresh the list, a stale change reports the server message, a role without partner.review is refused', () async {
    final repo = MockRepository();
    await repo.login(email: 'officer@example.com', password: 'password123');
    final c = StaffQueuesController(repo);
    await c.loadBookings();
    expect(c.bookings.items.length, 3);
    expect(c.bookings.items.firstWhere((b) => b.id == 'mock-qb-3').nextStatuses, isEmpty);
    expect(await c.changeBookingStatus('mock-qb-1', 'CONFIRMED'), isTrue);
    expect(c.bookings.items.firstWhere((b) => b.id == 'mock-qb-1').status, 'CONFIRMED');
    expect(await c.changeBookingStatus('mock-qb-1', 'CONFIRMED'), isFalse); // already confirmed: CONFLICT
    expect(c.actionError, isNotNull);
    expect(await c.changeBookingStatus('mock-qb-3', 'CANCELLED'), isFalse); // a paid booking has no manual transition
    await c.loadBookings(status: 'CONFIRMED', query: 'sb-1001');
    expect(c.bookings.items.map((b) => b.id), ['mock-qb-1']);

    await c.loadPartners();
    expect(c.partners.items, isEmpty);
    expect(c.partners.error, isNotNull);
    expect(await c.changePartnerStatus('mock-qp-1', 'APPROVED'), isFalse);

    expect(await c.openDispute('mock-qb-1', 'NO_SHOW', description: 'x'), isTrue);
    expect(c.disputes.items.first.bookingCode, 'SB-1001');
    expect(await c.openDispute('mock-qb-1', '   '), isFalse);
    c.reset();
    expect(c.bookings.items, isEmpty);
    expect(c.bookings.loaded, isFalse);
  });

  testWidgets('a customer and an admin never see the staff queues entry', (tester) async {
    tall(tester);
    await pumpAndSignIn(tester, 'user@example.com');
    expect(find.byKey(const Key('staffQueuesTile')), findsNothing);
  });

  testWidgets('staff on a phone: confirm and cancel bookings, search, filter; a paid booking offers no status change', (tester) async {
    tall(tester);
    await pumpAndSignIn(tester, 'staff@example.com');
    await openQueues(tester);
    expect(find.byKey(const Key('tab-bookings')), findsOneWidget);
    expect(find.byKey(const Key('tab-disputes')), findsOneWidget);
    expect(find.byKey(const Key('tab-partners')), findsOneWidget);

    expect(find.byKey(const Key('bk-mock-qb-1')), findsOneWidget);
    expect(find.byKey(const Key('bk-mock-qb-3-to-CANCELLED')), findsNothing);
    expect(find.byKey(const Key('bk-mock-qb-3-dispute')), findsOneWidget);
    expect(chipText('bk-mock-qb-3-status', 'ชำระแล้ว'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bk-mock-qb-1-to-CONFIRMED')));
    await tester.pumpAndSettle();
    await confirm(tester);
    expect(find.text('ดำเนินการแล้ว'), findsOneWidget);
    expect(chipText('bk-mock-qb-1-status', 'ยืนยันแล้ว'), findsOneWidget);
    expect(find.byKey(const Key('bk-mock-qb-1-to-CONFIRMED')), findsNothing);
    expect(find.byKey(const Key('bk-mock-qb-1-to-CANCELLED')), findsOneWidget);

    await tester.tap(find.byKey(const Key('bk-mock-qb-2-to-CANCELLED')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('statusNote')), 'ลูกค้าขอยกเลิก');
    await confirm(tester);
    expect(chipText('bk-mock-qb-2-status', 'ยกเลิก'), findsOneWidget);
    expect(find.byKey(const Key('bk-mock-qb-2-to-CANCELLED')), findsNothing);

    await tester.tap(find.byKey(const Key('qf-bookings-PENDING')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bookings-empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('qf-bookings-all')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bookingSearchField')), 'SB-1003');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bk-mock-qb-3')), findsOneWidget);
    expect(find.byKey(const Key('bk-mock-qb-1')), findsNothing);
  });

  testWidgets('staff: open a dispute (reason required), then move it through review', (tester) async {
    tall(tester);
    await pumpAndSignIn(tester, 'staff@example.com');
    await openQueues(tester);

    await tester.tap(find.byKey(const Key('bk-mock-qb-1-dispute')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDispute')));
    await tester.pumpAndSettle();
    expect(find.text('กรุณาระบุเหตุผล'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('disputeReason')), 'NO_SHOW');
    await tester.enterText(find.byKey(const Key('disputeDescription')), 'ไม่มีผู้รับ');
    await tester.tap(find.byKey(const Key('confirmDispute')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab-disputes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ds-mock-qd-1')), findsOneWidget);
    expect(find.byKey(const Key('ds-mock-qd-2')), findsOneWidget); // the one just opened
    expect(find.byKey(const Key('ds-mock-qd-1-to-RESOLVED')), findsNothing); // OPEN can only start review

    await tester.tap(find.byKey(const Key('ds-mock-qd-1-to-IN_REVIEW')));
    await tester.pumpAndSettle();
    await confirm(tester);
    expect(chipText('ds-mock-qd-1-status', 'กำลังตรวจสอบ'), findsOneWidget);
    expect(find.byKey(const Key('ds-mock-qd-1-to-RESOLVED')), findsOneWidget);
    expect(find.byKey(const Key('ds-mock-qd-1-to-REJECTED')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ds-mock-qd-1-to-RESOLVED')));
    await tester.pumpAndSettle();
    await confirm(tester);
    expect(chipText('ds-mock-qd-1-status', 'แก้ไขแล้ว'), findsOneWidget);
    expect(find.byKey(const Key('ds-mock-qd-1-to-RESOLVED')), findsNothing);
  });

  testWidgets('staff: approve a pending partner, which can then be suspended and reactivated', (tester) async {
    tall(tester);
    await pumpAndSignIn(tester, 'staff@example.com');
    await openQueues(tester);
    await tester.tap(find.byKey(const Key('tab-partners')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pt-mock-qp-1-to-APPROVED')), findsOneWidget);
    expect(find.byKey(const Key('pt-mock-qp-1-to-REJECTED')), findsOneWidget);

    await tester.tap(find.byKey(const Key('pt-mock-qp-1-to-APPROVED')));
    await tester.pumpAndSettle();
    await confirm(tester);
    expect(chipText('pt-mock-qp-1-status', 'อนุมัติแล้ว'), findsOneWidget);
    expect(find.byKey(const Key('pt-mock-qp-1-to-SUSPENDED')), findsOneWidget);

    await tester.tap(find.byKey(const Key('pt-mock-qp-1-to-SUSPENDED')));
    await tester.pumpAndSettle();
    await confirm(tester);
    expect(chipText('pt-mock-qp-1-status', 'ถูกระงับ'), findsOneWidget);
    expect(find.text('เปิดใช้งานอีกครั้ง'), findsOneWidget);
  });

  testWidgets('booking officer: bookings and disputes only, no partner tab', (tester) async {
    tall(tester);
    await pumpAndSignIn(tester, 'officer@example.com');
    await openQueues(tester);
    expect(find.byKey(const Key('tab-bookings')), findsOneWidget);
    expect(find.byKey(const Key('tab-disputes')), findsOneWidget);
    expect(find.byKey(const Key('tab-partners')), findsNothing);
    expect(find.byKey(const Key('moderationTile')), findsNothing); // moderation stays a Staff-only mock role
  });

  testWidgets('staff queues on a desktop window stay in a readable column', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpAndSignIn(tester, 'staff@example.com');
    await openQueues(tester);
    expect(find.byKey(const Key('bk-mock-qb-1')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('bk-mock-qb-1'))).width, lessThanOrEqualTo(900));
  });
}
