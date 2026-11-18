import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabai_app/src/app.dart';
import 'package:sabai_app/src/core/config/app_config.dart';
import 'package:sabai_app/src/data/repositories/mock_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  testWidgets('community asks for sign-in, then posts with a tag, reports another post and deletes its own', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('ชุมชน'));
    await tester.pumpAndSettle();
    expect(find.text('กรุณาเข้าสู่ระบบเพื่อดูข้อมูลนี้'), findsOneWidget);

    await signIn(tester);
    await tester.tap(find.text('ชุมชน'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('post-mock-post-seed')), findsOneWidget);

    await tester.tap(find.byKey(const Key('composePostButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submitPostButton'))); // empty
    await tester.pumpAndSettle();
    expect(find.text('กรุณาเขียนข้อความ'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('postBodyField')), 'ทะเลสวยมาก');
    await tester.enterText(find.byKey(const Key('postTagsField')), 'ทะเล');
    await tester.tap(find.byKey(const Key('submitPostButton')));
    await tester.pumpAndSettle();
    expect(find.text('ทะเลสวยมาก'), findsOneWidget);
    expect(find.textContaining('#ทะเล'), findsOneWidget);

    await tester.tap(find.byKey(const Key('report-mock-post-seed')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reason-SPAM')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('post-mock-post-seed')), findsNothing);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDeletePost')));
    await tester.pumpAndSettle();
    expect(find.text('ทะเลสวยมาก'), findsNothing);
  });

  testWidgets('coupons: notice, claim, error, saved list', (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    await tester.tap(find.byKey(const Key('couponsTile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('couponNotice')), findsOneWidget);
    expect(find.textContaining('ยังใช้ลดราคาในแอปไม่ได้'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('couponCodeField')), 'NOPE');
    await tester.tap(find.byKey(const Key('claimCouponButton')));
    await tester.pumpAndSettle();
    expect(find.text('ไม่พบรหัสคูปองนี้'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('couponCodeField')), 'sabai10');
    await tester.tap(find.byKey(const Key('claimCouponButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('couponSaved')), findsOneWidget);
    expect(find.byKey(const Key('coupon-SABAI10')), findsOneWidget);
    expect(find.text('ใช้งานได้'), findsOneWidget);
  });

  testWidgets('help is available signed out and shows an answer when expanded', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('โปรไฟล์'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('couponsTile')), findsNothing); // coupons need sign-in
    await tester.tap(find.byKey(const Key('helpTile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('faq-3')));
    await tester.pumpAndSettle();
    expect(find.textContaining('บันทึกรหัสคูปองไว้ดูสถานะได้อย่างเดียว'), findsOneWidget);
  });
}
