import 'package:flutter_test/flutter_test.dart';
import 'package:sabai_app/src/core/util/dates.dart';

void main() {
  test('formatDate and formatRange', () {
    expect(formatDate('2030-01-10'), '10 ม.ค. 2030');
    expect(formatDate('2030-12-05T00:00:00Z'), '5 ธ.ค. 2030');
    expect(formatDate('not a date'), 'not a date');
    expect(formatDate('2030-13-01'), '2030-13-01');
    expect(formatRange('2030-01-10', '2030-01-12'), '10 ม.ค. 2030 – 12 ม.ค. 2030');
    expect(formatRange('2030-01-10', '2030-01-10'), '10 ม.ค. 2030');
    expect(formatRange('2030-01-10', ''), '10 ม.ค. 2030');
    expect(formatRange('', ''), '');
  });

  test('toIsoDate and parseIsoDate round-trip without time zone shifts', () {
    expect(toIsoDate(DateTime(2030, 1, 5)), '2030-01-05');
    expect(parseIsoDate('2030-01-05'), DateTime(2030, 1, 5));
    expect(parseIsoDate('2030-1-5'), isNull);
  });
}
