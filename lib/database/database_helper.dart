import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'memory_database.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      final db = MemoryDatabase();
      await _onCreate(db, 3);
      return db;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'gouwu.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE platform (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT,
        color_code TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE series (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        aliases TEXT,
        cover_image TEXT,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE "character" (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        aliases TEXT,
        series_id TEXT NOT NULL,
        avatar_path TEXT,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (series_id) REFERENCES series(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE category (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT,
        sort_order INTEGER DEFAULT 0,
        parent_id TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (parent_id) REFERENCES category(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE "order" (
        id TEXT PRIMARY KEY,
        platform_id TEXT NOT NULL,
        order_no TEXT,
        total_amount REAL DEFAULT 0,
        status TEXT NOT NULL,
        is_presell INTEGER DEFAULT 0,
        deposit_amount REAL,
        deposit_time TEXT,
        balance_deadline TEXT,
        order_time TEXT NOT NULL,
        raw_source TEXT,
        raw_text TEXT,
        notes TEXT,
        screenshot_path TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (platform_id) REFERENCES platform(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE order_item (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        product_id TEXT,
        name TEXT NOT NULL,
        spec TEXT,
        unit_price REAL DEFAULT 0,
        quantity INTEGER DEFAULT 1,
        item_status TEXT,
        image_path TEXT,
        image_hash TEXT,
        category_id TEXT,
        series_id TEXT,
        character_id TEXT,
        source_text TEXT,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES "order"(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES product(id),
        FOREIGN KEY (category_id) REFERENCES category(id),
        FOREIGN KEY (series_id) REFERENCES series(id),
        FOREIGN KEY (character_id) REFERENCES "character"(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE product (
        id TEXT PRIMARY KEY,
        normalized_name TEXT NOT NULL,
        display_name TEXT NOT NULL,
        category_id TEXT,
        series_id TEXT,
        character_id TEXT,
        avg_price REAL DEFAULT 0,
        total_owned INTEGER DEFAULT 1,
        first_bought TEXT,
        last_bought TEXT,
        cover_image TEXT,
        image_hash TEXT,
        name_vector TEXT,
        is_favorite INTEGER DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES category(id),
        FOREIGN KEY (series_id) REFERENCES series(id),
        FOREIGN KEY (character_id) REFERENCES "character"(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE reminder (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        order_item_id TEXT,
        type TEXT NOT NULL,
        remind_at TEXT NOT NULL,
        remind_before TEXT,
        message TEXT,
        is_read INTEGER DEFAULT 0,
        is_dismissed INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES "order"(id) ON DELETE CASCADE,
        FOREIGN KEY (order_item_id) REFERENCES order_item(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE duplicate_check (
        id TEXT PRIMARY KEY,
        new_item_id TEXT NOT NULL,
        existing_product_id TEXT NOT NULL,
        similarity_score REAL NOT NULL,
        match_type TEXT NOT NULL,
        user_action TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (new_item_id) REFERENCES order_item(id),
        FOREIGN KEY (existing_product_id) REFERENCES product(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE product_alias (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        alias TEXT NOT NULL,
        source TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES product(id) ON DELETE CASCADE
      )
    ''');

    await _createIndexes(db);
    await _insertDefaultData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE "order" ADD COLUMN screenshot_path TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE series ADD COLUMN cover_image TEXT');
    }
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
        'CREATE INDEX idx_order_platform ON "order"(platform_id)');
    await db.execute(
        'CREATE INDEX idx_order_time ON "order"(order_time)');
    await db.execute(
        'CREATE INDEX idx_order_status ON "order"(status)');
    await db.execute(
        'CREATE INDEX idx_order_presell ON "order"(is_presell, balance_deadline)');
    await db.execute(
        'CREATE INDEX idx_order_item_order ON order_item(order_id)');
    await db.execute(
        'CREATE INDEX idx_order_item_product ON order_item(product_id)');
    await db.execute(
        'CREATE INDEX idx_order_item_character ON order_item(character_id)');
    await db.execute(
        'CREATE INDEX idx_product_category ON product(category_id)');
    await db.execute(
        'CREATE INDEX idx_product_series ON product(series_id)');
    await db.execute(
        'CREATE INDEX idx_product_character ON product(character_id)');
    await db.execute(
        'CREATE INDEX idx_product_name ON product(normalized_name)');
    await db.execute(
        'CREATE INDEX idx_reminder_time ON reminder(remind_at, is_dismissed)');
    await db.execute(
        'CREATE INDEX idx_character_series ON "character"(series_id)');
    await db.execute(
        'CREATE INDEX idx_character_name ON "character"(name)');
    await db.execute(
        'CREATE INDEX idx_alias_product ON product_alias(product_id)');
  }

  Future<void> _insertDefaultData(Database db) async {
    final now = DateTime.now().toIso8601String();

    final platforms = [
      {'id': 'taobao', 'name': '淘宝', 'color_code': '#FF5000', 'sort_order': 1},
      {'id': 'pinduoduo', 'name': '拼多多', 'color_code': '#E02E24', 'sort_order': 2},
      {'id': 'bilibili', 'name': 'B站会员购', 'color_code': '#FB7299', 'sort_order': 3},
      {'id': 'xianyu', 'name': '闲鱼', 'color_code': '#FFC300', 'sort_order': 4},
      {'id': 'weidian', 'name': '微店', 'color_code': '#07C160', 'sort_order': 5},
      {'id': 'jd', 'name': '京东', 'color_code': '#C91623', 'sort_order': 6},
      {'id': 'other', 'name': '其他', 'color_code': '#999999', 'sort_order': 99},
    ];
    for (final p in platforms) {
      await db.insert('platform', {...p, 'is_active': 1});
    }

    final categories = [
      {'id': 'figure', 'name': '手办', 'sort_order': 1},
      {'id': 'goods', 'name': '谷子', 'sort_order': 2},
      {'id': 'poster', 'name': '海报', 'sort_order': 3},
      {'id': 'cosplay', 'name': 'COS服', 'sort_order': 4},
      {'id': 'nendoroid', 'name': '黏土人', 'sort_order': 5},
      {'id': 'plush', 'name': '毛绒/抱枕', 'sort_order': 6},
      {'id': 'book', 'name': '画集/设定集', 'sort_order': 7},
      {'id': 'cd', 'name': 'CD/BD', 'sort_order': 8},
      {'id': 'other', 'name': '其他', 'sort_order': 99},
    ];
    for (final c in categories) {
      await db.insert('category', {...c, 'created_at': now});
    }
  }
}