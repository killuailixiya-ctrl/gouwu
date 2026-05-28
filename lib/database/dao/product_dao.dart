import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../../models/product.dart';

class ProductDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Product>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query('product', orderBy: 'last_bought DESC');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<Product?> getById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('product', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<Product?> findByNormalizedName(String normalizedName) async {
    final db = await _dbHelper.database;
    final maps = await db.query('product',
        where: 'normalized_name = ?', whereArgs: [normalizedName]);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<List<Product>> searchByName(String keyword) async {
    final db = await _dbHelper.database;
    final like = '%$keyword%';
    final maps = await db.query('product',
        where: 'normalized_name LIKE ? OR display_name LIKE ?',
        whereArgs: [like, like],
        orderBy: 'last_bought DESC');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<List<Product>> getByCharacterId(String characterId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('product',
        where: 'character_id = ?',
        whereArgs: [characterId],
        orderBy: 'last_bought DESC');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<List<Product>> getBySeriesId(String seriesId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('product',
        where: 'series_id = ?',
        whereArgs: [seriesId],
        orderBy: 'last_bought DESC');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<List<Product>> getByCategoryId(String categoryId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('product',
        where: 'category_id = ?',
        whereArgs: [categoryId],
        orderBy: 'last_bought DESC');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<void> insert(Product product) async {
    final db = await _dbHelper.database;
    await db.insert('product', product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Product product) async {
    final db = await _dbHelper.database;
    await db.update('product', product.toMap(),
        where: 'id = ?', whereArgs: [product.id]);
  }

  Future<void> upsert(Product product) async {
    final existing = await getById(product.id);
    if (existing != null) {
      await update(product);
    } else {
      await insert(product);
    }
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete('product', where: 'id = ?', whereArgs: [id]);
  }
}