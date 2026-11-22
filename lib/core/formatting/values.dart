import 'package:intl/intl.dart';

String nameKey(String value) => value.trim().toLowerCase();

/// Parses decimal text without floating-point arithmetic. Comma is accepted
/// as a decimal separator, never as a thousands separator.
int? parseGrams(String text) {
  final value = text.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d+(?:\.\d{1,3})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final whole = int.tryParse(parts[0]);
  if (whole == null || whole > 1000000000) return null;
  final fraction = parts.length == 1 ? 0 : int.parse(parts[1].padRight(3, '0'));
  return whole * 1000 + fraction;
}

int? parseRepTenths(String text) {
  final value = text.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d+(?:\.\d)?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final whole = int.tryParse(parts[0]);
  if (whole == null || whole > 2147483647) return null;
  final tenths = whole * 10 + (parts.length == 2 ? int.parse(parts[1]) : 0);
  return tenths > 0 ? tenths : null;
}

num? parseReps(String text) {
  final value = parseRepTenths(text);
  return value == null ? null : value / 10;
}

String repetitions(int tenths) =>
    tenths % 10 == 0 ? '${tenths ~/ 10}' : '${tenths ~/ 10}.${tenths % 10}';

String dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

bool validDay(String value) {
  final date = DateTime.tryParse(value);
  return date != null &&
      date.year >= 2000 &&
      date.year <= 9999 &&
      dayKey(date) == value;
}

String kilograms(int grams) {
  final whole = grams ~/ 1000;
  final fraction = (grams % 1000)
      .toString()
      .padLeft(3, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? '$whole' : '$whole.$fraction';
}

DateTime recordedTime(int milliseconds, int offsetMinutes) =>
    DateTime.fromMillisecondsSinceEpoch(
      milliseconds,
      isUtc: true,
    ).add(Duration(minutes: offsetMinutes));

int calendarDays(DateTime newer, DateTime older) => DateTime.utc(
  newer.year,
  newer.month,
  newer.day,
).difference(DateTime.utc(older.year, older.month, older.day)).inDays;

String daysAgo(DateTime now, DateTime previous) {
  final days = calendarDays(now, previous);
  if (days <= 0) return 'Today';
  if (days == 1) return '1 day ago';
  return '$days days ago';
}

String dateLabel(DateTime date) => DateFormat.yMMMd().add_jm().format(date);
