import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabai_app/src/app.dart';
import 'package:sabai_app/src/core/config/app_config.dart';
import 'package:sabai_app/src/data/repositories/mock_repository.dart';

void main() {
  testWidgets('browse, sign in, pay and see the booking (mock repository)', (tester) async {
    await tester.pumpWidget(SabaiApp(
      config: AppConfig.parse(const {}),
      repository: MockRepository(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ล้านนา วิว รีสอร์ท'), findsOneWidget);

    await tester.tap(find.text('ล้านนา วิว รีสอร์ท'));
    await tester.pumpAndSettle();
    expect(find.text('เข้าสู่ระบบเพื่อจอง'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bookButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('emailField')), 'demo@example.com');
    await tester.enterText(find.byKey(const Key('passwordField')), 'password123');
    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pumpAndSettle();

    expect(find.text('จองและชำระเงิน'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bookButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('payButton')));
    await tester.pumpAndSettle();

    expect(find.text('จองสำเร็จ'), findsOneWidget);
    expect(find.byKey(const Key('bookingCode')), findsOneWidget);
  });

  testWidgets('sold-out items cannot be booked', (tester) async {
    await tester.pumpWidget(SabaiApp(
      config: AppConfig.parse(const {}),
      repository: MockRepository(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('อันดามัน บีช วิลลา'));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.byKey(const Key('bookButton')));
    expect(button.onPressed, isNull);
  });
}
