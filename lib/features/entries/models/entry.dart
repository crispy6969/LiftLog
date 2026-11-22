import 'dart:convert';

import '../../../core/formatting/values.dart';

class LoggedSet {
  const LoggedSet({required this.grams, required this.repsTenths});
  final int grams;
  final int repsTenths;
  num get reps => repsTenths / 10;
}

class ExerciseEntry {
  const ExerciseEntry({
    required this.id,
    required this.exerciseId,
    required this.performedAtMs,
    required this.offsetMinutes,
    required this.sets,
    this.note,
  });
  final int id;
  final int exerciseId;
  final int performedAtMs;
  final int offsetMinutes;
  final String? note;
  final List<LoggedSet> sets;
  DateTime get localTime => recordedTime(performedAtMs, offsetMinutes);
}

class SetInput {
  SetInput({this.weight = '', this.reps = ''});
  String weight;
  String reps;
  Map<String, Object?> toJson() => {'weight': weight, 'reps': reps};
}

class EntryDraft {
  EntryDraft({
    required this.performedAtMs,
    required this.offsetMinutes,
    required this.sets,
    this.note = '',
    this.editingEntryId,
  });
  factory EntryDraft.empty({int setCount = 1}) {
    final now = DateTime.now();
    return EntryDraft(
      performedAtMs: now.millisecondsSinceEpoch,
      offsetMinutes: now.timeZoneOffset.inMinutes,
      sets: List.generate(setCount, (_) => SetInput()),
    );
  }
  factory EntryDraft.fromEntry(ExerciseEntry entry) => EntryDraft(
    performedAtMs: entry.performedAtMs,
    offsetMinutes: entry.offsetMinutes,
    editingEntryId: entry.id,
    note: entry.note ?? '',
    sets: entry.sets
        .map(
          (s) => SetInput(
            weight: kilograms(s.grams),
            reps: repetitions(s.repsTenths),
          ),
        )
        .toList(),
  );
  factory EntryDraft.decode(String payload, {int? editingEntryId}) {
    final json = jsonDecode(payload) as Map<String, dynamic>;
    return EntryDraft(
      performedAtMs: json['performedAtMs'] as int,
      offsetMinutes: json['offsetMinutes'] as int,
      note: json['note'] as String,
      editingEntryId: editingEntryId,
      sets: (json['sets'] as List<dynamic>).map((dynamic s) {
        final row = s as Map<String, dynamic>;
        return SetInput(
          weight: row['weight'] as String,
          reps: row['reps'] as String,
        );
      }).toList(),
    );
  }
  int performedAtMs;
  int offsetMinutes;
  int? editingEntryId;
  String note;
  final List<SetInput> sets;
  DateTime get localTime => recordedTime(performedAtMs, offsetMinutes);
  String encode() => jsonEncode({
    'performedAtMs': performedAtMs,
    'offsetMinutes': offsetMinutes,
    'note': note,
    'sets': sets.map((s) => s.toJson()).toList(),
  });
  List<LoggedSet> validate({DateTime? now}) {
    if (performedAtMs > (now ?? DateTime.now()).millisecondsSinceEpoch) {
      throw const FormatException(
        'Choose a date and time that is not in the future.',
      );
    }
    if (sets.isEmpty) throw const FormatException('Add at least one set.');
    return sets.map((s) {
      final grams = parseGrams(s.weight);
      final reps = parseRepTenths(s.reps);
      if (grams == null || reps == null) {
        throw const FormatException(
          'Complete every set with a valid weight and positive repetitions.',
        );
      }
      return LoggedSet(grams: grams, repsTenths: reps);
    }).toList();
  }
}
