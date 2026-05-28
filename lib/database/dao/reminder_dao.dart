import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../../models/reminder.dart';

class ReminderDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Reminder>> getActive() async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final maps = await db.query('reminder',
        where: 'is_dismissed = 0 AND remind_at <= ?',
        whereArgs: [now],
        orderBy: 'remind_at ASC');
    return maps.map((m) => Reminder.fromMap(m)).toList();
  }

  Future<List<Reminder>> getUpcoming({int days = 7}) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final future =
        DateTime.now().add(Duration(days: days)).toIso8601String();
    final maps = await db.query('reminder',
        where: 'is_dismissed = 0 AND remind_at >= ? AND remind_at <= ?',
        whereArgs: [now, future],
        orderBy: 'remind_at ASC');
    return maps.map((m) => Reminder.fromMap(m)).toList();
  }

  Future<List<Reminder>> getByOrderId(String orderId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('reminder',
        where: 'order_id = ?',
        whereArgs: [orderId],
        orderBy: 'remind_at ASC');
    return maps.map((m) => Reminder.fromMap(m)).toList();
  }

  Future<void> insert(Reminder reminder) async {
    final db = await _dbHelper.database;
    await db.insert('reminder', reminder.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertBatch(List<Reminder> reminders) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final r in reminders) {
      batch.insert('reminder', r.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> dismiss(String id) async {
    final db = await _dbHelper.database;
    await db.update('reminder', {'is_dismissed': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markRead(String id) async {
    final db = await _dbHelper.database;
    await db.update('reminder', {'is_read': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteByOrderId(String orderId) async {
    final db = await _dbHelper.database;
    await db.delete('reminder', where: 'order_id = ?', whereArgs: [orderId]);
  }
}