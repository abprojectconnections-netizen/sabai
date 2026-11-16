import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sabai_app/src/app.dart';
import 'package:sabai_app/src/core/config/app_config.dart';
import 'package:sabai_app/src/data/repositories/mock_repository.dart';

Future<void> pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(SabaiApp(
    config: AppConfig.parse(const {}),
    repository: MockRepository(),
    prefs: await SharedPreferences.getInstance(),
  ));
  await tester.pumpAndSettle();
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
  testWidgets('signed out: trips tab asks to sign in', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('ทริป'));
    await tester.pumpAndSettle();
    expect(find.text('กรุณาเข้าสู่ระบบเพื่อดูข้อมูลนี้'), findsOneWidget);
  });

  testWidgets('create a trip, add an activity, delete the trip', (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    expect(find.byKey(const Key('profileName')), findsOneWidget);

    await tester.tap(find.text('ทริป'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ยังไม่มีทริป'), findsOneWidget);

    await tester.tap(find.byKey(const Key('newTripButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveTripButton'))); // empty name is rejected locally
    await tester.pumpAndSettle();
    expect(find.text('กรุณากรอกชื่อทริป'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('tripNameField')), 'เชียงใหม่ 3 วัน');
    await tester.tap(find.byKey(const Key('saveTripButton')));
    await tester.pumpAndSettle();
    expect(find.text('เชียงใหม่ 3 วัน'), findsOneWidget);

    await tester.tap(find.text('เชียงใหม่ 3 วัน'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ยังไม่มีกิจกรรม'), findsOneWidget);
    await tester.tap(find.byKey(const Key('addActivityButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('activityTitleField')), 'ดอยสุเทพ');
    await tester.tap(find.byKey(const Key('saveActivityButton')));
    await tester.pumpAndSettle();
    expect(find.text('ดอยสุเทพ'), findsOneWidget);

    await tester.tap(find.byKey(const Key('deleteTripButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDeleteTrip')));
    await tester.pumpAndSettle();
    expect(find.textContaining('ยังไม่มีทริป'), findsOneWidget);
  });

  testWidgets('sign-out clears trips for the next user', (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    await tester.tap(find.text('ทริป'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('newTripButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tripNameField')), 'ทริปลับ');
    await tester.tap(find.byKey(const Key('saveTripButton')));
    await tester.pumpAndSettle();
    expect(find.text('ทริปลับ'), findsOneWidget);

    await tester.tap(find.text('โปรไฟล์'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logoutTile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ทริป'));
    await tester.pumpAndSettle();
    expect(find.text('ทริปลับ'), findsNothing);
    expect(find.text('กรุณาเข้าสู่ระบบเพื่อดูข้อมูลนี้'), findsOneWidget);
  });

  testWidgets('settings: theme switches the app and the toggles persist', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('โปรไฟล์'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsTile')));
    await tester.pumpAndSettle();
    expect(find.text('ยังไม่เปิดให้ใช้ เพราะระบบหลังบ้านยังไม่รองรับ'), findsOneWidget);

    await tester.tap(find.text('มืด'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byKey(const Key('themeSelector')))).brightness, Brightness.dark);

    await tester.tap(find.byKey(const Key('notifyPromoSwitch')));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.theme'), 'dark');
    expect(prefs.getBool('settings.notify.promo'), isTrue);
  });
}
