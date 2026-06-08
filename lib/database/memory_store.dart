class MemoryStore {
  static final MemoryStore _instance = MemoryStore._();
  factory MemoryStore() => _instance;
  MemoryStore._();

  final Map<String, List<Map<String, dynamic>>> _tables = {};

  List<Map<String, dynamic>> _getTable(String table) {
    return _tables.putIfAbsent(table, () => []);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    var rows = _getTable(table).map((row) => Map<String, dynamic>.from(row)).toList();

    if (where != null) {
      rows = _applyWhere(rows, where, whereArgs ?? []);
    }

    if (orderBy != null) {
      final parts = orderBy.split(' ');
      final col = parts[0].replaceAll('"', '');
      final asc = parts.length < 2 || parts[1].toUpperCase() != 'DESC';
      rows.sort((a, b) {
        final va = a[col];
        final vb = b[col];
        if (va == null && vb == null) return 0;
        if (va == null) return asc ? -1 : 1;
        if (vb == null) return asc ? 1 : -1;
        final cmp = Comparable.compare(va, vb);
        return asc ? cmp : -cmp;
      });
    }

    if (limit != null && limit < rows.length) {
      rows = rows.sublist(0, limit);
    }

    return rows;
  }

  List<Map<String, dynamic>> _applyWhere(
    List<Map<String, dynamic>> rows,
    String where,
    List<dynamic> whereArgs,
  ) {
    final conditions = where.split(' AND ');
    return rows.where((row) {
      var usedArgCount = 0;
      for (final condition in conditions) {
        final trimmed = condition.trim();
        if (!_evalCondition(row, trimmed, whereArgs, usedArgCount)) {
          return false;
        }
        if (_conditionUsesArg(trimmed)) {
          usedArgCount++;
        }
      }
      return true;
    }).toList();
  }

  bool _conditionUsesArg(String condition) {
    final parts = _splitCondition(condition);
    if (parts.length >= 3 && parts[2] == 'NOT') {
      return false;
    }
    return parts.length >= 3 && parts[2] == '?';
  }

  bool _evalCondition(
    Map<String, dynamic> row,
    String condition,
    List<dynamic> whereArgs,
    int argIndex,
  ) {
    final parts = _splitCondition(condition);
    if (parts.length < 2) return true;

    final col = parts[0].replaceAll('"', '');

    if (parts.length >= 3 && parts[1] == 'IS' && parts[2] == 'NOT' && parts.length >= 4 && parts[3] == 'NULL') {
      return row[col] != null;
    }
    if (parts.length >= 3 && parts[1] == 'IS' && parts[2] == 'NULL') {
      return row[col] == null;
    }

    if (parts.length < 3) return true;

    final op = parts[1];
    final placeholder = parts[2];

    if (placeholder != '?') return true;

    if (argIndex >= whereArgs.length) return true;

    final value = row[col];
    final arg = whereArgs[argIndex];

    switch (op) {
      case '=':
        return value == arg;
      case '!=':
        return value != arg;
      case '>':
        if (value is Comparable && arg is Comparable) {
          return value.compareTo(arg) > 0;
        }
        return false;
      case '<':
        if (value is Comparable && arg is Comparable) {
          return value.compareTo(arg) < 0;
        }
        return false;
      case '>=':
        if (value is Comparable && arg is Comparable) {
          return value.compareTo(arg) >= 0;
        }
        return false;
      case '<=':
        if (value is Comparable && arg is Comparable) {
          return value.compareTo(arg) <= 0;
        }
        return false;
      case 'LIKE':
        if (value is String && arg is String) {
          final pattern = arg.replaceAll('%', '.*').replaceAll('_', '.');
          return RegExp('^$pattern\$', caseSensitive: false).hasMatch(value);
        }
        return false;
      default:
        return true;
    }
  }

  List<String> _splitCondition(String condition) {
    final parts = <String>[];
    final buffer = StringBuffer();
    for (int i = 0; i < condition.length; i++) {
      final c = condition[i];
      if (c == ' ') {
        if (buffer.isNotEmpty) {
          parts.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(c);
      }
    }
    if (buffer.isNotEmpty) parts.add(buffer.toString());
    return parts;
  }

  Future<int> insert(String table, Map<String, dynamic> values) async {
    final rows = _getTable(table);
    final id = values['id'] as String?;
    if (id != null) {
      final existingIndex = rows.indexWhere((r) => r['id'] == id);
      if (existingIndex >= 0) {
        rows[existingIndex] = Map<String, dynamic>.from(values);
        return 1;
      }
    }
    rows.add(Map<String, dynamic>.from(values));
    return 1;
  }

  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final rows = _getTable(table);
    int count = 0;
    for (int i = 0; i < rows.length; i++) {
      if (where == null || _matchesWhere(rows[i], where, whereArgs ?? [])) {
        rows[i] = {...rows[i], ...values};
        count++;
      }
    }
    return count;
  }

  bool _matchesWhere(
    Map<String, dynamic> row,
    String where,
    List<dynamic> whereArgs,
  ) {
    return _evalCondition(row, where, whereArgs, 0);
  }

  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final rows = _getTable(table);
    if (where == null) {
      final count = rows.length;
      rows.clear();
      return count;
    }
    final toRemove = <int>[];
    for (int i = 0; i < rows.length; i++) {
      if (_matchesWhere(rows[i], where, whereArgs ?? [])) {
        toRemove.add(i);
      }
    }
    for (final i in toRemove.reversed) {
      rows.removeAt(i);
    }
    return toRemove.length;
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? args,
  ]) async {
    return [];
  }

  void clear() {
    _tables.clear();
  }
}