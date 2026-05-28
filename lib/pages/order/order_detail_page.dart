import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/platform.dart';
import '../../database/dao/order_dao.dart';
import '../../database/dao/order_item_dao.dart';
import '../../database/dao/platform_dao.dart';
import '../order/order_edit_page.dart';
import '../order/order_item_detail_page.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final _orderDao = OrderDao();
  final _orderItemDao = OrderItemDao();
  final _platformDao = PlatformDao();

  Order? _order;
  List<OrderItem> _items = [];
  Platform? _platform;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final order = await _orderDao.getById(widget.orderId);
      if (order != null) {
        final items = await _orderItemDao.getByOrderId(order.id);
        final platform = await _platformDao.getById(order.platformId);
        setState(() {
          _order = order;
          _items = items;
          _platform = platform;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后无法恢复，确定要删除此订单吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _orderDao.delete(widget.orderId);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('订单详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('订单详情')),
        body: const Center(child: Text('订单不存在')),
      );
    }

    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 0);
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(_order!.orderTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text('订单详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderEditPage(existingOrder: _order),
                ),
              );
              if (result == true) _loadData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _deleteOrder,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildOrderInfoCard(dateStr, currencyFormat),
          if (_order!.screenshotPath != null) ...[
            const SizedBox(height: 16),
            _buildScreenshotSection(),
          ],
          const SizedBox(height: 16),
          _buildItemsSection(currencyFormat),
          if (_order!.isPresell) ...[
            const SizedBox(height: 16),
            _buildPresellCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard(String dateStr, NumberFormat currencyFormat) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _parseColor(_platform?.colorCode ?? '#999').withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_platform?.name ?? '未知平台',
                      style: TextStyle(
                          color: _parseColor(_platform?.colorCode ?? '#999'),
                          fontWeight: FontWeight.w500)),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(),
              ],
            ),
            const SizedBox(height: 12),
            if (_order!.orderNo != null) ...[
              Text('订单号: ${_order!.orderNo}',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
            ],
            Text('下单时间: $dateStr',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('订单总额',
                    style: Theme.of(context).textTheme.bodyMedium),
                Text(currencyFormat.format(_order!.totalAmount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    switch (_order!.status) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'paid':
        color = Colors.blue;
        break;
      case 'shipped':
        color = Colors.indigo;
        break;
      case 'received':
        color = Colors.green;
        break;
      case 'completed':
        color = Colors.grey;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(_order!.statusLabel,
          style: TextStyle(fontSize: 12, color: color)),
    );
  }

  Widget _buildScreenshotSection() {
    final file = File(_order!.screenshotPath!);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('订单截图',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: file.existsSync()
                  ? Image.file(
                      file,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    )
                  : Container(
                      height: 120,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Text('截图文件已丢失',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection(NumberFormat currencyFormat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('商品明细 (${_items.length}件)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._items.map((item) => _buildItemCard(item, currencyFormat)),
      ],
    );
  }

  Widget _buildItemCard(OrderItem item, NumberFormat currencyFormat) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
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
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  if (item.spec != null) ...[
                    const SizedBox(height: 2),
                    Text(item.spec!,
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(currencyFormat.format(item.unitPrice),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('×${item.quantity}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
        ),
    );
  }

  Widget _buildPresellCard() {
    final deadline = _order!.balanceDeadline;
    final daysLeft = _order!.daysUntilBalanceDeadline;
    final isOverdue = _order!.isBalanceOverdue;

    return Card(
      color: isOverdue ? Colors.red.withValues(alpha: 0.05) : Colors.orange.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isOverdue ? Icons.warning : Icons.access_time,
              color: isOverdue ? Colors.red : Colors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('预售尾款',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isOverdue ? Colors.red : Colors.orange)),
                  const SizedBox(height: 4),
                  if (deadline != null)
                    Text(
                      isOverdue
                          ? '尾款已逾期（截止: ${DateFormat('MM/dd').format(deadline)}）'
                          : '尾款截止: ${DateFormat('yyyy-MM-dd').format(deadline)}（还剩$daysLeft天）',
                      style: const TextStyle(fontSize: 13),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}