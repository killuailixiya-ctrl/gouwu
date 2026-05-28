import 'package:sqflite/sqflite.dart';
import 'memory_store.dart';

class MemoryDatabase implements Database {
  final MemoryStore _store;

  MemoryDatabase([MemoryStore? store]) : _store = store ?? MemoryStore();

  @override
  String get path => ':memory:';

  @override
  bool get isOpen => true;

  @override
  Database get database => this;

  @override
  Future<void> close() async {}

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action, {bool? exclusive}) async {
    return action(_MemoryTransaction(_store));
  }

  @override
  Future<T> readTransaction<T>(Future<T> Function(Transaction txn) action) async {
    return action(_MemoryTransaction(_store));
  }

  @override
  Future<T> devInvokeMethod<T>(String method, [Object? arguments]) async {
    throw UnimplementedError();
  }

  @override
  Future<T> devInvokeSqlMethod<T>(String method, String sql, [List<Object?>? arguments]) async {
    throw UnimplementedError();
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {}

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    return 0;
  }

  @override
  Future<int> insert(String table, Map<String, Object?> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) {
    return _store.insert(table, values);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    return _store.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit);
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) {
    return _store.rawQuery(sql, arguments);
  }

  @override
  Future<QueryCursor> rawQueryCursor(String sql, List<Object?>? arguments, {int? bufferSize}) async {
    throw UnimplementedError();
  }

  @override
  Future<QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    return 0;
  }

  @override
  Future<int> update(String table, Map<String, Object?> values, {String? where, List<Object?>? whereArgs, ConflictAlgorithm? conflictAlgorithm}) {
    return _store.update(table, values, where: where, whereArgs: whereArgs);
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    return 0;
  }

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) {
    return _store.delete(table, where: where, whereArgs: whereArgs);
  }

  @override
  Batch batch() {
    return _MemoryBatch(_store);
  }
}

class _MemoryTransaction extends MemoryDatabase implements Transaction {
  _MemoryTransaction(super.store);
}

class _MemoryBatch implements Batch {
  final MemoryStore _store;
  final List<_BatchOp> _ops = [];

  _MemoryBatch(this._store);

  @override
  int get length => _ops.length;

  @override
  void insert(String table, Map<String, Object?> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) {
    _ops.add(_BatchOp('insert', table, values: values));
  }

  @override
  void update(String table, Map<String, Object?> values, {String? where, List<Object?>? whereArgs, ConflictAlgorithm? conflictAlgorithm}) {
    _ops.add(_BatchOp('update', table, values: values, where: where, whereArgs: whereArgs));
  }

  @override
  void delete(String table, {String? where, List<Object?>? whereArgs}) {
    _ops.add(_BatchOp('delete', table, where: where, whereArgs: whereArgs));
  }

  @override
  void execute(String sql, [List<Object?>? arguments]) {}

  @override
  void rawInsert(String sql, [List<Object?>? arguments]) {}

  @override
  void rawUpdate(String sql, [List<Object?>? arguments]) {}

  @override
  void rawDelete(String sql, [List<Object?>? arguments]) {}

  @override
  void rawQuery(String sql, [List<Object?>? arguments]) {}

  @override
  void query(String table, {bool? distinct, List<String>? columns, String? where, List<Object?>? whereArgs, String? groupBy, String? having, String? orderBy, int? limit, int? offset}) {}

  @override
  Future<List<Object?>> apply({bool? continueOnError, bool? noResult}) async {
    for (final op in _ops) {
      await op.execute(_store);
    }
    return [];
  }

  @override
  Future<List<Object?>> commit({bool? noResult, bool? exclusive, bool? continueOnError}) async {
    for (final op in _ops) {
      await op.execute(_store);
    }
    return [];
  }
}

class _BatchOp {
  final String type;
  final String table;
  final Map<String, dynamic>? values;
  final String? where;
  final List<dynamic>? whereArgs;

  _BatchOp(this.type, this.table, {this.values, this.where, this.whereArgs});

  Future<void> execute(MemoryStore store) async {
    switch (type) {
      case 'insert':
        await store.insert(table, values!);
        break;
      case 'update':
        await store.update(table, values!, where: where, whereArgs: whereArgs);
        break;
      case 'delete':
        await store.delete(table, where: where, whereArgs: whereArgs);
        break;
    }
  }
}