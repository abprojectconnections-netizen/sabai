import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabai_app/src/app.dart';
import 'package:sabai_app/src/core/config/app_config.dart';
import 'package:sabai_app/src/data/models/admin_models.dart';
import 'package:sabai_app/src/data/models/community_models.dart';
import 'package:sabai_app/src/data/repositories/http_repository.dart';
import 'package:sabai_app/src/data/repositories/mock_repository.dart';
import 'package:sabai_app/src/state/admin_controller.dart';
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

Future<void> openConsole(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('adminConsoleTile')));
  await tester.pumpAndSettle();
}

void main() {
  test('AccountInfo: console gates follow the permissions the server reports', () {
    expect(const AccountInfo(permissions: ['user.manage']).canManageUsers, isTrue);
    expect(const AccountInfo(permissions: ['user.manage']).canReadAudit, isFalse);
    expect(const AccountInfo(permissions: ['audit.read']).hasAdminConsole, isTrue);
    expect(const AccountInfo(permissions: ['portal.read', 'support.manage']).hasAdminConsole, isFalse);
    expect(const AccountInfo(permissions: ['portal.read']).canViewDashboard, isTrue);
    expect(const AccountInfo().canViewDashboard, isFalse);
  });

  test('models parse the documented payloads and tolerate missing fields', () {
    final u = AdminUser.fromJson({
      'id': 'u1',
      'email': 'a@b.co',
      'status': 'SUSPENDED',
      'roles': ['CUSTOMER', 'STAFF'],
      'created_at': '2030-01-02T00:00:00Z',
      'last_login_at': null,
      'display_name': 'ก',
      'pending_role_requests': [
        {'role': 'PARTNER', 'request_id': 'r', 'created_at': 'x'}
      ],
    });
    expect(u.suspended, isTrue);
    expect(u.lastLoginAt, isNull);
    expect(u.pendingRoles, ['PARTNER']);
    expect(u.copyWith(status: 'ACTIVE').suspended, isFalse);
    expect(AdminUser.fromJson(const {}).roles, isEmpty);

    final s = DashboardStats.fromJson({
      'users': {'total': 5, 'active': 4, 'suspended': 1, 'new_last_7_days': 2},
      'bookings': {
        'by_status': {'CONFIRMED': 3, 'PENDING': 2},
        'created_last_7_days': 1
      },
      'payments': {
        'by_status': {'SUCCEEDED': 3}
      },
      'queues': {'tickets_open': 7},
    });
    expect(s.usersTotal, 5);
    expect(s.bookingsTotal, 5);
    expect(s.queue('tickets_open'), 7);
    expect(s.queue('missing'), 0);
    expect(DashboardStats.fromJson(const {}).usersTotal, 0);

    final a = AuditEntry.fromJson({
      'id': 'a1',
      'created_at': '2030-01-02T00:00:00Z',
      'actor_email': 'x@y.co',
      'action': 'user.status.changed',
      'subject_type': 'user',
      'subject_id': 'u1',
      'before': {'status': 'ACTIVE'},
      'after': null,
    });
    expect(a.before, {'status': 'ACTIVE'});
    expect(a.after, isNull);
  });

  test('HttpRepository: admin endpoints use the documented routes, filters and body', () async {
    final seen = <String>[];
    Object? patchBody;
    final r = HttpRepository(
      client: MockClient((req) async {
        seen.add('${req.method} ${req.url.path}?${req.url.query}');
        if (req.method == 'PATCH') {
          patchBody = jsonDecode(req.body);
          return json(200, {'data': {'id': 'u1', 'status': 'SUSPENDED'}});
        }
        switch (req.url.path) {
          case '/admin/dashboard':
            return json(200, {'data': {'users': {'total': 3}, 'queues': {'tickets_open': 1}}});
          case '/admin/users':
            return json(200, {
              'data': {
                'items': [
                  {'id': 'u1', 'email': 'a@b.co', 'status': 'ACTIVE', 'roles': ['CUSTOMER'], 'created_at': '2030-01-01T00:00:00Z'}
                ],
                'total': 41,
              }
            });
          case '/admin/users/u1':
            return json(200, {'data': {'id': 'u1', 'email': 'a@b.co', 'status': 'ACTIVE', 'roles': [], 'display_name': 'ก'}});
          case '/admin/audit-logs':
            return json(200, {
              'data': {
                'items': [
                  {'id': 'a1', 'action': 'user.status.changed', 'actor_email': 'x@y.co', 'subject_type': 'user', 'subject_id': 'u1'}
                ],
                'total': 9,
              }
            });
        }
        return json(404, {'error': {'code': 'NOT_FOUND', 'message': 'x'}});
      }),
      baseUrl: 'https://api.test',
      mode: ApiMode.beta,
      pollDelay: Duration.zero,
    );
    expect((await r.adminDashboard()).usersTotal, 3);
    final page = await r.adminUsers(query: ' a_b ', status: 'SUSPENDED', offset: 20, limit: 20);
    expect(page.total, 41);
    expect(page.items.single.email, 'a@b.co');
    expect((await r.adminUser('u1')).displayName, 'ก');
    await r.setUserStatus(id: 'u1', status: 'SUSPENDED', reason: 'สแปม');
    expect(patchBody, {'status': 'SUSPENDED', 'reason': 'สแปม'});
    expect(() => r.setUserStatus(id: 'u1', status: 'BANNED'), throwsA(anything));
    final audit = await r.auditLogs(action: 'user.status.changed', offset: 0, limit: 5);
    expect(audit.total, 9);
    expect(audit.items.single.subjectId, 'u1');
    expect(seen, [
      'GET /admin/dashboard?',
      'GET /admin/users?limit=20&offset=20&q=a_b&status=SUSPENDED',
      'GET /admin/users/u1?',
      'PATCH /admin/users/u1/status?',
      'GET /admin/audit-logs?limit=5&offset=0&action=user.status.changed',
    ]);
  });

  test('AdminController: a customer gets the server message; a status change drops the row from a filtered list', () async {
    final denied = MockRepository();
    await denied.login(email: 'user@example.com', password: 'password123');
    final d = AdminController(denied);
    await d.loadUsers(query: '', status: '');
    expect(d.users, isEmpty);
    expect(d.usersError, isNotNull);
    await d.loadAudit(action: '');
    expect(d.auditError, isNotNull);

    final repo = MockRepository();
    await repo.login(email: 'admin@example.com', password: 'password123');
    final c = AdminController(repo);
    await c.loadUsers(query: '', status: 'SUSPENDED');
    expect(c.users.map((u) => u.id), ['mock-user-3']);
    expect(await c.setStatus('mock-user-3', 'ACTIVE'), isTrue);
    expect(c.users, isEmpty);
    expect(c.usersTotal, 0);
    await c.loadUsers(query: '', status: '');
    expect(c.users.firstWhere((u) => u.id == 'mock-user-3').suspended, isFalse);

    expect(await c.setStatus('mock-user-1', 'SUSPENDED'), isFalse); // reason is required
    expect(c.actionError, isNotNull);
    expect(await c.setStatus('mock-admin', 'SUSPENDED', reason: 'ทดสอบ'), isFalse); // never your own account
    expect(await c.setStatus('mock-user-1', 'SUSPENDED', reason: 'สแปมซ้ำ'), isTrue);
    expect(c.actionError, isNull);
  });

  testWidgets('a customer and a moderator-only staff member never see the admin console entry', (tester) async {
    tall(tester);
    await pumpAndSignIn(tester, 'user@example.com');
    expect(find.byKey(const Key('adminConsoleTile')), findsNothing);
  });

  testWidgets('staff (moderation only) has no admin console but keeps the moderation entry', (tester) async {
    tall(tester);
    await pumpAndSignIn(tester, 'staff@example.com');
    expect(find.byKey(const Key('adminConsoleTile')), findsNothing);
    expect(find.byKey(const Key('moderationTile')), findsOneWidget);
  });

  testWidgets('admin on a phone: dashboard counts, search, inspect, suspend with a reason, reactivate', (tester) async {
    tall(tester);
    await pumpAndSignIn(tester, 'admin@example.com');
    await openConsole(tester);

    expect(tester.widget<Text>(find.byKey(const Key('stat-users-total'))).data, '4');
    expect(tester.widget<Text>(find.byKey(const Key('stat-users-suspended'))).data, '1');
    expect(find.byKey(const Key('usersTile')), findsOneWidget);
    expect(find.byKey(const Key('auditTile')), findsNothing); // System Admin cannot read the audit trail

    await tester.tap(find.byKey(const Key('usersTile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('user-mock-user-1')), findsOneWidget);
    expect(find.byKey(const Key('badge-mock-user-3')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('userSearchField')), 'mali');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('user-mock-user-2')), findsOneWidget);
    expect(find.byKey(const Key('user-mock-user-1')), findsNothing);

    await tester.tap(find.byKey(const Key('user-mock-user-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detailEmail')), findsOneWidget);
    expect(find.byKey(const Key('pendingRoles')), findsOneWidget);
    expect(find.textContaining('PARTNER_FINANCE'), findsOneWidget);

    // A reason is required; an empty one is rejected inside the dialog.
    await tester.tap(find.byKey(const Key('suspendButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmSuspend')));
    await tester.pumpAndSettle();
    expect(find.text('กรุณาระบุเหตุผลอย่างน้อย 3 ตัวอักษร'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('reasonField')), 'โพสต์สแปมซ้ำ');
    await tester.tap(find.byKey(const Key('confirmSuspend')));
    await tester.pumpAndSettle();
    expect(find.text('ระงับบัญชีแล้ว'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('detailStatus')), matching: find.text('ถูกระงับ')), findsOneWidget);
    expect(find.byKey(const Key('reactivateButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('reactivateButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmReactivate')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('detailStatus')), matching: find.text('ใช้งานอยู่')), findsOneWidget);
    expect(find.byKey(const Key('suspendButton')), findsOneWidget);
  });

  testWidgets('admin cannot suspend their own account; the server message is shown', (tester) async {
    tall(tester);
    await pumpAndSignIn(tester, 'admin@example.com');
    await openConsole(tester);
    await tester.tap(find.byKey(const Key('usersTile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('user-mock-admin')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('suspendButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reasonField')), 'ทดสอบตัวเอง');
    await tester.tap(find.byKey(const Key('confirmSuspend')));
    await tester.pumpAndSettle();
    expect(find.text('คุณไม่มีสิทธิ์ทำรายการนี้'), findsOneWidget);
    expect(find.byKey(const Key('suspendButton')), findsOneWidget); // still active
  });

  testWidgets('auditor: reads the audit trail (read-only) and cannot open the user list', (tester) async {
    tall(tester);
    await pumpAndSignIn(tester, 'auditor@example.com');
    await openConsole(tester);
    expect(find.byKey(const Key('usersTile')), findsNothing);
    expect(find.byKey(const Key('auditTile')), findsOneWidget);
    expect(find.byKey(const Key('stat-users-total')), findsOneWidget);

    await tester.tap(find.byKey(const Key('auditTile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('audit-mock-audit-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('audit-mock-audit-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('โพสต์สแปมซ้ำ'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('auditActionField')), 'role.granted');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auditEmpty')), findsOneWidget);
  });

  testWidgets('admin console on a desktop window stays in a readable column without overflow', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpAndSignIn(tester, 'admin@example.com');
    await openConsole(tester);
    expect(find.byKey(const Key('stat-users-total')), findsOneWidget);
    await tester.tap(find.byKey(const Key('usersTile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('user-mock-user-1')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('userSearchField'))).width, lessThanOrEqualTo(900));
  });
}
