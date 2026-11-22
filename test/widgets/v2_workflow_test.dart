import 'package:flutter_test/flutter_test.dart';
import 'package:liftlog/app.dart';
import 'package:liftlog/core/formatting/values.dart';
import 'package:liftlog/features/entries/models/entry.dart';
import 'package:liftlog/features/exercises/data/tracker_repository.dart';
import 'package:liftlog/features/weight/data/weight_repository.dart';
import 'package:liftlog/features/weight/presentation/weight_chart.dart';
import 'package:liftlog/shared/material.dart';
import '../support/database.dart';

void main() {
  testWidgets(
    'mock signup accepts blank fields, gates all features, and logout returns to login',
    (tester) async {
      final db = (await tester.runAsync(testDatabase))!;
      addTearDown(db.close);
      await tester.pumpWidget(LiftlogApp(repository: TrackerRepository(db)));
      await tester.pumpAndSettle();
      expect(find.text('Workout'), findsNothing);
      expect(find.text('Weight tracker'), findsNothing);
      await tester.tap(find.text('New here? Sign up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Mock user'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Backup & restore'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(find.text('Log in'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    },
  );

  testWidgets(
    'phone-sized location/split filters share a row and new sets compare directly with the latest',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = (await tester.runAsync(testDatabase))!;
      addTearDown(db.close);
      final repository = TrackerRepository(db);
      await repository.saveLocation('Gym A');
      final location = (await repository.locations()).single;
      final id = await repository.saveExercise(
        'Bench',
        {},
        locationId: location.id,
      );
      final entry = EntryDraft.empty();
      entry.sets.first
        ..weight = '80'
        ..reps = '7.5';
      entry.sets.addAll([
        SetInput(weight: '75', reps: '7'),
        SetInput(weight: '70', reps: '6'),
      ]);
      await repository.saveEntry(id, entry);
      await tester.pumpWidget(LiftlogApp(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      final split = find.widgetWithText(
        DropdownButtonFormField<int>,
        'Split day',
      );
      final place = find.widgetWithText(
        DropdownButtonFormField<int>,
        'Location',
      );
      expect(tester.getTopLeft(split).dy, tester.getTopLeft(place).dy);
      await tester.tap(find.text('Bench'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, 'Repetitions'),
        findsNWidgets(3),
      );
      expect(find.text('80 kg × 7.5 reps'), findsOneWidget);
      final inputs = tester.widgetList<TextFormField>(
        find.widgetWithText(TextFormField, 'Repetitions'),
      );
      expect(inputs.every((input) => input.initialValue!.isEmpty), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'weight tab adds decimal measurements and notes and rejects duplicate dates',
    (tester) async {
      final db = (await tester.runAsync(testDatabase))!;
      addTearDown(db.close);
      final repository = TrackerRepository(db);
      await tester.pumpWidget(LiftlogApp(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weight'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add weight'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Body weight (kg)'),
        '81.4',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Note (optional)'),
        'Started bulking',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.byType(WeightChart), findsOneWidget);
      expect(find.text('Started bulking'), findsOneWidget);
      expect(
        (await WeightRepository(db).entries()).single.day,
        dayKey(DateTime.now()),
      );
      await tester.tap(find.text('Add weight'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Body weight (kg)'),
        '82',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'There is already a measurement for this date. Edit it from the list.',
        ),
        findsOneWidget,
      );
      expect(await WeightRepository(db).entries(), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'weight chart positions use time spacing, including single points and flat series',
    () {
      const entries = [
        BodyWeight(id: 1, day: '2020-01-01', grams: 80000),
        BodyWeight(id: 2, day: '2020-01-02', grams: 80000),
        BodyWeight(id: 3, day: '2020-01-10', grams: 82000),
      ];
      final points = chartPoints(entries, const Size(360, 240));
      expect(
        points[2].dx - points[1].dx,
        greaterThan((points[1].dx - points[0].dx) * 7),
      );
      expect(
        chartPoints(
          entries.take(1).toList(),
          const Size(360, 240),
        ).single.isFinite,
        isTrue,
      );
    },
  );
}
