import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabai_app/src/app.dart';
import 'package:sabai_app/src/core/config/app_config.dart';
import 'package:sabai_app/src/data/repositories/mock_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<List<Uri>> pumpApp(WidgetTester tester, {bool openOk = true}) async {
  SharedPreferences.setMockInitialValues({});
  final opened = <Uri>[];
  await tester.pumpWidget(SabaiApp(
    config: AppConfig.parse(const {}),
    repository: MockRepository(),
    prefs: await SharedPreferences.getInstance(),
    urlOpener: (u) async {
      opened.add(u);
      return openOk;
    },
  ));
  await tester.pumpAndSettle();
  return opened;
}

Future<void> signIn(WidgetTester tester) async {
  await tester.tap(find.text('โปรไฟล์'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('เข้าสู่ระบบ / สมัครสมาชิก'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('emailField')), 'demo@example.com');
  await tester.enterText(find.byKey(const Key('passwordField')), 'password123');
  await tester.tap(find.byKey(const Key('submitButton')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('planner makes a trip from a template and maps links open for its activities', (tester) async {
    final opened = await pumpApp(tester);
    await signIn(tester);
    await tester.tap(find.text('ทริป'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plannerTile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plannerNotice')), findsOneWidget);
    expect(find.textContaining('ไม่ใช่ AI'), findsWidgets);

    await tester.tap(find.byKey(const Key('generatePlanButton'))); // nothing filled in
    await tester.pumpAndSettle();
    expect(find.text('กรุณากรอกจุดหมายปลายทาง'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('plannerDestinationField')), 'ภูเก็ต');
    await tester.tap(find.byKey(const Key('generatePlanButton'))); // no date yet
    await tester.pumpAndSettle();
    expect(find.text('กรุณาเลือกวันเริ่มเดินทาง'), findsOneWidget);

    await tester.tap(find.byKey(const Key('plannerStartTile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('daysMinus'))); // 3 -> 2
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('generatePlanButton')));
    await tester.pumpAndSettle();
    expect(find.text('วันที่ 2 · ภูเก็ต', skipOffstage: false), findsOneWidget);
    expect(find.text('วันที่ 3 · ภูเก็ต', skipOffstage: false), findsNothing);

    await tester.scrollUntilVisible(find.byKey(const Key('savePlanButton')), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('savePlanButton')));
    await tester.pumpAndSettle();
    expect(find.text('ทริปภูเก็ต 2 วัน'), findsWidgets); // now on the trip detail
    expect(find.text('อาหารเย็นและพักผ่อน'), findsWidgets);
    expect(find.byKey(const Key('route-day-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('route-day-1')));
    await tester.pumpAndSettle();
    expect(opened.single.path, '/maps/dir/');
    expect(opened.single.queryParameters['destination'], 'อาหารเย็นและพักผ่อน');
    expect(opened.single.queryParameters['waypoints']!.split('|').length, 3);

    await tester.tap(find.byTooltip('เปิดใน Google Maps').first);
    await tester.pumpAndSettle();
    expect(opened.last.path, '/maps/search/');
  });
}
