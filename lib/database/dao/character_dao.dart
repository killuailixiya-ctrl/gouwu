import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../../models/character.dart';

class CharacterDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Character>> getBySeries(String seriesId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('"character"',
        where: 'series_id = ?',
        whereArgs: [seriesId],
        orderBy: 'sort_order ASC');
    return maps.map((m) => Character.fromMap(m)).toList();
  }

  Future<Character?> getById(String id) async {
    final db = await _dbHelper.database;
    final maps =
        await db.query('"character"', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Character.fromMap(maps.first);
  }

  Future<List<Character>> search(String keyword) async {
    final db = await _dbHelper.database;
    final like = '%$keyword%';
    final maps = await db.query('"character"',
        where: 'name LIKE ? OR aliases LIKE ?',
        whereArgs: [like, like],
        orderBy: 'sort_order ASC');
    return maps.map((m) => Character.fromMap(m)).toList();
  }

  Future<List<Character>> searchInSeries(String seriesId, String keyword) async {
    final db = await _dbHelper.database;
    final maps = await db.query('"character"',
        where: 'series_id = ?',
        whereArgs: [seriesId],
        orderBy: 'sort_order ASC');
    final kw = keyword.toLowerCase();
    return maps
        .where((m) {
          final name = (m['name'] as String? ?? '').toLowerCase();
          final aliases = (m['aliases'] as String? ?? '').toLowerCase();
          return name.contains(kw) || aliases.contains(kw);
        })
        .map((m) => Character.fromMap(m))
        .toList();
  }

  Future<void> insert(Character character) async {
    final db = await _dbHelper.database;
    await db.insert('"character"', character.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Character character) async {
    final db = await _dbHelper.database;
    await db.update('"character"', character.toMap(),
        where: 'id = ?', whereArgs: [character.id]);
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete('"character"', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateSortOrder(String id, int sortOrder) async {
    final db = await _dbHelper.database;
    await db.update('"character"', {'sort_order': sortOrder},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>> getStats(String characterId) async {
    final db = await _dbHelper.database;
    final items = await db.query('order_item',
        where: 'character_id = ?', whereArgs: [characterId]);
    final orderIds = items.map((i) => i['order_id'] as String).toSet();
    final totalSpent = items.fold<double>(
        0, (sum, item) => sum + ((item['unit_price'] as num?)?.toDouble() ?? 0) * ((item['quantity'] as int?) ?? 1));
    String platforms = '';
    if (orderIds.isNotEmpty) {
      final allOrders = await db.query('"order"');
      final allPlatforms = await db.query('platform');
      final platformIds = allOrders
          .where((o) => orderIds.contains(o['id']))
          .map((o) => o['platform_id'] as String)
          .toSet();
      platforms = allPlatforms
          .where((p) => platformIds.contains(p['id']))
          .map((p) => p['name'] as String)
          .join(', ');
    }
    return {
      'product_count': items.length,
      'order_count': orderIds.length,
      'total_spent': totalSpent,
      'platforms': platforms,
    };
  }
}