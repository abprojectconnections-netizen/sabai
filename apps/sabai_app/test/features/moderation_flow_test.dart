import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabai_app/src/app.dart';
import 'package:sabai_app/src/core/config/app_config.dart';
import 'package:sabai_app/src/data/models/community_models.dart';
import 'package:sabai_app/src/data/repositories/http_repository.dart';
import 'package:sabai_app/src/data/repositories/mock_repository.dart';
import 'package:sabai_app/src/state/moderation_controller.dart';
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

void main() {
  test('AccountInfo gates the moderation screen on both permissions', () {
    expect(const AccountInfo(permissions: ['portal.read', 'support.manage']).canModerateCommunity, isTrue);
    expect(const AccountInfo(permissions: ['portal.read']).canModerateCommunity, isFalse);
    expect(const AccountInfo(permissions: ['support.manage']).canModerateCommunity, isFalse);
    expect(AccountInfo.fromJson({'roles': ['STAFF'], 'permissions': ['portal.read', 'support.manage']}).canModerateCommunity, isTrue);
    expect(AccountInfo.fromJson({}).canModerateCommunity, isFalse);
  });

  test('HttpRepository: /me, queue and moderation use the documented routes', () async {
    final seen = <String>[];
    final bodies = <Object?>[];
    final r = HttpRepository(
      client: MockClient((req) async {
        seen.add('${req.method} ${req.url.path}');
        if (req.body.isNotEmpty) bodies.add(jsonDecode(req.body));
        if (req.url.path == '/me') return json(200, {'data': {'id': 'u', 'roles': ['STAFF'], 'permissions': ['portal.read', 'support.manage']}});
        if (req.method == 'GET') {
          return json(200, {'data': {'items': [{'id': 'p1', 'body': 'x', 'author_name': 'ก', 'created_at': '2030-01-02T00:00:00Z', 'report_count': 2, 'reasons': ['SPAM', 'ABUSE']}]}});
        }
        return json(200, {'data': {'action': 'remove'}});
      }),
      baseUrl: 'https://api.test',
      mode: ApiMode.beta,
      pollDelay: Duration.zero,
    );
    expect((await r.accountInfo()).canModerateCommunity, isTrue);
    final q = await r.reportedPosts();
    expect((q.single.reportCount, q.single.reasons), (2, ['SPAM', 'ABUSE']));
    await r.moderatePost(id: 'p1', action: 'remove', note: 'spam');
    await r.moderatePost(id: 'p1', action: 'dismiss');
    expect(() => r.moderatePost(id: 'p1', action: 'ban'), throwsA(anything));
    expect(seen, ['GET /me', 'GET /portal/community/reports', 'POST /portal/community/posts/p1/remove', 'POST /portal/community/posts/p1/dismiss']);
    expect(bodies, [{'note': 'spam'}, {'note': ''}]);
  });

  test('ModerationController: a forbidden user sees the server message and an empty queue', () async {
    final repo = MockRepository();
    await repo.login(email: 'user@example.com', password: 'password123');
    final c = ModerationController(repo);
    await c.load();
    expect(c.queue, isEmpty);
    expect(c.error, isNotNull);
    expect(await c.act('mock-report-1', 'remove'), isFalse);
  });

  testWidgets('a customer never sees the moderation entry', (tester) async {
    await pumpAndSignIn(tester, 'user@example.com');
    expect(find.byKey(const Key('moderationTile')), findsNothing);
    expect(find.byKey(const Key('couponsTile')), findsOneWidget);
  });

  testWidgets('staff on a phone: review the queue, dismiss one and remove the other', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpAndSignIn(tester, 'staff@example.com');
    await tester.tap(find.byKey(const Key('moderationTile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-mock-report-1')), findsOneWidget);
    expect(find.text('รายงาน 2 ครั้ง'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dismiss-mock-report-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('moderationNote')), 'ไม่ผิดกฎ');
    await tester.tap(find.byKey(const Key('confirmModeration')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-mock-report-1')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('remove-mock-report-2')));
    await tester.tap(find.byKey(const Key('remove-mock-report-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmModeration')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('queueEmpty')), findsOneWidget);
  });

  testWidgets('staff on a desktop-sized window: actions sit beside the post', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpAndSignIn(tester, 'staff@example.com');
    await tester.tap(find.byKey(const Key('moderationTile')));
    await tester.pumpAndSettle();
    final body = tester.getTopLeft(find.textContaining('โปรโมชันสุดคุ้ม'));
    final remove = tester.getTopLeft(find.byKey(const Key('remove-mock-report-1')));
    expect(remove.dx, greaterThan(body.dx + 200)); // side by side, not stacked under the text
    expect(tester.getSize(find.byKey(const Key('report-mock-report-1'))).width, lessThanOrEqualTo(900));
  });
}
