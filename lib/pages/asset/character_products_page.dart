import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order_item.dart';
import '../../models/platform.dart';
import '../../database/dao/order_item_dao.dart';
import '../../database/dao/platform_dao.dart';
import '../order/order_item_detail_page.dart';

class CharacterProductsPage extends StatefulWidget {
  final String seriesId;
  final String seriesName;
  final String? characterId;
  final String? characterName;

  const CharacterProductsPage({
    super.key,
    required this.seriesId,
    required this.seriesName,
    this.characterId,
    this.characterName,
  });

  @override
  State<CharacterProductsPage> createState() => _CharacterProductsPageState();
}

class _CharacterProductsPageState extends State<CharacterProductsPage> {
  final _orderItemDao = OrderItemDao();
  final _platformDao = PlatformDao();

  List<OrderItem> _items = [];
  List<Platform> _platforms = [];
  String? _filterPlatform;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      List<OrderItem> items;
      if (widget.characterId != null) {
        items = await _orderItemDao.getByCharacterId(widget.characterId!);
      } else {
        items = await _orderItemDao.getBySeriesId(widget.seriesId);
      }
      final platforms = await _platformDao.getAll();
      setState(() {
        _items = items;
        _platforms = platforms;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<OrderItem> get _filteredItems {
    if (_filterPlatform == null) return _items;
    return _items.where((item) {
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.characterName ?? widget.seriesName;
    final totalSpent = _items.fold<double>(
        0, (sum, item) => sum + item.unitPrice * item.quantity);
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryCard(totalSpent, currencyFormat),
                _buildFilterBar(),
                Expanded(
                  child: _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                              const SizedBox(height: 16),
                              Text('暂无商品',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredItems.length,
                            itemBuilder: (_, i) => _buildProductCard(_filteredItems[i], currencyFormat),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(double totalSpent, NumberFormat currencyFormat) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.shopping_bag,
                  color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.characterName != null
                        ? '${widget.characterName} · ${widget.seriesName}'
                        : widget.seriesName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text('${_items.length}件商品 · ${_getPlatformCount()}个平台',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Text(currencyFormat.format(totalSpent),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.primary)),
          ],
        ),
      ),
    );
  }

  int _getPlatformCount() {
    final platformIds = <String>{};
    for (final item in _items) {
      platformIds.add(item.orderId);
    }
    return platformIds.length;
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: _filterPlatform,
              decoration: const InputDecoration(
                labelText: '平台筛选',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('全部平台')),
                ..._platforms.map(
                  (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                ),
              ],
              onChanged: (v) => setState(() => _filterPlatform = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(OrderItem item, NumberFormat currencyFormat) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderItemDetailPage(orderItemId: item.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: item.imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(item.imagePath!, fit: BoxFit.cover),
                      )
                    : Icon(Icons.image,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                    if (item.spec != null) ...[
                      const SizedBox(height: 2),
                      Text(item.spec!,
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(currencyFormat.format(item.unitPrice),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        if (item.quantity > 1) ...[
                          const SizedBox(width: 4),
                          Text('×${item.quantity}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.itemStatus != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(item.itemStatus!).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(item.itemStatus!,
                          style: TextStyle(fontSize: 10, color: _getStatusColor(item.itemStatus!))),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'paid':
        return Colors.blue;
      case 'shipped':
        return Colors.indigo;
      case 'received':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}