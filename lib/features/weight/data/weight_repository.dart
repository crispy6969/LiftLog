import 'package:sqflite/sqflite.dart';
import '../../../core/formatting/values.dart';

class BodyWeight {
  const BodyWeight({
    required this.id,
    required this.day,
    required this.grams,
    this.note,
  });
  final int id;
  final String day;
  final int grams;
  final String? note;
  DateTime get date => DateTime.parse(day);
}

class WeightRepository {
  WeightRepository(this.db);
  final Database db;
  Future<List<BodyWeight>> entries() async =>
      (await db.query('body_weights', orderBy: 'day DESC'))
          .map(
            (r) => BodyWeight(
              id: r['id'] as int,
              day: r['day'] as String,
              grams: r['weight_grams'] as int,
              note: r['note'] as String?,
            ),
          )
          .toList();

  Future<void> save({
    int? id,
    required String day,
    required String weight,
    required String note,
  }) async {
    final grams = parseGrams(weight);
    if (grams == null || grams <= 0) {
      throw const FormatException(
        'Enter a weight greater than 0 kg, with up to 3 decimal places.',
      );
    }
    if (!validDay(day) || day.compareTo(dayKey(DateTime.now())) > 0) {
      throw const FormatException('Choose today or an earlier date.');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = <String, Object?>{
      'day': day,
      'weight_grams': grams,
      'note': note.trim().isEmpty ? null : note.trim(),
      'updated_at_ms': now,
    };
    if (id == null) {
      row['created_at_ms'] = now;
      await db.insert('body_weights', row);
    } else {
      await db.update('body_weights', row, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> delete(int id) async =>
      db.delete('body_weights', where: 'id = ?', whereArgs: [id]);
}
