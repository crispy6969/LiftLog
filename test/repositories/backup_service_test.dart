import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftlog/features/backup/data/backup_service.dart';
import 'package:liftlog/features/entries/models/entry.dart';
import 'package:liftlog/features/exercises/data/tracker_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../support/database.dart';

void main() {
  late Database db;
  late TrackerRepository repository;
  late BackupService service;
  setUp(() async {
    db = await testDatabase();
    repository = TrackerRepository(db);
    service = BackupService(db);
    await repository.saveSplit('Push');
    final split = (await repository.splits()).single;
    final id = await repository.saveExercise('Bench', {split.id});
    final draft = EntryDraft.empty()..note = 'Recovery note';
    draft.sets.first
      ..weight = '80'
      ..reps = '10';
    await repository.saveEntry(id, draft);
    await repository.saveDraft(id, EntryDraft.empty());
  });
  tearDown(() => db.close());

  test(
    'all tables including drafts round-trip; restore replaces instead of merging',
    () async {
      final source = await service.export();
      final preview = BackupDocument.parse(source);
      expect(preview.count('exercise_entries'), 1);
      await repository.saveExercise('Remove on restore', {});
      await service.restore(source);
      final restored =
          jsonDecode(await service.export()) as Map<String, dynamic>;
      final original = jsonDecode(source) as Map<String, dynamic>;
      restored.remove('exportedAtUtc');
      original.remove('exportedAtUtc');
      expect(restored, original);
    },
  );
  test('invalid backups preserve every current table', () async {
    final source = await service.export();
    final cases = <void Function(Map<String, dynamic>)>[
      (json) => json['formatVersion'] = 999,
      (json) => (json['entry_sets'] as List<dynamic>).clear(),
      (json) =>
          ((json['entry_sets'] as List<dynamic>).first
                  as Map<String, dynamic>)['entry_id'] =
              999,
      (json) =>
          ((json['entry_sets'] as List<dynamic>).first
                  as Map<String, dynamic>)['weight_grams'] =
              -1,
      (json) =>
          ((json['exercises'] as List<dynamic>).first
                  as Map<String, dynamic>)['name_key'] =
              'mismatch',
      (json) =>
          ((json['entry_sets'] as List<dynamic>).first
                  as Map<String, dynamic>)['position'] =
              2,
    ];
    for (final corrupt in cases) {
      final json = jsonDecode(source) as Map<String, dynamic>;
      corrupt(json);
      await expectLater(
        service.restore(jsonEncode(json)),
        throwsFormatException,
      );
      expect((await repository.exercises()).single.name, 'Bench');
      expect(await db.query('entry_sets'), hasLength(1));
      expect(await db.query('entry_drafts'), hasLength(1));
    }
    await expectLater(service.restore('not json'), throwsFormatException);
  });
  test('failed insertion rolls back a restore after deletion', () async {
    final source = await service.export();
    await db.execute(
      "CREATE TRIGGER reject_restore BEFORE INSERT ON exercises BEGIN SELECT RAISE(ABORT, 'simulated failure'); END",
    );
    await expectLater(
      service.restore(source),
      throwsA(isA<DatabaseException>()),
    );
    expect((await repository.exercises()).single.name, 'Bench');
    expect(await db.query('entry_sets'), hasLength(1));
    expect(await db.query('entry_drafts'), hasLength(1));
  });
}
