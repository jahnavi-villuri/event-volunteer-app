// ============================================================
// FORMAT HELPERS
// Converts MySQL date/time strings into readable text.
// ============================================================

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatDate(String? raw) {
  if (raw == null || raw.isEmpty) return '';

  final s = raw.split(' ').first;
  final parts = s.split('-');

  if (parts.length != 3) return raw;

  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);

  if (year == null || month == null || day == null || month < 1 || month > 12) {
    return raw;
  }

  return '${_months[month - 1]} $day, $year';
}

String formatTime(String? raw) {
  if (raw == null || raw.isEmpty) return '';

  final parts = raw.split(':');

  if (parts.length < 2) return raw;

  final hour = int.tryParse(parts[0]);
  if (hour == null) return raw;

  final minute = parts[1].padLeft(2, '0');
  final period = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;

  return '$hour12:$minute $period';
}

String formatDateTime(String? raw) {
  if (raw == null || raw.isEmpty) return '';

  final parts = raw.split(' ');
  final date = parts.isNotEmpty ? formatDate(parts[0]) : '';

  if (parts.length > 1) {
    final time = formatTime(parts[1]);
    return '$date $time';
  }

  return date;
}
