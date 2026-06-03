import 'package:flutter/material.dart';
import '../../services/search_service.dart';
import '../asset/character_list_page.dart';
import '../asset/character_products_page.dart';
import '../order/order_item_detail_page.dart';
import '../../theme/glass_container.dart';
import '../../database/dao/series_dao.dart';
import '../../database/dao/order_item_dao.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchService = SearchService();
  final _seriesDao = SeriesDao();
  final _orderItemDao = OrderItemDao();
  final _controller = TextEditingController();

  List<SearchResult> _results = [];
  bool _searching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() => _searching = true);
    try {
      final results = await _searchService.search(keyword);
      setState(() {
        _results = results;
        _searching = false;
        _hasSearched = true;
      });
    } catch (e) {
      setState(() {
        _searching = false;
        _hasSearched = true;
      });
    }
  }

  void _onResultTap(SearchResult result) async {
    if (result.type == 'series') {
      final series = await _seriesDao.getById(result.id);
      if (series != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CharacterListPage(series: series),
          ),
        );
      }
    } else if (result.type == 'character') {
      final items = await _orderItemDao.getByCharacterId(result.id);
      if (items.isNotEmpty && mounted) {
        final firstItem = items.first;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CharacterProductsPage(
              seriesId: firstItem.seriesId ?? '',
              seriesName: '',
              characterId: result.id,
              characterName: result.title,
            ),
          ),
        );
      }
    } else if (result.type == 'product') {
      final item = await _orderItemDao.getById(result.id);
      if (item != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderItemDetailPage(orderItemId: item.id),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索IP、角色或商品...',
            border: InputBorder.none,
          ),
          onSubmitted: _search,
          onChanged: (v) {
            if (v.isEmpty) {
              setState(() {
                _results = [];
                _hasSearched = false;
              });
            }
          },
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() {
                  _results = [];
                  _hasSearched = false;
                });
              },
            ),
        ],
      ),
      body: _searching
          ? const Center(child: CircularProgressIndicator())
          : _hasSearched && _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('未找到相关结果',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : _results.isEmpty
                  ? _buildSuggestions()
                  : _buildResults(),
    );
  }

  Widget _buildSuggestions() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('热门搜索',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            '原神', '初音未来', '明日方舟', '钟离', '手办', '谷子', 'B站会员购',
          ].map((keyword) {
            return ActionChip(
              label: Text(keyword),
              onPressed: () {
                _controller.text = keyword;
                _search(keyword);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final seriesResults = _results.where((r) => r.type == 'series').toList();
    final characterResults = _results.where((r) => r.type == 'character').toList();
    final productResults = _results.where((r) => r.type == 'product').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (seriesResults.isNotEmpty) ...[
          _buildSectionHeader('IP/系列', seriesResults.length),
          ...seriesResults.map(_buildSeriesResult),
          const SizedBox(height: 16),
        ],
        if (characterResults.isNotEmpty) ...[
          _buildSectionHeader('角色', characterResults.length),
          ...characterResults.map(_buildCharacterResult),
          const SizedBox(height: 16),
        ],
        if (productResults.isNotEmpty) ...[
          _buildSectionHeader('商品', productResults.length),
          ...productResults.map(_buildProductResult),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('$title ($count)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary)),
    );
  }

  Widget _buildSeriesResult(SearchResult result) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.auto_awesome,
              color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        title: Text(result.title),
        subtitle: Text(result.subtitle ?? '', style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _onResultTap(result),
      ),
    );
  }

  Widget _buildCharacterResult(SearchResult result) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Text(result.title.isNotEmpty ? result.title[0] : '?',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
        ),
        title: Text(result.title),
        subtitle: Text(result.subtitle ?? '', style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _onResultTap(result),
      ),
    );
  }

  Widget _buildProductResult(SearchResult result) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.shopping_bag,
              color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
        ),
        title: Text(result.title, style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          result.subtitle ?? '',
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => _onResultTap(result),
      ),
    );
  }
}