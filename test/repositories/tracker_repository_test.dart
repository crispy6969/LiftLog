import 'package:flutter_test/flutter_test.dart';
import 'package:liftlog/features/entries/models/entry.dart';
import 'package:liftlog/features/entries/presentation/entry_controller.dart';
import 'package:liftlog/features/exercises/data/tracker_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../support/database.dart';

EntryDraft performance({String weight = '80', String reps = '10'}) {
  final draft = EntryDraft.empty();
  draft.sets.first
    ..weight = weight
    ..reps = reps;
  return draft;
}

class _FailOnceRepository extends TrackerRepository {
  _FailOnceRepository(super.db);
  bool first = true;
  @override
  Future<void> saveDraft(int exerciseId, EntryDraft draft) async {
    if (first) {
      first = false;
      throw StateError('Simulated storage error');
    }
    await super.saveDraft(exerciseId, draft);
  }
}

void main() {
  late Database db;
  late TrackerRepository repository;
  setUp(() async {
    db = await testDatabase();
    repository = TrackerRepository(db);
  });
  tearDown(() => db.close());

  test('a successful queued write clears an earlier draft failure', () async {
    final repository = _FailOnceRepository(db);
    final id = await repository.saveExercise('Bench', {});
    final controller = EntryController(repository, id);
    await controller.load();
    controller.draft.note = 'First';
    controller.changed();
    controller.draft.note = 'Latest';
    controller.changed();
    expect(await controller.flush(), isTrue);
    expect((await repository.draft(id))!.note, 'Latest');
    controller.dispose();
  });

  test(
    'installation starts empty and rejects normalized duplicate names',
    () async {
      expect(await repository.exercises(), isEmpty);
      expect(await repository.splits(), isEmpty);
      await repository.saveExercise(' Bench Press ', {});
      await expectLater(
        repository.saveExercise('BENCH PRESS', {}),
        throwsA(isA<DatabaseException>()),
      );
      expect((await repository.exercises()).single.name, 'Bench Press');
    },
  );
  test(
    'many-to-many filters combine with literal search and split deletion preserves history',
    () async {
      await repository.saveSplit('Push');
      await repository.saveSplit('Upper');
      final splits = await repository.splits();
      final push = splits.first.id;
      final upper = splits.last.id;
      final bench = await repository.saveExercise('Bench Press', {push, upper});
      await repository.saveExercise('Squat', {});
      await repository.saveEntry(bench, performance());
      expect(await repository.memberships(bench), {push, upper});
      expect(
        (await repository.exercises(search: 'BENCH', splitId: push)).single.id,
        bench,
      );
      expect(await repository.exercises(search: '%'), isEmpty);
      expect((await repository.exercises(splitId: -1)).single.name, 'Squat');
      await repository.deleteSplit(push);
      expect(await repository.history(bench), hasLength(1));
      expect(await repository.memberships(bench), {upper});
    },
  );
  test(
    'ordered sets and note survive editing; creation time is preserved',
    () async {
      final id = await repository.saveExercise('Bench', {});
      final draft = performance()..note = 'Shoulder recovering';
      draft.sets.addAll([
        SetInput(weight: '80', reps: '9'),
        SetInput(weight: '75', reps: '10'),
      ]);
      final entryId = await repository.saveEntry(id, draft);
      final created = (await db.query(
        'exercise_entries',
      )).single['created_at_ms'];
      final entry = (await repository.history(id)).single;
      expect(entry.sets.map((s) => s.grams), [80000, 80000, 75000]);
      expect(entry.sets.map((s) => s.reps), [10, 9, 10]);
      final edit = EntryDraft.fromEntry(entry)..note = 'Corrected';
      edit.sets.removeLast();
      await repository.saveEntry(id, edit);
      expect((await repository.history(id)).single.id, entryId);
      expect((await repository.history(id)).single.note, 'Corrected');
      expect(
        (await db.query('exercise_entries')).single['created_at_ms'],
        created,
      );
    },
  );
  test('history cannot be cascaded away by deleting an exercise', () async {
    final id = await repository.saveExercise('Bench', {});
    final entryId = await repository.saveEntry(id, performance());
    await expectLater(
      repository.deleteEmptyExercise(id),
      throwsA(isA<DatabaseException>()),
    );
    await repository.archive(id, true);
    expect(await repository.exercises(), isEmpty);
    expect(await repository.exercises(archived: true), hasLength(1));
    await expectLater(
      repository.saveEntry(id, performance()),
      throwsStateError,
    );
    await repository.archive(id, false);
    await repository.deleteEntry(entryId);
    expect(await db.query('entry_sets'), isEmpty);
    await repository.deleteEmptyExercise(id);
  });
  test('failed edit rolls back entry, sets and draft together', () async {
    final id = await repository.saveExercise('Bench', {});
    await repository.saveEntry(id, performance());
    final edit = EntryDraft.fromEntry((await repository.history(id)).single)
      ..note = 'Should roll back';
    await repository.saveDraft(id, edit);
    await db.execute(
      "CREATE TRIGGER reject_sets BEFORE INSERT ON entry_sets BEGIN SELECT RAISE(ABORT, 'simulated failure'); END",
    );
    await expectLater(
      repository.saveEntry(id, edit),
      throwsA(isA<DatabaseException>()),
    );
    final saved = (await repository.history(id)).single;
    expect(saved.note, isNull);
    expect(saved.sets.single.reps, 10);
    expect(await repository.draft(id), isNotNull);
  });
  test(
    'persistent drafts do not change last performed and ownership is enforced',
    () async {
      final a = await repository.saveExercise('Bench', {});
      final b = await repository.saveExercise('Squat', {});
      final draft = performance(weight: '80,');
      await repository.saveDraft(a, draft);
      expect((await repository.draft(a))!.sets.first.weight, '80,');
      expect((await repository.exercises()).first.lastAtMs, isNull);
      final entryId = await repository.saveEntry(b, performance());
      draft.editingEntryId = entryId;
      await expectLater(repository.saveDraft(a, draft), throwsStateError);
    },
  );
  test('queued draft changes cannot resurrect a draft after saving', () async {
    final id = await repository.saveExercise('Bench', {});
    final controller = EntryController(repository, id);
    await controller.load();
    controller.draft.sets.first
      ..weight = '80'
      ..reps = '10';
    controller.changed();
    controller.draft.sets.first.reps = '9';
    controller.changed();
    await controller.save();
    expect(await repository.draft(id), isNull);
    expect((await repository.history(id)).single.sets.single.reps, 9);
    controller.dispose();
  });
  test(
    'multiple same-day entries have deterministic order and paging',
    () async {
      final id = await repository.saveExercise('Bench', {});
      final draft = performance();
      final ids = <int>[];
      for (var i = 0; i < 32; i++) {
        ids.add(await repository.saveEntry(id, draft));
      }
      final firstPage = await repository.history(id);
      final secondPage = await repository.history(id, offset: 30);
      expect(firstPage.map((e) => e.id), ids.reversed.take(30));
      expect(secondPage, hasLength(2));
    },
  );
}
