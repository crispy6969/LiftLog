import 'package:flutter_test/flutter_test.dart';
import 'package:liftlog/core/formatting/values.dart';
import 'package:liftlog/features/entries/models/entry.dart';

void main() {
  test('weights parse exactly and accept decimal comma', () {
    expect(parseGrams('80'), 80000);
    expect(parseGrams('1,25'), 1250);
    expect(parseGrams('0.001'), 1);
    expect(parseGrams(' 0 '), 0);
    for (final invalid in [
      '',
      '-1',
      '1.1234',
      '1,000.5',
      'NaN',
      'Infinity',
      '1e3',
    ]) {
      expect(parseGrams(invalid), isNull);
    }
    expect(kilograms(80100), '80.1');
    expect(kilograms(1), '0.001');
  });
  test('repetitions must be positive whole numbers', () {
    expect(parseReps('10'), 10);
    expect(parseReps('7.5'), 7.5);
    expect(parseReps('7,5'), 7.5);
    expect(parseRepTenths('0.1'), 1);
    expect(repetitions(75), '7.5');
    expect(repetitions(70), '7');
    for (final value in ['0', '-1', '1.55', '', '999999999999999999999']) {
      expect(parseReps(value), isNull);
    }
  });
  test('calendar days handle midnight and DST rather than elapsed hours', () {
    expect(
      calendarDays(
        DateTime(2026, 11, 14, 0, 1),
        DateTime(2026, 11, 13, 23, 59),
      ),
      1,
    );
    expect(calendarDays(DateTime(2026, 3, 30), DateTime(2026, 3, 29)), 1);
    final instant = DateTime.utc(2026, 11, 13, 23).millisecondsSinceEpoch;
    expect(recordedTime(instant, 120).day, 14);
    expect(
      daysAgo(DateTime(2026, 11, 14), recordedTime(instant, 120)),
      'Today',
    );
  });
  test('partial drafts round-trip but cannot be saved as history', () {
    final draft = EntryDraft.empty()..note = 'Shoulder recovering';
    draft.sets.first.weight = '80,';
    final restored = EntryDraft.decode(draft.encode());
    expect(restored.sets.first.weight, '80,');
    expect(restored.note, 'Shoulder recovering');
    expect(restored.validate, throwsFormatException);
    draft.sets.clear();
    expect(draft.validate, throwsFormatException);
  });
  test('future entries are rejected', () {
    final draft = EntryDraft.empty()
      ..performedAtMs = DateTime.now()
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch;
    expect(draft.validate, throwsFormatException);
  });
}
