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

/// Sign in from the profile tab, then book the first listing so a confirmed booking exists.
Future<void> signInAndBook(WidgetTester tester) async {
  await tester.tap(find.text('โปรไฟล์'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('เข้าสู่ระบบ / สมัครสมาชิก'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('emailField')), 'demo@example.com');
  await tester.enterText(find.byKey(const Key('passwordField')), 'password123');
  await tester.tap(find.byKey(const Key('submitButton')));
  await tester.pumpAndSettle();

  await tester.tap(find.text('ค้นหา'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ล้านนา วิว รีสอร์ท'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('bookButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('payButton')));
  await tester.pumpAndSettle();
  expect(find.text('จองสำเร็จ'), findsOneWidget);
  await tester.tap(find.text('กลับหน้าหลัก'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bell shows the unread count and notifications can be read', (tester) async {
    await pumpApp(tester);
    expect(find.byKey(const Key('notificationBell')), findsNothing); // signed out
    await signInAndBook(tester);

    expect(find.byKey(const Key('notificationBell')), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // badge
    await tester.tap(find.byKey(const Key('notificationBell')));
    await tester.pumpAndSettle();
    expect(find.text('ยินดีต้อนรับสู่ Sabai'), findsOneWidget);
    await tester.tap(find.byKey(const Key('notification-mock-n-1')));
    await tester.pumpAndSettle();
    final markAll = tester.widget<TextButton>(find.byKey(const Key('markAllReadButton')));
    expect(markAll.onPressed, isNull); // nothing unread any more
  });

  testWidgets('review a booking with tags, see it in my reviews, delete it', (tester) async {
    await pumpApp(tester);
    await signInAndBook(tester);

    await tester.tap(find.text('การจอง'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เขียนรีวิว'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('submitReviewButton'))); // no rating yet
    await tester.pumpAndSettle();
    expect(find.text('กรุณาให้คะแนนอย่างน้อย 1 ดาว'), findsOneWidget);

    await tester.tap(find.byKey(const Key('star4')));
    await tester.enterText(find.byKey(const Key('reviewBodyField')), 'ที่พักสะอาด');
    await tester.enterText(find.byKey(const Key('reviewTagsField')), 'ธรรมชาติ, คาเฟ่');
    await tester.tap(find.byKey(const Key('submitReviewButton')));
    await tester.pumpAndSettle();
    expect(find.text('เขียนรีวิว'), findsNothing); // already reviewed: action is gone

    await tester.tap(find.text('โปรไฟล์'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('myReviewsTile')));
    await tester.pumpAndSettle();
    expect(find.textContaining('4 ดาว'), findsOneWidget);
    expect(find.textContaining('#ธรรมชาติ #คาเฟ่'), findsOneWidget);

    await tester.tap(find.byTooltip('ลบรีวิว'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDeleteReview')));
    await tester.pumpAndSettle();
    expect(find.textContaining('ยังไม่มีรีวิว'), findsOneWidget);
  });
}
