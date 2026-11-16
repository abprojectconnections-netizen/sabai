import 'package:flutter_test/flutter_test.dart';
import 'package:sabai_app/src/core/util/format.dart';

void main() {
  test('formatBaht groups thousands and keeps satang when present', () {
    expect(formatBaht(0), '฿0');
    expect(formatBaht(1490), '฿1,490');
    expect(formatBaht(1234567), '฿1,234,567');
    expect(formatBaht(1490.5), '฿1,490.50');
    expect(formatBaht(-50), '-฿50');
  });

  test('parseAmount is display-only and never throws', () {
    expect(parseAmount('1490.00'), 1490);
    expect(parseAmount('bad'), 0);
    expect(parseAmount(null), 0);
    expect(parseAmount(12), 12);
  });
}
