import 'package:sqflite/sqflite.dart';

import '../../../core/formatting/values.dart';
import '../../entries/models/entry.dart';
import '../models/exercise.dart';

class TrackerRepository {
  TrackerRepository(this.db);
  final Database db;

  Future<List<Exercise>> exercises({
    String search = '',
    int? splitId,
    int? locationId,
    bool archived = false,
  }) async {
    final where = <String>['x.is_archived = ?'];
    final args = <Object?>[archived ? 1 : 0];
    if (locationId != null) {
      where.add('(x.location_id = ? OR x.location_id IS NULL)');
      args.add(locationId);
    }
    if (splitId == -1) {
      where.add(
        'NOT EXISTS (SELECT 1 FROM exercise_split_days l WHERE l.exercise_id = x.id)',
      );
    } else if (splitId != null) {
      where.add(
        'EXISTS (SELECT 1 FROM exercise_split_days l WHERE l.exercise_id = x.id AND l.split_day_id = ?)',
      );
      args.add(splitId);
    }
    // instr treats %, _ and other user input literally, unlike LIKE.
    where.add('instr(x.name_key, ?) > 0');
    args.add(nameKey(search));
    final rows = await db.rawQuery('''
      SELECT x.*, l.name AS location_name, e.performed_at_ms, e.performed_utc_offset_minutes
      FROM exercises x LEFT JOIN locations l ON l.id = x.location_id
      LEFT JOIN exercise_entries e ON e.id = (
        SELECT id FROM exercise_entries WHERE exercise_id = x.id
        ORDER BY performed_at_ms DESC, id DESC LIMIT 1
      ) WHERE ${where.join(' AND ')} ORDER BY x.name_key, x.id
    ''', args);
    return rows
        .map(
          (r) => Exercise(
            id: r['id'] as int,
            name: r['name'] as String,
            archived: r['is_archived'] == 1,
            locationId: r['location_id'] as int?,
            locationName: r['location_name'] as String?,
            lastAtMs: r['performed_at_ms'] as int?,
            lastOffset: r['performed_utc_offset_minutes'] as int?,
          ),
        )
        .toList();
  }

  Future<List<SplitDay>> splits() async =>
      (await db.query('split_days', orderBy: 'name_key, id'))
          .map((r) => SplitDay(id: r['id'] as int, name: r['name'] as String))
          .toList();

  Future<Set<int>> memberships(int exerciseId) async => (await db.query(
    'exercise_split_days',
    where: 'exercise_id = ?',
    whereArgs: [exerciseId],
  )).map((r) => r['split_day_id'] as int).toSet();

  Future<int> saveExercise(
    String name,
    Set<int> splitIds, {
    int? id,
    int? locationId,
  }) async {
    _requireName(name);
    return db.transaction((tx) async {
      final row = <String, Object?>{
        'name': name.trim(),
        'name_key': nameKey(name),
        'location_id': locationId,
      };
      final exerciseId = id ?? await tx.insert('exercises', row);
      if (id != null) {
        await tx.update('exercises', row, where: 'id = ?', whereArgs: [id]);
      }
      await tx.delete(
        'exercise_split_days',
        where: 'exercise_id = ?',
        whereArgs: [exerciseId],
      );
      for (final splitId in splitIds) {
        await tx.insert('exercise_split_days', {
          'exercise_id': exerciseId,
          'split_day_id': splitId,
        });
      }
      return exerciseId;
    });
  }

  Future<void> saveSplit(String name, {int? id}) async {
    _requireName(name);
    final row = {'name': name.trim(), 'name_key': nameKey(name)};
    if (id == null) {
      await db.insert('split_days', row);
    } else {
      await db.update('split_days', row, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> deleteSplit(int id) async {
    await db.delete('split_days', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> archive(int id, bool archived) async {
    await db.update(
      'exercises',
      {'is_archived': archived ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> hasHistory(int id) async =>
      Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM exercise_entries WHERE exercise_id = ?',
          [id],
        ),
      )! >
      0;

  Future<void> deleteEmptyExercise(int id) async {
    // The database foreign key prevents accidental history deletion.
    await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ExerciseEntry>> history(
    int exerciseId, {
    int offset = 0,
    int limit = 30,
  }) async {
    return db.transaction((tx) async {
      final rows = await tx.query(
        'exercise_entries',
        where: 'exercise_id = ?',
        whereArgs: [exerciseId],
        orderBy: 'performed_at_ms DESC, id DESC',
        limit: limit,
        offset: offset,
      );
      final entries = <ExerciseEntry>[];
      for (final r in rows) {
        final sets = await tx.query(
          'entry_sets',
          where: 'entry_id = ?',
          whereArgs: [r['id']],
          orderBy: 'position',
        );
        entries.add(
          ExerciseEntry(
            id: r['id'] as int,
            exerciseId: exerciseId,
            performedAtMs: r['performed_at_ms'] as int,
            offsetMinutes: r['performed_utc_offset_minutes'] as int,
            note: r['note'] as String?,
            sets: sets
                .map(
                  (s) => LoggedSet(
                    grams: s['weight_grams'] as int,
                    repsTenths: s['reps_tenths'] as int,
                  ),
                )
                .toList(),
          ),
        );
      }
      return entries;
    });
  }

  Future<EntryDraft?> draft(int exerciseId) async {
    final rows = await db.query(
      'entry_drafts',
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
    );
    if (rows.isEmpty) return null;
    return EntryDraft.decode(
      rows.single['payload_json'] as String,
      editingEntryId: rows.single['editing_entry_id'] as int?,
    );
  }

  Future<void> saveDraft(int exerciseId, EntryDraft draft) async {
    await db.transaction((tx) async {
      await _checkDraftOwner(tx, exerciseId, draft.editingEntryId);
      await tx.insert('entry_drafts', {
        'exercise_id': exerciseId,
        'editing_entry_id': draft.editingEntryId,
        'payload_json': draft.encode(),
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> discardDraft(int exerciseId) async {
    await db.delete(
      'entry_drafts',
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
    );
  }

  Future<int> saveEntry(int exerciseId, EntryDraft draft) async {
    final sets = draft.validate();
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction((tx) async {
      final exercise = await tx.query(
        'exercises',
        where: 'id = ?',
        whereArgs: [exerciseId],
      );
      if (exercise.isEmpty || exercise.single['is_archived'] == 1) {
        throw StateError('Restore this exercise before logging.');
      }
      await _checkDraftOwner(tx, exerciseId, draft.editingEntryId);
      final row = <String, Object?>{
        'exercise_id': exerciseId,
        'performed_at_ms': draft.performedAtMs,
        'performed_utc_offset_minutes': draft.offsetMinutes,
        'note': draft.note.trim().isEmpty ? null : draft.note.trim(),
        'updated_at_ms': now,
      };
      final int entryId;
      if (draft.editingEntryId == null) {
        row['created_at_ms'] = now;
        entryId = await tx.insert('exercise_entries', row);
      } else {
        entryId = draft.editingEntryId!;
        await tx.update(
          'exercise_entries',
          row,
          where: 'id = ?',
          whereArgs: [entryId],
        );
        await tx.delete(
          'entry_sets',
          where: 'entry_id = ?',
          whereArgs: [entryId],
        );
      }
      for (var i = 0; i < sets.length; i++) {
        await tx.insert('entry_sets', {
          'entry_id': entryId,
          'position': i + 1,
          'weight_grams': sets[i].grams,
          'reps_tenths': sets[i].repsTenths,
        });
      }
      await tx.delete(
        'entry_drafts',
        where: 'exercise_id = ?',
        whereArgs: [exerciseId],
      );
      return entryId;
    });
  }

  Future<void> deleteEntry(int entryId) async {
    await db.delete('exercise_entries', where: 'id = ?', whereArgs: [entryId]);
  }

  Future<void> _checkDraftOwner(
    DatabaseExecutor tx,
    int exerciseId,
    int? entryId,
  ) async {
    if (entryId == null) return;
    final entries = await tx.query(
      'exercise_entries',
      where: 'id = ? AND exercise_id = ?',
      whereArgs: [entryId, exerciseId],
    );
    if (entries.isEmpty) {
      throw StateError('This entry no longer belongs to this exercise.');
    }
  }

  void _requireName(String name) {
    if (name.trim().isEmpty) throw const FormatException('Enter a name.');
  }

  Future<List<Location>> locations() async =>
      (await db.query('locations', orderBy: 'name_key, id'))
          .map((r) => Location(id: r['id'] as int, name: r['name'] as String))
          .toList();

  Future<void> saveLocation(String name, {int? id}) async {
    _requireName(name);
    final values = {'name': name.trim(), 'name_key': nameKey(name)};
    if (id == null) {
      await db.insert('locations', values);
    } else {
      await db.update('locations', values, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> deleteLocation(int id) async {
    if (Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM exercises WHERE location_id = ?',
            [id],
          ),
        )! >
        0) {
      throw StateError(
        'Move exercises at this location (including archived ones) to another location or Any location before deleting it.',
      );
    }
    await db.delete('locations', where: 'id = ?', whereArgs: [id]);
  }
}
