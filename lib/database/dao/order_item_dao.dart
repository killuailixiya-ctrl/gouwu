import '../database_helper.dart';
import '../../models/order_item.dart';

class OrderItemDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<OrderItem>> getByOrderId(String orderId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('order_item',
        where: 'order_id = ?',
        whereArgs: [orderId],
        orderBy: 'sort_order ASC');
    return maps.map((m) => OrderItem.fromMap(m)).toList();
  }

  Future<OrderItem?> getById(String id) async {
    final db = await _dbHelper.database;
    final maps =
        await db.query('order_item', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return OrderItem.fromMap(maps.first);
  }

  Future<List<OrderItem>> getByCharacterId(String characterId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('order_item',
        where: 'character_id = ?',
        whereArgs: [characterId],
        orderBy: 'created_at DESC');
    return maps.map((m) => OrderItem.fromMap(m)).toList();
  }

  Future<List<OrderItem>> getBySeriesId(String seriesId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('order_item',
        where: 'series_id = ?',
        whereArgs: [seriesId],
        orderBy: 'created_at DESC');
    return maps.map((m) => OrderItem.fromMap(m)).toList();
  }

  Future<List<OrderItem>> getByCategoryId(String categoryId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('order_item',
        where: 'category_id = ?',
        whereArgs: [categoryId],
        orderBy: 'created_at DESC');
    return maps.map((m) => OrderItem.fromMap(m)).toList();
  }

  Future<List<OrderItem>> search(String keyword) async {
    final db = await _dbHelper.database;
    final allMaps = await db.query('order_item', orderBy: 'created_at DESC');
    return allMaps
        .where((m) {
          final name = (m['name'] as String? ?? '').toLowerCase();
          final spec = (m['spec'] as String? ?? '').toLowerCase();
          final sourceText = (m['source_text'] as String? ?? '').toLowerCase();
          final kw = keyword.toLowerCase();
          return name.contains(kw) || spec.contains(kw) || sourceText.contains(kw);
        })
        .map((m) => OrderItem.fromMap(m))
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchAll(String keyword) async {
    final db = await _dbHelper.database;
    final results = <Map<String, dynamic>>[];
    final kw = keyword.toLowerCase();

    final allSeries = await db.query('series');
    for (final s in allSeries) {
      final name = (s['name'] as String? ?? '').toLowerCase();
      final aliases = (s['aliases'] as String? ?? '').toLowerCase();
      if (!name.contains(kw) && !aliases.contains(kw)) continue;
      final items = await db.query('order_item',
          where: 'series_id = ?', whereArgs: [s['id']]);
      results.add({
        'result_type': 'series',
        'id': s['id'],
        'name': s['name'],
        'product_count': items.map((i) => i['name']).toSet().length,
        'character_name': null,
        'platform_name': null,
        'unit_price': null,
        'image_path': null,
        'order_time': null,
        'item_status': null,
      });
    }

    final allCharacters = await db.query('"character"');
    for (final c in allCharacters) {
      final name = (c['name'] as String? ?? '').toLowerCase();
      final aliases = (c['aliases'] as String? ?? '').toLowerCase();
      if (!name.contains(kw) && !aliases.contains(kw)) continue;
      final items = await db.query('order_item',
          where: 'character_id = ?', whereArgs: [c['id']]);
      final seriesMaps = await db.query('series',
          where: 'id = ?', whereArgs: [c['series_id']]);
      results.add({
        'result_type': 'character',
        'id': c['id'],
        'name': c['name'],
        'product_count': items.length,
        'character_name': seriesMaps.isNotEmpty ? seriesMaps.first['name'] : null,
        'platform_name': null,
        'unit_price': null,
        'image_path': null,
        'order_time': null,
        'item_status': null,
      });
    }

    final allItems = await db.query('order_item');
    final allOrders = await db.query('"order"');
    final allPlatforms = await db.query('platform');
    final allChars = await db.query('"character"');
    for (final item in allItems) {
      final name = (item['name'] as String? ?? '').toLowerCase();
      if (!name.contains(kw)) continue;
      final order = allOrders.where((o) => o['id'] == item['order_id']).firstOrNull;
      final platform = order != null
          ? allPlatforms.where((p) => p['id'] == order['platform_id']).firstOrNull
          : null;
      final character = item['character_id'] != null
          ? allChars.where((c) => c['id'] == item['character_id']).firstOrNull
          : null;
      results.add({
        'result_type': 'product',
        'id': item['id'],
        'name': item['name'],
        'product_count': null,
        'character_name': character?['name'] ?? '未归属',
        'platform_name': platform?['name'],
        'unit_price': item['unit_price'],
        'image_path': item['image_path'],
        'order_time': order?['order_time'],
        'item_status': order?['status'],
      });
    }

    return results;
  }

  Future<void> insert(OrderItem item) async {
    final db = await _dbHelper.database;
    await db.insert('order_item', item.toMap());
  }

  Future<void> insertBatch(List<OrderItem> items) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert('order_item', item.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> update(OrderItem item) async {
    final db = await _dbHelper.database;
    await db.update('order_item', item.toMap(),
        where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> deleteByOrderId(String orderId) async {
    final db = await _dbHelper.database;
    await db.delete('order_item', where: 'order_id = ?', whereArgs: [orderId]);
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete('order_item', where: 'id = ?', whereArgs: [id]);
  }
}