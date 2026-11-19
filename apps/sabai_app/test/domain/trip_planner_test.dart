import 'package:flutter_test/flutter_test.dart';
import 'package:sabai_app/src/domain/trip_planner.dart';

void main() {
  test('generic plan has one entry per day with four timed slots', () {
    final p = buildPlan(destination: 'ภูเก็ต', days: 2);
    expect(p.length, 2);
    expect(p.first.title, 'วันที่ 1 · ภูเก็ต');
    expect(p.first.items.map((i) => i.time), ['09:00', '13:00', '16:00', '19:00']);
    expect(p.first.items.first.text, contains('ภูเก็ต'));
  });

  test('days are clamped to 1..7 and styles change only the afternoon slot', () {
    expect(buildPlan(destination: 'x', days: 0).length, 1);
    expect(buildPlan(destination: 'x', days: 30).length, maxPlannerDays);
    final p = buildPlan(destination: 'x', days: 1, styles: ['คาเฟ่', 'อาหาร']);
    expect(p.single.items[2].text, 'กิจกรรมตามความสนใจ: คาเฟ่, อาหาร');
    expect(buildPlan(destination: 'x', days: 1).single.items[2].text, 'เดินเล่นชมเมือง');
  });

  test('every title fits the 200 character limit of the trips API', () {
    for (final p in [buildPlan(destination: 'เชียงใหม่', days: 3), buildPlan(destination: 'ก' * 40, days: 7, styles: plannerStyles)]) {
      for (final d in p) {
        for (final i in d.items) {
          expect(i.text.runes.length, lessThanOrEqualTo(200));
        }
      }
    }
  });

  test('Chiang Mai 3 days uses the curated template', () {
    final p = buildPlan(destination: ' เชียงใหม่ ', days: 3);
    expect(p[1].title, contains('ดอยอินทนนท์'));
  });
}
