import '../database/dao/series_dao.dart';
import '../database/dao/character_dao.dart';
import '../database/dao/order_item_dao.dart';

class SearchResult {
  final String type;
  final String id;
  final String title;
  final String? subtitle;
  final int? productCount;
  final String? platformName;
  final double? unitPrice;
  final String? imagePath;
  final String? orderTime;
  final String? itemStatus;

  SearchResult({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    this.productCount,
    this.platformName,
    this.unitPrice,
    this.imagePath,
    this.orderTime,
    this.itemStatus,
  });
}

class SearchService {
  final SeriesDao _seriesDao = SeriesDao();
  final CharacterDao _characterDao = CharacterDao();
  final OrderItemDao _orderItemDao = OrderItemDao();

  Future<List<SearchResult>> search(String keyword) async {
    if (keyword.trim().isEmpty) return [];

    final results = <SearchResult>[];

    final seriesList = await _seriesDao.search(keyword);
    for (final s in seriesList) {
      final stats = await _seriesDao.getStats(s.id);
      results.add(SearchResult(
        type: 'series',
        id: s.id,
        title: s.name,
        subtitle: '${stats['character_count']}个角色 · ${stats['product_count']}件商品',
        productCount: stats['product_count'] as int?,
      ));
    }

    final characters = await _characterDao.search(keyword);
    for (final c in characters) {
      final stats = await _characterDao.getStats(c.id);
      results.add(SearchResult(
        type: 'character',
        id: c.id,
        title: c.name,
        subtitle: '${stats['product_count']}件商品',
        productCount: stats['product_count'] as int?,
      ));
    }

    final items = await _orderItemDao.search(keyword);
    for (final item in items) {
      results.add(SearchResult(
        type: 'product',
        id: item.id,
        title: item.name,
        subtitle: '¥${item.unitPrice.toStringAsFixed(0)}',
        unitPrice: item.unitPrice,
        imagePath: item.imagePath,
        itemStatus: item.itemStatus,
      ));
    }

    return results;
  }

  Future<List<SearchResult>> searchWithDetails(String keyword) async {
    if (keyword.trim().isEmpty) return [];

    final rawResults = await _orderItemDao.searchAll(keyword);
    final results = <SearchResult>[];

    for (final row in rawResults) {
      results.add(SearchResult(
        type: row['result_type'] as String,
        id: row['id'] as String,
        title: row['name'] as String,
        subtitle: row['character_name'] as String?,
        productCount: row['product_count'] as int?,
        platformName: row['platform_name'] as String?,
        unitPrice: (row['unit_price'] as num?)?.toDouble(),
        imagePath: row['image_path'] as String?,
        orderTime: row['order_time'] as String?,
        itemStatus: row['item_status'] as String?,
      ));
    }

    return results;
  }
}