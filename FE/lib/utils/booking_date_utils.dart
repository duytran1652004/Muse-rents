DateTime? parseBookingDate(dynamic value) {
  if (value == null) return null;

  final raw = value.toString().trim();
  if (raw.isEmpty) return null;

  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
  if (match != null) {
    final year = int.tryParse(match.group(1) ?? '');
    final month = int.tryParse(match.group(2) ?? '');
    final day = int.tryParse(match.group(3) ?? '');
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }

  try {
    return DateTime.parse(raw);
  } catch (_) {
    return null;
  }
}

String formatBookingDate(dynamic value) {
  final parsed = parseBookingDate(value);
  if (parsed == null) return '';
  return '${parsed.day}/${parsed.month}/${parsed.year}';
}

String formatBookingDateShort(dynamic value) {
  final parsed = parseBookingDate(value);
  if (parsed == null) return '';
  return '${parsed.day}/${parsed.month}';
}

String formatTimeStr(String? t) {
  if (t == null || t.trim().isEmpty) return '';
  final parts = t.trim().split(':');
  if (parts.length >= 2) {
    int? hour = int.tryParse(parts[0]);
    if (hour != null) {
      return '$hour:${parts[1]}';
    }
  }
  return t.trim();
}
