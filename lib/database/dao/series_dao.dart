import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../../models/series.dart';

class SeriesDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Series>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query('series', orderBy: 'sort_order ASC');
    return maps.map((m) => Series.fromMap(m)).toList();
  }

  Future<Series?> getById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('series', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Series.fromMap(maps.first);
  }

  Future<List<Series>> search(String keyword) async {
    final db = await _dbHelper.database;
    final like = '%$keyword%';
    final maps = await db.query('series',
        where: 'name LIKE ? OR aliases LIKE ?',
        whereArgs: [like, like],
        orderBy: 'sort_order ASC');
    return maps.map((m) => Series.fromMap(m)).toList();
  }

  Future<void> insert(Series series) async {
    final db = await _dbHelper.database;
    await db.insert('series', series.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Series series) async {
    final db = await _dbHelper.database;
    await db.update('series', series.toMap(),
        where: 'id = ?', whereArgs: [series.id]);
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete('series', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateSortOrder(String id, int sortOrder) async {
    final db = await _dbHelper.database;
    await db.update('series', {'sort_order': sortOrder},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>> getStats(String seriesId) async {
    final db = await _dbHelper.database;
    final characters = await db.query('"character"',
        where: 'series_id = ?', whereArgs: [seriesId]);
    final items = await db.query('order_item',
        where: 'series_id = ?', whereArgs: [seriesId]);
    final totalSpent = items.fold<double>(
        0, (sum, item) => sum + ((item['unit_price'] as num?)?.toDouble() ?? 0) * ((item['quantity'] as int?) ?? 1));
    return {
      'character_count': characters.length,
      'product_count': items.length,
      'total_spent': totalSpent,
    };
  }
}