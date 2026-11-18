import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabai_app/src/app.dart';
import 'package:sabai_app/src/core/config/app_config.dart';
import 'package:sabai_app/src/data/repositories/mock_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('flights demo is labelled simulated, sorts, and rejects the same airport', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SabaiApp(
      config: AppConfig.parse(const {}),
      repository: MockRepository(),
      prefs: await SharedPreferences.getInstance(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('flightsDemoTile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flightsDemoNotice')), findsOneWidget);
    expect(find.textContaining('จองไม่ได้'), findsWidgets);
    expect(find.textContaining('(จำลอง)'), findsWidgets);

    await tester.tap(find.byKey(const Key('sort-fastest')));
    await tester.pumpAndSettle();
    expect(find.textContaining('BKK→CNX'), findsWidgets);

    await tester.tap(find.byKey(const Key('toField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BKK · กรุงเทพฯ (สุวรรณภูมิ)').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sameAirport')), findsOneWidget);
  });
}
