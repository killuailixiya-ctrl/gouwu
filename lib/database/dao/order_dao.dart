import '../database_helper.dart';
import '../../models/order.dart';

class OrderDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Order>> getAll({String? status, String? platformId}) async {
    final db = await _dbHelper.database;
    String? where;
    List<dynamic>? whereArgs;

    final conditions = <String>[];
    final args = <dynamic>[];
    if (status != null) {
      conditions.add('status = ?');
      args.add(status);
    }
    if (platformId != null) {
      conditions.add('platform_id = ?');
      args.add(platformId);
    }
    if (conditions.isNotEmpty) {
      where = conditions.join(' AND ');
      whereArgs = args;
    }

    final maps = await db.query('"order"',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'order_time DESC');
    return maps.map((m) => Order.fromMap(m)).toList();
  }

  Future<Order?> getById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('"order"', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Order.fromMap(maps.first);
  }

  Future<List<Order>> getPresellOrders() async {
    final db = await _dbHelper.database;
    final maps = await db.query('"order"',
        where: 'is_presell = 1 AND status != ? AND status != ?',
        whereArgs: ['completed', 'cancelled'],
        orderBy: 'balance_deadline ASC');
    return maps.map((m) => Order.fromMap(m)).toList();
  }

  Future<List<Order>> getRecentOrders({int limit = 10}) async {
    final db = await _dbHelper.database;
    final maps = await db.query('"order"',
        orderBy: 'order_time DESC', limit: limit);
    return maps.map((m) => Order.fromMap(m)).toList();
  }

  Future<List<Order>> getByDateRange(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final maps = await db.query('"order"',
        where: 'order_time >= ? AND order_time <= ?',
        whereArgs: [start.toIso8601String(), end.toIso8601String()],
        orderBy: 'order_time DESC');
    return maps.map((m) => Order.fromMap(m)).toList();
  }

  Future<void> insert(Order order) async {
    final db = await _dbHelper.database;
    await db.insert('"order"', order.toMap());
  }

  Future<void> update(Order order) async {
    final db = await _dbHelper.database;
    await db.update('"order"', order.toMap(),
        where: 'id = ?', whereArgs: [order.id]);
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete('"order"', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getMonthlyTotal(int year, int month) async {
    final db = await _dbHelper.database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 1).toIso8601String();
    final allOrders = await db.query('"order"',
        where: 'status != ?', whereArgs: ['cancelled']);
    return allOrders
        .where((o) {
          final time = o['order_time'] as String?;
          if (time == null) return false;
          return time.compareTo(startDate) >= 0 && time.compareTo(endDate) < 0;
        })
        .fold<double>(0, (sum, o) => sum + ((o['total_amount'] as num?)?.toDouble() ?? 0));
  }

  Future<Map<String, double>> getPlatformSpending() async {
    final db = await _dbHelper.database;
    final allOrders = await db.query('"order"',
        where: 'status != ?', whereArgs: ['cancelled']);
    final allPlatforms = await db.query('platform');
    final platformMap = {for (final p in allPlatforms) p['id'] as String: p['name'] as String};
    final map = <String, double>{};
    for (final order in allOrders) {
      final platformId = order['platform_id'] as String;
      final name = platformMap[platformId] ?? '未知';
      map[name] = (map[name] ?? 0) + ((order['total_amount'] as num?)?.toDouble() ?? 0);
    }
    return map;
  }
}