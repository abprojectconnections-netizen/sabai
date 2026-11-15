/// Display-only money formatting. The client never computes, rounds or decides a price, refund or balance:
/// every figure comes from the server (amounts arrive as decimal strings).
String formatBaht(num amount) {
  final negative = amount < 0;
  final fixed = amount.abs().toStringAsFixed(
      amount.abs() == amount.abs().roundToDouble() ? 0 : 2);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  final frac = parts.length > 1 ? '.${parts[1]}' : '';
  return '${negative ? '-' : ''}฿$buf$frac';
}

/// Parses a server decimal string; anything unparsable becomes 0 (display only).
num parseAmount(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value) ?? 0;
  return 0;
}
