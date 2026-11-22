import 'package:flutter_test/flutter_test.dart';
import 'package:liftlog/shared/material.dart';
import 'package:liftlog/app.dart';
import 'package:liftlog/features/exercises/data/tracker_repository.dart';
import '../support/database.dart';

void main() {
  testWidgets('empty state, creation and inline set validation', (
    tester,
  ) async {
    final db = await testDatabase();
    addTearDown(db.close);
    final repository = TrackerRepository(db);
    await tester.pumpWidget(LiftlogApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Create your first exercise'), findsOneWidget);
    await tester.tap(find.text('Create your first exercise'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Exercise name'),
      'Bench Press',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Bench Press'), findsOneWidget);
    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save entry'));
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(find.text('Use 0 or more kg'), findsOneWidget);
    expect(find.text('Positive reps; max 1 decimal'), findsOneWidget);
    expect(
      await repository.history((await repository.exercises()).single.id),
      isEmpty,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Weight (kg)'),
      '80',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Repetitions'),
      '10',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Note (optional)'),
      'First session back',
    );
    await tester.ensureVisible(find.text('Save entry'));
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(find.text('Entry saved'), findsOneWidget);
    final saved = (await repository.history(
      (await repository.exercises()).single.id,
    )).single;
    expect(saved.sets.single.grams, 80000);
    expect(saved.note, 'First session back');
    await tester.ensureVisible(find.text('First session back'));
    expect(tester.takeException(), isNull);
  });
}
