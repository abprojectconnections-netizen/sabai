import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabai_app/src/app.dart';
import 'package:sabai_app/src/core/config/app_config.dart';
import 'package:sabai_app/src/data/repositories/mock_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('flights list from the catalogue, filter, book, and a simulated failed payment can be retried', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SabaiApp(
      config: AppConfig.parse(const {}),
      repository: MockRepository(),
      prefs: await SharedPreferences.getInstance(),
    ));
    await tester.pumpAndSettle();

    // sign in
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

    await tester.tap(find.byKey(const Key('flightsDemoTile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flightsSandboxNotice')), findsOneWidget);
    expect(find.byKey(const Key('flight-mock-flight-1')), findsOneWidget);
    expect(find.byKey(const Key('flight-mock-flight-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sort-earliest')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('flight-mock-flight-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bookButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('simulateFailButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('paymentFailed')), findsOneWidget);
    expect(find.textContaining('ไม่มีการตัดเงิน'), findsWidgets);

    await tester.tap(find.byKey(const Key('payButton'))); // retry, this time it succeeds
    await tester.pumpAndSettle();
    expect(find.text('จองสำเร็จ'), findsOneWidget);
    expect(find.byKey(const Key('bookingCode')), findsOneWidget);
  });
}
