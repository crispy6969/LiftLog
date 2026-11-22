import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/formatting/values.dart';
import '../../entries/models/entry.dart';

const _columns = <String, Set<String>>{
  'locations': {'id', 'name', 'name_key'},
  'split_days': {'id', 'name', 'name_key'},
  'exercises': {'id', 'name', 'name_key', 'is_archived', 'location_id'},
  'exercise_split_days': {'exercise_id', 'split_day_id'},
  'exercise_entries': {
    'id',
    'exercise_id',
    'performed_at_ms',
    'performed_utc_offset_minutes',
    'note',
    'created_at_ms',
    'updated_at_ms',
  },
  'entry_sets': {'id', 'entry_id', 'position', 'weight_grams', 'reps_tenths'},
  'entry_drafts': {
    'exercise_id',
    'editing_entry_id',
    'payload_json',
    'updated_at_ms',
  },
  'body_weights': {
    'id',
    'day',
    'weight_grams',
    'note',
    'created_at_ms',
    'updated_at_ms',
  },
};

class BackupDocument {
  BackupDocument._(this.tables);
  final Map<String, List<Map<String, Object?>>> tables;
  int count(String table) => tables[table]!.length;

  static BackupDocument parse(String source) {
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      if (json['formatVersion'] != 1 && json['formatVersion'] != 2) {
        throw const FormatException('Unsupported backup format.');
      }
      if (json['formatVersion'] == 1) {
        json['locations'] = <Object?>[];
        json['body_weights'] = <Object?>[];
        for (final row in json['exercises'] as List<dynamic>) {
          (row as Map<String, dynamic>)['location_id'] = null;
        }
        for (final row in json['entry_sets'] as List<dynamic>) {
          final set = row as Map<String, dynamic>;
          set['reps_tenths'] =
              _integer(set.remove('reps'), min: 1, max: 2147483647) * 10;
        }
      }
      if (json['appVersion'] is! String ||
          DateTime.tryParse(json['exportedAtUtc'] as String) == null) {
        throw const FormatException('Missing backup metadata.');
      }
      final tables = <String, List<Map<String, Object?>>>{};
      for (final table in _columns.keys) {
        final rows = (json[table] as List<dynamic>)
            .map((dynamic row) => Map<String, Object?>.from(row as Map))
            .toList();
        for (final row in rows) {
          if (row.length != _columns[table]!.length ||
              !row.keys.every(_columns[table]!.contains)) {
            throw FormatException('Invalid columns in $table.');
          }
        }
        tables[table] = rows;
      }
      _validate(tables);
      return BackupDocument._(tables);
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException('This is not a valid Liftlog backup.');
    }
  }

  static int _integer(
    Object? value, {
    int min = 0,
    int max = 9223372036854775807,
  }) {
    if (value is! int || value < min || value > max) {
      throw const FormatException('Invalid integer value.');
    }
    return value;
  }

  static void _timestamp(Object? value) {
    _integer(value, max: 8640000000000000);
  }

  static void _offset(Object? value) => _integer(value, min: -840, max: 840);

  static void _validate(Map<String, List<Map<String, Object?>>> tables) {
    final ids = <String, Set<int>>{};
    for (final table in [
      'split_days',
      'locations',
      'exercises',
      'exercise_entries',
      'entry_sets',
      'body_weights',
    ]) {
      ids[table] = {};
      for (final r in tables[table]!) {
        if (!ids[table]!.add(_integer(r['id'], min: 1))) {
          throw const FormatException('Duplicate record ID.');
        }
      }
    }
    for (final table in ['split_days', 'locations', 'exercises']) {
      final names = <String>{};
      for (final r in tables[table]!) {
        final name = r['name'] as String;
        if (name.trim().isEmpty ||
            name != name.trim() ||
            nameKey(name) != r['name_key'] ||
            !names.add(
              jsonEncode([
                nameKey(name),
                if (table == 'exercises') r['location_id'],
              ]),
            )) {
          throw const FormatException('Invalid or duplicate name.');
        }
        if (table == 'exercises') _integer(r['is_archived'], max: 1);
      }
    }
    void reference(String table, Object? value) {
      if (!ids[table]!.contains(_integer(value, min: 1))) {
        throw const FormatException('A referenced record is missing.');
      }
    }

    for (final row in tables['exercises']!) {
      if (row['location_id'] != null) {
        reference('locations', row['location_id']);
      }
    }
    final days = <String>{};
    for (final row in tables['body_weights']!) {
      final day = row['day'] as String;
      if (!validDay(day) || !days.add(day)) {
        throw const FormatException('Invalid or duplicate weight date.');
      }
      _integer(row['weight_grams'], min: 1, max: 1000000000999);
      _timestamp(row['created_at_ms']);
      _timestamp(row['updated_at_ms']);
      if (row['note'] != null && row['note'] is! String) {
        throw const FormatException('Invalid weight note.');
      }
    }

    final links = <String>{};
    for (final r in tables['exercise_split_days']!) {
      reference('exercises', r['exercise_id']);
      reference('split_days', r['split_day_id']);
      if (!links.add('${r['exercise_id']}:${r['split_day_id']}')) {
        throw const FormatException('Duplicate split association.');
      }
    }
    final owners = <int, int>{};
    for (final r in tables['exercise_entries']!) {
      reference('exercises', r['exercise_id']);
      owners[r['id'] as int] = r['exercise_id'] as int;
      _timestamp(r['performed_at_ms']);
      _timestamp(r['created_at_ms']);
      _timestamp(r['updated_at_ms']);
      _offset(r['performed_utc_offset_minutes']);
      if (r['note'] != null && r['note'] is! String) {
        throw const FormatException('Invalid note.');
      }
    }
    final positions = <int, Set<int>>{};
    for (final r in tables['entry_sets']!) {
      reference('exercise_entries', r['entry_id']);
      final entryId = r['entry_id'] as int;
      final position = _integer(r['position'], min: 1);
      if (!(positions[entryId] ??= {}).add(position)) {
        throw const FormatException('Duplicate set position.');
      }
      _integer(r['weight_grams'], max: 1000000000999);
      _integer(r['reps_tenths'], min: 1, max: 21474836479);
    }
    for (final id in ids['exercise_entries']!) {
      final ordered = positions[id]?.toList();
      ordered?.sort();
      if (ordered == null || ordered.isEmpty) {
        throw const FormatException('An entry has no sets.');
      }
      for (var i = 0; i < ordered.length; i++) {
        if (ordered[i] != i + 1) {
          throw const FormatException('Set positions must be consecutive.');
        }
      }
    }
    final draftOwners = <int>{};
    for (final r in tables['entry_drafts']!) {
      reference('exercises', r['exercise_id']);
      if (!draftOwners.add(r['exercise_id'] as int)) {
        throw const FormatException('Duplicate exercise draft.');
      }
      if (r['editing_entry_id'] != null) {
        reference('exercise_entries', r['editing_entry_id']);
        if (owners[r['editing_entry_id']] != r['exercise_id']) {
          throw const FormatException('Draft belongs to another exercise.');
        }
      }
      _timestamp(r['updated_at_ms']);
      final draft = EntryDraft.decode(
        r['payload_json'] as String,
        editingEntryId: r['editing_entry_id'] as int?,
      );
      _timestamp(draft.performedAtMs);
      _offset(draft.offsetMinutes);
      // A draft is intentionally allowed to contain incomplete or invalid input.
    }
  }
}

class BackupService {
  BackupService(this.db);
  final Database db;

  Future<String> export() => db.transaction((tx) async {
    final document = <String, Object?>{
      'formatVersion': 2,
      'appVersion': '1.1.0',
      'exportedAtUtc': DateTime.now().toUtc().toIso8601String(),
    };
    for (final table in _columns.keys) {
      document[table] = await tx.query(table);
    }
    return const JsonEncoder.withIndent('  ').convert(document);
  });

  /// Revalidates to prevent mutated previews from bypassing validation.
  Future<void> restore(String source) async {
    final document = BackupDocument.parse(source);
    await db.transaction((tx) async {
      for (final table in _columns.keys.toList().reversed) {
        await tx.delete(table);
      }
      for (final table in _columns.keys) {
        for (final row in document.tables[table]!) {
          await tx.insert(table, row);
        }
      }
    });
  }
}
