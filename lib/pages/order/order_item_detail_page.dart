import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/order_item.dart';
import '../../models/order.dart';
import '../../models/series.dart';
import '../../models/character.dart';
import '../../models/category.dart';
import '../../models/platform.dart';
import '../../database/dao/order_item_dao.dart';
import '../../database/dao/order_dao.dart';
import '../../database/dao/series_dao.dart';
import '../../database/dao/character_dao.dart';
import '../../database/dao/category_dao.dart';
import '../../database/dao/platform_dao.dart';
import 'order_detail_page.dart';

class OrderItemDetailPage extends StatefulWidget {
  final String orderItemId;

  const OrderItemDetailPage({super.key, required this.orderItemId});

  @override
  State<OrderItemDetailPage> createState() => _OrderItemDetailPageState();
}

class _OrderItemDetailPageState extends State<OrderItemDetailPage> {
  final _orderItemDao = OrderItemDao();
  final _orderDao = OrderDao();
  final _seriesDao = SeriesDao();
  final _characterDao = CharacterDao();
  final _categoryDao = CategoryDao();
  final _platformDao = PlatformDao();

  OrderItem? _item;
  Order? _order;
  Series? _series;
  Character? _character;
  Category? _category;
  Platform? _platform;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final item = await _orderItemDao.getById(widget.orderItemId);
    if (item == null) {
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }

    final order = await _orderDao.getById(item.orderId);
    Series? series;
    Character? character;
    Category? category;
    Platform? platform;

    if (item.seriesId != null) {
      series = await _seriesDao.getById(item.seriesId!);
    }
    if (item.characterId != null) {
      character = await _characterDao.getById(item.characterId!);
    }
    if (item.categoryId != null) {
      category = await _categoryDao.getById(item.categoryId!);
    }
    if (order != null) {
      platform = await _platformDao.getById(order.platformId);
    }

    if (mounted) {
      setState(() {
        _item = item;
        _order = order;
        _series = series;
        _character = character;
        _category = category;
        _platform = platform;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 0);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('商品详情'),
        actions: [
          if (_order != null)
            IconButton(
              icon: const Icon(Icons.receipt_long),
              tooltip: '查看订单',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailPage(orderId: _order!.id),
                  ),
                );
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildImageCard(colorScheme),
                  const SizedBox(height: 16),
                  _buildBasicInfoCard(currencyFormat, colorScheme),
                  const SizedBox(height: 16),
                  if (_series != null || _character != null || _category != null)
                    _buildAttributionCard(colorScheme),
                  if (_sourceText != null) ...[
                    const SizedBox(height: 16),
                    _buildSourceTextCard(colorScheme),
                  ],
                  if (_order != null) ...[
                    const SizedBox(height: 16),
                    _buildOrderCard(currencyFormat, colorScheme),
                  ],
                ],
              ),
            ),
    );
  }

  String? get _sourceText {
    if (_item?.sourceText == null || _item!.sourceText!.trim().isEmpty) {
      return null;
    }
    return _item!.sourceText;
  }

  Widget _buildImageCard(ColorScheme colorScheme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: _item!.imagePath != null
            ? Image.asset(
                _item!.imagePath!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _buildImagePlaceholder(colorScheme),
              )
            : _buildImagePlaceholder(colorScheme),
      ),
    );
  }

  Widget _buildImagePlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image,
          size: 48,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard(NumberFormat currencyFormat, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _item!.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_item!.spec != null) ...[
              const SizedBox(height: 8),
              Text(
                _item!.spec!,
                style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
              ),
            ],
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile('单价', currencyFormat.format(_item!.unitPrice)),
                ),
                Expanded(
                  child: _buildInfoTile('数量', '×${_item!.quantity}'),
                ),
                Expanded(
                  child: _buildInfoTile('小计', currencyFormat.format(_item!.totalPrice)),
                ),
              ],
            ),
            if (_item!.itemStatus != null) ...[
              const Divider(height: 24),
              _buildInfoTile('状态', _item!.itemStatus!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttributionCard(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '归属信息',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_series != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text('IP/系列: '),
                    Text(_series!.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            if (_character != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text('角色: '),
                    Text(_character!.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            if (_category != null)
              Row(
                children: [
                  Icon(Icons.category, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('品类: '),
                  Text(_category!.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceTextCard(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '原始文本',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _sourceText!,
                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(NumberFormat currencyFormat, ColorScheme colorScheme) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailPage(orderId: _order!.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '所属订单',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.receipt, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _platform?.name ?? '未知平台',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (_order!.orderNo != null)
                          Text(
                            _order!.orderNo!,
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(_order!.orderTime),
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    currencyFormat.format(_order!.totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.navigate_next,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}