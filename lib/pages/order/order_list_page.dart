import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/platform.dart';
import '../../database/dao/order_dao.dart';
import '../../database/dao/order_item_dao.dart';
import '../../database/dao/platform_dao.dart';
import 'order_detail_page.dart';
import 'order_edit_page.dart';

class OrderListPage extends StatefulWidget {
  const OrderListPage({super.key});

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> {
  final _orderDao = OrderDao();
  final _platformDao = PlatformDao();
  final _orderItemDao = OrderItemDao();

  List<Order> _orders = [];
  List<Platform> _platforms = [];
  Map<String, List<OrderItem>> _orderItems = {};
  String? _filterStatus;
  String? _filterPlatform;
  bool _loading = true;
  bool _selectMode = false;
  final Set<String> _selectedOrderIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final orders = await _orderDao.getAll(
        status: _filterStatus,
        platformId: _filterPlatform,
      );
      debugPrint('========== [LOAD] 开始加载订单列表 ==========');
      debugPrint('[LOAD] orders.length = ${orders.length}');
      final platforms = await _platformDao.getAll();
      final itemsMap = <String, List<OrderItem>>{};
      for (final order in orders) {
        itemsMap[order.id] = await _orderItemDao.getByOrderId(order.id);
        debugPrint('[LOAD] orderId=${order.id} items=${itemsMap[order.id]!.length}');
        for (final item in itemsMap[order.id]!) {
          debugPrint('[LOAD]   item: id=${item.id} orderId=${item.orderId} name=${item.name}');
        }
      }
      debugPrint('========== [LOAD] 加载完成 ==========');
      setState(() {
        _orders = orders;
        _platforms = platforms;
        _orderItems = itemsMap;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _selectMode
            ? Text('已选择 ${_selectedOrderIds.length} 项')
            : const Text('订单管理'),
        actions: [
          if (_orders.isNotEmpty)
            IconButton(
              icon: Icon(_selectMode ? Icons.close : Icons.checklist),
              tooltip: _selectMode ? '取消选择' : '批量选择',
              onPressed: () {
                setState(() {
                  _selectMode = !_selectMode;
                  if (!_selectMode) _selectedOrderIds.clear();
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_selectMode) _buildFilterBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long,
                                size: 64,
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text('暂无订单',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
                          itemCount: _orders.length,
                          itemBuilder: (_, i) => _buildOrderCard(_orders[i]),
                        ),
                      ),
          ),
          if (_selectMode) _buildBatchActionBar(),
        ],
      ),
      floatingActionButton: _selectMode
          ? null
          : FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrderEditPage()),
                );
                if (result == true) _loadData();
              },
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildBatchActionBar() {
    final allSelected = _selectedOrderIds.length == _orders.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            TextButton.icon(
              icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
              label: Text(allSelected ? '取消全选' : '全选'),
              onPressed: () {
                setState(() {
                  if (allSelected) {
                    _selectedOrderIds.clear();
                  } else {
                    _selectedOrderIds.addAll(_orders.map((o) => o.id));
                  }
                });
              },
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('删除', style: TextStyle(color: Colors.red)),
              onPressed: _selectedOrderIds.isEmpty ? null : _deleteSelected,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('确定要删除选中的 ${_selectedOrderIds.length} 个订单吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      for (final id in _selectedOrderIds) {
        await _orderDao.delete(id);
      }
      _selectedOrderIds.clear();
      _selectMode = false;
      _loadData();
    }
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: _filterStatus,
              decoration: const InputDecoration(
                labelText: '状态',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('全部状态')),
                ...Order.statusLabels.entries.map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                ),
              ],
              onChanged: (v) {
                _filterStatus = v;
                _loadData();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: _filterPlatform,
              decoration: const InputDecoration(
                labelText: '平台',
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
              onChanged: (v) {
                _filterPlatform = v;
                _loadData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final platform = _platforms.where((p) => p.id == order.platformId).firstOrNull;
    final dateStr = DateFormat('MM/dd').format(order.orderTime);
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 0);
    final items = _orderItems[order.id] ?? [];
    final itemNames = items.map((e) => e.name).take(3).join('、');
    final hasImage = items.isNotEmpty && items.first.imagePath != null;
    final isSelected = _selectedOrderIds.contains(order.id);

    Widget cardContent = Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: () async {
          if (_selectMode) {
            setState(() {
              if (isSelected) {
                _selectedOrderIds.remove(order.id);
              } else {
                _selectedOrderIds.add(order.id);
              }
            });
          } else {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailPage(orderId: order.id),
              ),
            );
            _loadData();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (_selectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedOrderIds.add(order.id);
                        } else {
                          _selectedOrderIds.remove(order.id);
                        }
                      });
                    },
                  ),
                ),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: hasImage
                    ? Image.file(
                        File(items.first.imagePath!),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 56,
                          height: 56,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(Icons.image, size: 24,
                              color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.shopping_bag, size: 24,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (itemNames.isNotEmpty)
                      Text(itemNames,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _parseColor(platform?.colorCode ?? '#999').withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(platform?.name ?? '未知',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: _parseColor(platform?.colorCode ?? '#999'),
                                  fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(width: 8),
                        Text(dateStr,
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        if (items.length > 1) ...[
                          const SizedBox(width: 8),
                          Text('等${items.length}件',
                              style: TextStyle(
                                  fontSize: 11,
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
                  Text(currencyFormat.format(order.totalAmount),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  _buildStatusChip(order),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (_selectMode) {
      return cardContent;
    }

    return Dismissible(
      key: Key(order.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定要删除此订单吗？\n${itemNames.isNotEmpty ? itemNames : "无商品"}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) async {
        await _orderDao.delete(order.id);
        setState(() {
          _orders.removeWhere((o) => o.id == order.id);
          _orderItems.remove(order.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已删除订单「${itemNames.isNotEmpty ? itemNames : "无商品"}」'),
              action: SnackBarAction(
                label: '撤销',
                onPressed: () async {
                  await _orderDao.insert(order);
                  for (final item in items) {
                    await _orderItemDao.insert(item);
                  }
                  _loadData();
                },
              ),
            ),
          );
        }
      },
      child: cardContent,
    );
  }

  Widget _buildStatusChip(Order order) {
    Color color;
    switch (order.status) {
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
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(order.statusLabel, style: TextStyle(fontSize: 10, color: color)),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}