const _months = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];

/// `2030-01-10` -> `10 ม.ค. 2030`; anything that is not an ISO date is returned unchanged.
String formatDate(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  if (m == null) return iso;
  final month = int.parse(m.group(2)!);
  if (month < 1 || month > 12) return iso;
  return '${int.parse(m.group(3)!)} ${_months[month - 1]} ${m.group(1)}';
}

/// `2030-01-10`, `2030-01-12` -> `10 ม.ค. 2030 – 12 ม.ค. 2030`; one empty bound shows the other; both empty -> ''.
String formatRange(String start, String end) {
  if (start.isEmpty && end.isEmpty) return '';
  if (end.isEmpty || start == end) return formatDate(start.isEmpty ? end : start);
  if (start.isEmpty) return formatDate(end);
  return '${formatDate(start)} – ${formatDate(end)}';
}

/// DateTime -> `YYYY-MM-DD` (local calendar date, no time zone shifts).
String toIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseIsoDate(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (m == null) return null;
  return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
}
