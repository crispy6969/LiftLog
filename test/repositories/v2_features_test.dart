import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftlog/core/database/app_database.dart';
import 'package:liftlog/features/backup/data/backup_service.dart';
import 'package:liftlog/features/entries/models/entry.dart';
import 'package:liftlog/features/entries/presentation/entry_controller.dart';
import 'package:liftlog/features/exercises/data/tracker_repository.dart';
import 'package:liftlog/features/weight/data/weight_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../support/database.dart';

void main() {
  late Database db;
  late TrackerRepository repository;
  setUp(() async {
    db = await testDatabase();
    repository = TrackerRepository(db);
  });
  tearDown(() => db.close());

  test(
    'locations combine with search and splits; universal exercises always match',
    () async {
      await repository.saveLocation('Gym A');
      await repository.saveLocation('Gym B');
      final locations = await repository.locations();
      final a = locations[0].id, b = locations[1].id;
      await repository.saveSplit('Pull');
      final split = (await repository.splits()).single.id;
      final universal = await repository.saveExercise('Curl', {split});
      final atA = await repository.saveExercise('Lat pulldown', {
        split,
      }, locationId: a);
      final atB = await repository.saveExercise('Lat pulldown', {
        split,
      }, locationId: b);
      expect((await repository.exercises(locationId: a)).map((e) => e.id), [
        universal,
        atA,
      ]);
      expect(
        (await repository.exercises(
          locationId: b,
          search: 'lat',
          splitId: split,
        )).single.id,
        atB,
      );
      expect(await repository.exercises(), hasLength(3));
      await expectLater(
        repository.saveExercise('LAT PULLDOWN', {}, locationId: a),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(repository.deleteLocation(a), throwsStateError);
      await repository.saveExercise('Lat pulldown', {split}, id: atA);
      await repository.deleteLocation(a);
      expect((await repository.exercises(locationId: b)).map((e) => e.id), [
        universal,
        atA,
        atB,
      ]);
    },
  );

  test(
    'fractional reps persist exactly and fresh drafts seed blank matching sets',
    () async {
      final id = await repository.saveExercise('Bench', {});
      final draft = EntryDraft.empty();
      draft.sets.first
        ..weight = '80'
        ..reps = '7.5';
      draft.sets.addAll([
        SetInput(weight: '75', reps: '7,1'),
        SetInput(weight: '70', reps: '6'),
      ]);
      await repository.saveEntry(id, draft);
      expect((await db.query('entry_sets')).map((r) => r['reps_tenths']), [
        75,
        71,
        60,
      ]);
      final controller = EntryController(repository, id);
      await controller.load();
      expect(controller.draft.sets, hasLength(3));
      expect(
        controller.draft.sets.every((s) => s.weight.isEmpty && s.reps.isEmpty),
        isTrue,
      );
      expect(controller.comparison!.sets.first.reps, 7.5);
      controller.draft.sets.removeLast();
      controller.changed();
      await controller.flush();
      controller.dispose();
      final resumed = EntryController(repository, id);
      await resumed.load();
      expect(resumed.draft.sets, hasLength(2));
      await resumed.discard();
      expect(resumed.draft.sets, hasLength(3));
      resumed.dispose();
    },
  );

  test(
    'daily body weights are unique, editable, sorted and included in backups',
    () async {
      final weights = WeightRepository(db);
      await weights.save(
        day: '2020-01-01',
        weight: '80.25',
        note: 'Started bulking',
      );
      await expectLater(
        weights.save(day: '2020-01-01', weight: '81', note: ''),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        weights.save(day: '2020-02-30', weight: '81', note: ''),
        throwsFormatException,
      );
      await expectLater(
        weights.save(day: '2020-01-02', weight: '0', note: ''),
        throwsFormatException,
      );
      final saved = (await weights.entries()).single;
      await weights.save(
        id: saved.id,
        day: saved.day,
        weight: '80.5',
        note: 'Updated',
      );
      await weights.save(day: '2020-02-01', weight: '82', note: '');
      expect((await weights.entries()).first.grams, 82000);
      final backup = BackupService(db);
      final source = await backup.export();
      expect(BackupDocument.parse(source).count('body_weights'), 2);
      await weights.delete(saved.id);
      await backup.restore(source);
      expect((await weights.entries()).last.note, 'Updated');
    },
  );

  test(
    'v1 backup imports whole reps and exercises without locations',
    () async {
      final id = await repository.saveExercise('Bench', {});
      final draft = EntryDraft.empty();
      draft.sets.first
        ..weight = '80'
        ..reps = '7';
      await repository.saveEntry(id, draft);
      final service = BackupService(db);
      final json = jsonDecode(await service.export()) as Map<String, dynamic>;
      json['formatVersion'] = 1;
      json.remove('locations');
      json.remove('body_weights');
      for (final dynamic row in json['exercises'] as List<dynamic>) {
        (row as Map<String, dynamic>).remove('location_id');
      }
      for (final dynamic row in json['entry_sets'] as List<dynamic>) {
        final set = row as Map<String, dynamic>;
        set['reps'] = (set.remove('reps_tenths') as int) ~/ 10;
      }
      await service.restore(jsonEncode(json));
      expect((await repository.history(id)).single.sets.single.repsTenths, 70);
      expect((await repository.exercises()).single.locationId, isNull);
    },
  );

  test(
    'v1 on-disk migration preserves IDs, memberships, notes, drafts and FK protection',
    () async {
      final folder = await Directory(
        'build/test_databases',
      ).create(recursive: true);
      final path =
          '${folder.absolute.path}/migration-${DateTime.now().microsecondsSinceEpoch}.db';
      final old = await databaseFactoryFfiNoIsolate.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            for (final statement in File(
              'test/fixtures/schema_v1.sql',
            ).readAsStringSync().split(';')) {
              if (statement.trim().isNotEmpty) await db.execute(statement);
            }
          },
        ),
      );
      await old.insert('exercises', {
        'id': 41,
        'name': 'Bench',
        'name_key': 'bench',
      });
      await old.insert('split_days', {
        'id': 9,
        'name': 'Push',
        'name_key': 'push',
      });
      await old.insert('exercise_split_days', {
        'exercise_id': 41,
        'split_day_id': 9,
      });
      await old.insert('exercise_entries', {
        'id': 52,
        'exercise_id': 41,
        'performed_at_ms': 1600000000000,
        'performed_utc_offset_minutes': 120,
        'note': 'Original note',
        'created_at_ms': 1600000000000,
        'updated_at_ms': 1600000000000,
      });
      await old.insert('entry_sets', {
        'id': 61,
        'entry_id': 52,
        'position': 1,
        'weight_grams': 80000,
        'reps': 7,
      });
      await old.insert('entry_drafts', {
        'exercise_id': 41,
        'editing_entry_id': 52,
        'payload_json': EntryDraft.empty().encode(),
        'updated_at_ms': 1600000000000,
      });
      await old.close();
      final migrated = await AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      try {
        expect(await migrated.getVersion(), 2);
        final repo = TrackerRepository(migrated);
        expect((await repo.history(41)).single.sets.single.repsTenths, 70);
        expect((await repo.history(41)).single.note, 'Original note');
        expect((await repo.draft(41))!.editingEntryId, 52);
        expect(await repo.memberships(41), {9});
        expect(await migrated.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        await expectLater(
          repo.deleteEmptyExercise(41),
          throwsA(isA<DatabaseException>()),
        );
      } finally {
        await migrated.close();
        await databaseFactoryFfiNoIsolate.deleteDatabase(path);
      }
    },
  );
}
