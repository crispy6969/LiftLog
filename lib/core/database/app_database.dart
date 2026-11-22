import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const version = 2;

  static Future<Database> open({DatabaseFactory? factory, String? path}) async {
    final selected = factory ?? databaseFactory;
    final location =
        path ?? p.join(await selected.getDatabasesPath(), 'liftlog.db');
    return selected.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) async {
          // Rebuilding a parent table requires temporarily disabling foreign
          // keys BEFORE sqflite's upgrade transaction, not inside it.
          final old = await db.getVersion();
          await db.execute('PRAGMA foreign_keys = ${old == 1 ? 'OFF' : 'ON'}');
        },
        onOpen: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          final schema = await rootBundle.loadString(
            'lib/core/database/schema.sql',
          );
          for (final statement in schema.split(';')) {
            if (statement.trim().isNotEmpty) await db.execute(statement);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion == 1 && newVersion == 2) {
            await db.execute(
              'CREATE TABLE locations (id INTEGER PRIMARY KEY, name TEXT NOT NULL CHECK(length(trim(name)) > 0), name_key TEXT NOT NULL UNIQUE CHECK(length(name_key) > 0))',
            );
            await db.execute(
              'CREATE TABLE exercises_v2 (id INTEGER PRIMARY KEY, name TEXT NOT NULL CHECK(length(trim(name)) > 0), name_key TEXT NOT NULL CHECK(length(name_key) > 0), location_id INTEGER REFERENCES locations(id) ON DELETE RESTRICT, is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN (0, 1)))',
            );
            await db.execute(
              'INSERT INTO exercises_v2(id,name,name_key,is_archived) SELECT id,name,name_key,is_archived FROM exercises',
            );
            await db.execute('DROP TABLE exercises');
            await db.execute('ALTER TABLE exercises_v2 RENAME TO exercises');
            await db.execute(
              'CREATE UNIQUE INDEX idx_exercise_any_name ON exercises(name_key) WHERE location_id IS NULL',
            );
            await db.execute(
              'CREATE UNIQUE INDEX idx_exercise_location_name ON exercises(name_key, location_id) WHERE location_id IS NOT NULL',
            );
            await db.execute(
              'CREATE INDEX idx_exercise_location ON exercises(location_id)',
            );
            await db.execute(
              'CREATE TABLE entry_sets_v2 (id INTEGER PRIMARY KEY, entry_id INTEGER NOT NULL REFERENCES exercise_entries(id) ON DELETE CASCADE, position INTEGER NOT NULL CHECK(position >= 1), weight_grams INTEGER NOT NULL CHECK(weight_grams >= 0), reps_tenths INTEGER NOT NULL CHECK(reps_tenths > 0), UNIQUE(entry_id, position))',
            );
            await db.execute(
              'INSERT INTO entry_sets_v2 SELECT id,entry_id,position,weight_grams,reps * 10 FROM entry_sets',
            );
            await db.execute('DROP TABLE entry_sets');
            await db.execute('ALTER TABLE entry_sets_v2 RENAME TO entry_sets');
            await db.execute(
              'CREATE TABLE body_weights (id INTEGER PRIMARY KEY, day TEXT NOT NULL UNIQUE, weight_grams INTEGER NOT NULL CHECK(weight_grams > 0), note TEXT, created_at_ms INTEGER NOT NULL, updated_at_ms INTEGER NOT NULL)',
            );
            if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
              throw StateError(
                'Migration could not preserve database relationships.',
              );
            }
          } else {
            throw StateError('No migration from $oldVersion to $newVersion.');
          }
        },
        onDowngrade: (db, oldVersion, newVersion) async {
          throw StateError('This database needs a newer version of Liftlog.');
        },
      ),
    );
  }
}
