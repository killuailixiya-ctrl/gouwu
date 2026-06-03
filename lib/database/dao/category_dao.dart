import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../../models/category.dart';

class CategoryDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Category>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query('category', orderBy: 'sort_order ASC');
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  Future<Category?> getById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('category', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Category.fromMap(maps.first);
  }

  Future<void> insert(Category category) async {
    final db = await _dbHelper.database;
    await db.insert('category', category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Category category) async {
    final db = await _dbHelper.database;
    await db.update('category', category.toMap(),
        where: 'id = ?', whereArgs: [category.id]);
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete('category', where: 'id = ?', whereArgs: [id]);
  }
}