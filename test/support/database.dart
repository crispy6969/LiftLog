import 'package:flutter_test/flutter_test.dart';
import 'package:liftlog/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> testDatabase() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  return AppDatabase.open(
    factory: createDatabaseFactoryFfi(noIsolate: true),
    path: inMemoryDatabasePath,
  );
}
