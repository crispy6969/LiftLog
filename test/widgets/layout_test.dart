import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftlog/shared/material.dart';
import 'package:liftlog/app.dart';
import 'package:liftlog/features/entries/models/entry.dart';
import 'package:liftlog/features/exercises/data/tracker_repository.dart';
import 'package:liftlog/features/weight/data/weight_repository.dart';
import '../support/database.dart';

void main() {
  testWidgets('logging and history fit a phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = await testDatabase();
    addTearDown(db.close);
    final repository = TrackerRepository(db);
    final weights = WeightRepository(db);
    await weights.save(
      day: '2026-01-01',
      weight: '80',
      note: 'Started bulking',
    );
    await weights.save(day: '2026-01-10', weight: '81.5', note: '');
    await weights.save(day: '2026-02-01', weight: '82', note: '');
    // Flutter widget tests default to the block-shaped Ahem font. Load the SDK
    // fonts so saved screenshots are useful for actual visual inspection.
    final configFile = File('.dart_tool/package_config.json');
    final config =
        jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    final flutterPackage = (config['packages'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .singleWhere((p) => p['name'] == 'flutter');
    final sdk = Directory.fromUri(
      configFile.absolute.uri.resolve(flutterPackage['rootUri'] as String),
    ).parent.parent;
    final fonts = Directory('${sdk.path}/bin/cache/artifacts/material_fonts');
    Future<void> loadFont(String family, String filename) async {
      final bytes = await File('${fonts.path}/$filename').readAsBytes();
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }

    await tester.runAsync(() async {
      await loadFont('Roboto', 'roboto-regular.ttf');
      await loadFont('MaterialIcons', 'materialicons-regular.otf');
    });
    final id = await repository.saveExercise('Bench Press', {});
    final entry = EntryDraft.empty()
      ..note = 'First session back after a shoulder injury.';
    entry.performedAtMs -= const Duration(days: 3).inMilliseconds;
    entry.sets.first
      ..weight = '80'
      ..reps = '10';
    entry.sets.addAll([
      SetInput(weight: '80', reps: '9'),
      SetInput(weight: '75', reps: '10'),
    ]);
    await repository.saveEntry(id, entry);
    const capture = ValueKey('capture');
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: LiftlogApp(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Future<void> screenshot(String name) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(capture),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/screenshots').create(recursive: true);
        await File(
          'build/screenshots/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await screenshot('logging');
    await tester.ensureVisible(
      find.text('First session back after a shoulder injury.'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await screenshot('history');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await screenshot('workout');
    await tester.tap(find.text('Weight'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await screenshot('weight-tracker');
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await screenshot('login');
  });
}
