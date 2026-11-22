import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liftlog/app.dart';
import 'package:liftlog/core/database/app_database.dart';
import 'package:liftlog/features/backup/data/backup_service.dart';
import 'package:liftlog/features/entries/models/entry.dart';
import 'package:liftlog/features/exercises/data/tracker_repository.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native SQLite persists a workout and restores a backup', (
    tester,
  ) async {
    final path = '${await getDatabasesPath()}/integration-only.db';
    await deleteDatabase(path);
    var db = await AppDatabase.open(path: path);
    try {
      var repository = TrackerRepository(db);
      final id = await repository.saveExercise('Bench Press', {});
      final draft = EntryDraft.empty()..note = 'First session back';
      draft.sets.first
        ..weight = '80'
        ..reps = '10';
      draft.sets.addAll([
        SetInput(weight: '80', reps: '9'),
        SetInput(weight: '75', reps: '10'),
      ]);
      await repository.saveEntry(id, draft);
      await repository.saveDraft(
        id,
        EntryDraft.empty()..note = 'Resume after restart',
      );
      await db.close();
      db = await AppDatabase.open(path: path);
      repository = TrackerRepository(db);
      expect((await repository.history(id)).single.sets, hasLength(3));
      expect((await repository.draft(id))!.note, 'Resume after restart');
      final edit = EntryDraft.fromEntry((await repository.history(id)).single);
      edit.sets.first.reps = '11';
      await repository.saveEntry(id, edit);
      final backup = BackupService(db);
      final source = await backup.export();
      await repository.deleteEntry((await repository.history(id)).single.id);
      await backup.restore(source);
      expect((await repository.history(id)).single.sets.first.reps, 11);
      await tester.pumpWidget(LiftlogApp(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Bench Press'), findsOneWidget);
    } finally {
      await db.close();
      await deleteDatabase(path);
    }
  });
}
