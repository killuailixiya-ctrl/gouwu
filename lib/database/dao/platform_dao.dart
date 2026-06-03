import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../../models/platform.dart';

class PlatformDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Platform>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query('platform', orderBy: 'sort_order ASC');
    return maps.map((m) => Platform.fromMap(m)).toList();
  }

  Future<Platform?> getById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('platform', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Platform.fromMap(maps.first);
  }

  Future<void> insert(Platform platform) async {
    final db = await _dbHelper.database;
    await db.insert('platform', platform.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Platform platform) async {
    final db = await _dbHelper.database;
    await db.update('platform', platform.toMap(),
        where: 'id = ?', whereArgs: [platform.id]);
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete('platform', where: 'id = ?', whereArgs: [id]);
  }
}