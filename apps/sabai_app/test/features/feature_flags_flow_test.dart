import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabai_app/src/app.dart';
import 'package:sabai_app/src/core/config/app_config.dart';
import 'package:sabai_app/src/core/errors/api_error.dart';
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

bool flagValue(WidgetTester tester, String key) => tester.widget<SwitchListTile>(find.byKey(Key('flag-$key'))).value;

void main() {
  test('FeatureFlag parses the documented payload; an absent enabled means on like the server', () {
    final f = FeatureFlag.fromJson({'key': 'community.posting', 'description': 'd', 'enabled': false, 'updated_by': 'a@b.co'});
    expect(f.key, 'community.posting');
    expect(f.enabled, isFalse);
    expect(f.updatedBy, 'a@b.co');
    expect(FeatureFlag.fromJson({'key': 'x'}).enabled, isTrue);
    expect(f.copyWith(enabled: true).enabled, isTrue);
  });

  test('AccountInfo: config.manage opens the console on its own, and FEATURE_DISABLED has a Thai message', () {
    expect(const AccountInfo(permissions: ['config.manage']).canManageConfig, isTrue);
    expect(const AccountInfo(permissions: ['config.manage']).hasAdminConsole, isTrue);
    expect(const AccountInfo(permissions: ['portal.read']).canManageConfig, isFalse);
    expect(describeApiErrorTh(const ApiError(code: 'FEATURE_DISABLED', message: 'x', status: 503)), contains('ปิดชั่วคราว'));
  });

  test('HttpRepository: flags use the documented routes and body', () async {
    final seen = <String>[];
    Object? body;
    final r = HttpRepository(
      client: MockClient((req) async {
        seen.add('${req.method} ${req.url.path}');
        if (req.method == 'PATCH') {
          body = jsonDecode(req.body);
          return json(200, {'data': {'key': 'community.posting', 'enabled': false}});
        }
        return json(200, {
          'data': {
            'items': [
              {'key': 'community.posting', 'description': 'd', 'enabled': true, 'updated_at': '2030-01-01T00:00:00Z', 'updated_by': null}
            ]
          }
        });
      }),
      baseUrl: 'https://api.test',
      mode: ApiMode.beta,
      pollDelay: Duration.zero,
    );
    final flags = await r.featureFlags();
    expect(flags.single.key, 'community.posting');
    expect(flags.single.updatedBy, isNull);
    await r.setFeatureFlag(key: 'community.posting', enabled: false, reason: '  สแปม  ');
    expect(seen, ['GET /admin/feature-flags', 'PATCH /admin/feature-flags/community.posting']);
    expect(body, {'enabled': false, 'reason': 'สแปม'});
    await r.setFeatureFlag(key: 'community.posting', enabled: true);
    expect(body, {'enabled': true}); // no reason key when there is none
  });

  test('AdminController: only config.manage may read or switch; a reason is needed to turn off; state follows the server', () async {
    final customer = MockRepository();
    await customer.login(email: 'user@example.com', password: 'password123');
    final d = AdminController(customer);
    await d.loadFlags();
    expect(d.flags, isEmpty);
    expect(d.flagsError, isNotNull);

    final auditor = MockRepository();
    await auditor.login(email: 'auditor@example.com', password: 'password123');
    final a = AdminController(auditor);
    await a.loadFlags();
    expect(a.flagsError, isNotNull); // audit.read is not config.manage

    final repo = MockRepository();
    await repo.login(email: 'admin@example.com', password: 'password123');
    final c = AdminController(repo);
    await c.loadFlags();
    expect(c.flags.map((f) => f.key), ['community.posting', 'coupons.claiming']);
    expect(c.flags.every((f) => f.enabled), isTrue);

    expect(await c.setFlag('community.posting', false), isFalse); // reason required
    expect(c.actionError, isNotNull);
    expect(c.flags.first.enabled, isTrue);
    expect(await c.setFlag('no.such.flag', true), isFalse);
    expect(await c.setFlag('community.posting', false, reason: 'สแปมท่วมชุมชน'), isTrue);
    expect(c.actionError, isNull);
    expect(c.flags.firstWhere((f) => f.key == 'community.posting').enabled, isFalse);
    expect(c.flags.firstWhere((f) => f.key == 'community.posting').updatedBy, 'admin@example.com');
    expect(c.flags.firstWhere((f) => f.key == 'coupons.claiming').enabled, isTrue);

    c.reset();
    await Future<void>.delayed(Duration.zero);
    expect(c.flags, isEmpty);
  });

  testWidgets('admin: sees the flags, must give a reason to turn one off, can turn it back on', (tester) async {
    tall(tester);
    await pumpAndSignIn(tester, 'admin@example.com');
    await tester.tap(find.byKey(const Key('adminConsoleTile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flagsTile')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('flag-community.posting')), findsOneWidget);
    expect(find.byKey(const Key('flag-coupons.claiming')), findsOneWidget);
    expect(flagValue(tester, 'community.posting'), isTrue);

    await tester.tap(find.byKey(const Key('flag-community.posting')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmFlagOff')));
    await tester.pumpAndSettle();
    expect(find.text('กรุณาระบุเหตุผลอย่างน้อย 3 ตัวอักษร'), findsOneWidget);
    expect(flagValue(tester, 'community.posting'), isTrue); // nothing changed yet

    await tester.enterText(find.byKey(const Key('flagReasonField')), 'สแปมท่วมชุมชน');
    await tester.tap(find.byKey(const Key('confirmFlagOff')));
    await tester.pumpAndSettle();
    expect(flagValue(tester, 'community.posting'), isFalse);
    expect(flagValue(tester, 'coupons.claiming'), isTrue);
    expect(find.textContaining('แก้ไขล่าสุดโดย admin@example.com'), findsOneWidget);

    // Cancelling the dialog changes nothing.
    await tester.tap(find.byKey(const Key('flag-coupons.claiming')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(flagValue(tester, 'coupons.claiming'), isTrue);

    // Turning on needs no reason.
    await tester.tap(find.byKey(const Key('flag-community.posting')));
    await tester.pumpAndSettle();
    expect(flagValue(tester, 'community.posting'), isTrue);
  });

  testWidgets('auditor and staff never see the flags entry', (tester) async {
    tall(tester);
    await pumpAndSignIn(tester, 'auditor@example.com');
    await tester.tap(find.byKey(const Key('adminConsoleTile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auditTile')), findsOneWidget);
    expect(find.byKey(const Key('flagsTile')), findsNothing);
  });
}
