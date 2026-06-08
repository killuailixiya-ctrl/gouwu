import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/dao/order_dao.dart';
import '../../database/dao/order_item_dao.dart';
import '../../database/dao/reminder_dao.dart';
import '../../database/dao/platform_dao.dart';
import '../../database/dao/series_dao.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/reminder.dart';
import '../../models/platform.dart';
import '../../models/series.dart';
import '../order/order_detail_page.dart';
import '../order/order_edit_page.dart';
import '../order/screenshot_import_page.dart';
import '../order/calendar_page.dart';
import '../search/search_page.dart';
import '../asset/character_products_page.dart';

class DashboardPage extends StatefulWidget {
  final ValueNotifier<int>? refreshNotifier;

  const DashboardPage({super.key, this.refreshNotifier});

  @override
  DashboardPageState createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  final OrderDao _orderDao = OrderDao();
  final OrderItemDao _orderItemDao = OrderItemDao();
  final ReminderDao _reminderDao = ReminderDao();
  final PlatformDao _platformDao = PlatformDao();
  final SeriesDao _seriesDao = SeriesDao();

  List<Reminder> _activeReminders = [];
  List<Order> _recentOrders = [];
  Map<String, List<OrderItem>> _orderItemsMap = {};
  List<Platform> _platforms = [];
  List<Series> _topSeries = [];
  double _monthlyTotal = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.refreshNotifier?.addListener(_onRefresh);
    _loadData();
  }

  void _onRefresh() => _loadData();

  void refresh() => _loadData();

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_onRefresh);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      print('[Dashboard] _loadData called');
      final reminders = await _reminderDao.getUpcoming(days: 30);
      final orders = await _orderDao.getRecentOrders(limit: 5);
      print('[Dashboard] _loadData: got ${orders.length} orders');
      final orderItemsMap = <String, List<OrderItem>>{};
      for (final order in orders) {
        final items = await _orderItemDao.getByOrderId(order.id);
        orderItemsMap[order.id] = items;
        print('[Dashboard] _loadData: order ${order.id} has ${items.length} items');
      }
      final platforms = await _platformDao.getAll();
      final allSeries = await _seriesDao.getAll();
      final now = DateTime.now();
      final monthlyTotal = await _orderDao.getMonthlyTotal(now.year, now.month);

      final seriesWithCounts = <MapEntry<Series, int>>[];
      for (final s in allSeries) {
        final stats = await _seriesDao.getStats(s.id);
        final count = stats['product_count'] as int? ?? 0;
        if (count > 0) seriesWithCounts.add(MapEntry(s, count));
      }
      seriesWithCounts.sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _activeReminders = reminders;
        _recentOrders = orders;
        _orderItemsMap = orderItemsMap;
        _platforms = platforms;
        _topSeries = seriesWithCounts.take(6).map((e) => e.key).toList();
        _monthlyTotal = monthlyTotal;
        _loading = false;
      });
    } catch (e, stack) {
      print('[Dashboard] _loadData error: $e\n$stack');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('购物'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchPage()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  _buildMonthlyOverview(),
                  const SizedBox(height: 16),
                  _buildReminderSection(),
                  const SizedBox(height: 16),
                  _buildQuickActions(),
                  const SizedBox(height: 16),
                  _buildTopSeries(),
                  const SizedBox(height: 16),
                  _buildRecentOrders(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OrderEditPage()),
          );
          if (result == true) _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('录入订单'),
      ),
    );
  }

  Widget _buildMonthlyOverview() {
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 0);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.account_balance_wallet,
                color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('本月消费',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(currencyFormat.format(_monthlyTotal),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const Spacer(),
          Text(
            '${_recentOrders.length}笔订单',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildReminderSection() {
    if (_activeReminders.isEmpty) return const SizedBox.shrink();

    final urgent = _activeReminders.where((r) => r.urgencyLevel >= 3).toList();
    final normal = _activeReminders.where((r) => r.urgencyLevel < 3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.notifications_active, size: 20, color: Colors.orange),
              const SizedBox(width: 8),
              Text('待处理提醒',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${_activeReminders.length}条',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        ...urgent.map((e) => _buildReminderCard(e)),
        ...normal.map((e) => _buildReminderCard(e)),
      ],
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    final colors = {
      4: Colors.red,
      3: Colors.orange,
      2: Colors.amber,
      1: Colors.blue,
    };
    final color = colors[reminder.urgencyLevel] ?? Colors.grey;
    final dateStr = DateFormat('MM/dd HH:mm').format(reminder.remindAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await _reminderDao.dismiss(reminder.id);
          _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              reminder.type == 'balance' ? Icons.payment : Icons.local_shipping,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reminder.message ?? reminder.typeLabel,
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 2),
                Text(dateStr, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline, size: 20),
            onPressed: () async {
              await _reminderDao.dismiss(reminder.id);
              _loadData();
            },
          ),
        ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            icon: Icons.edit_note,
            label: '手动录入',
            color: Theme.of(context).colorScheme.primary,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrderEditPage()),
              );
              _loadData();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            icon: Icons.document_scanner,
            label: '截图导入',
            color: Colors.teal,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScreenshotImportPage()),
              );
              _loadData();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            icon: Icons.calendar_month,
            label: '购买日历',
            color: Colors.orange,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CalendarPage()),
              );
              _loadData();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(fontSize: 12, color: color),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopSeries() {
    if (_topSeries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('热门IP',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _topSeries.map((s) {
            return ActionChip(
              avatar: const Icon(Icons.auto_awesome, size: 16),
              label: Text(s.name),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CharacterProductsPage(
                      seriesId: s.id,
                      seriesName: s.name,
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRecentOrders() {
    if (_recentOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text('还没有订单记录',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Text('点击右下角按钮录入第一笔订单吧',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('最近订单',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
        ..._recentOrders.map((e) => _buildOrderCard(e)),
      ],
    );
  }

  Widget _buildOrderCard(Order order) {
    final platform =
        _platforms.where((p) => p.id == order.platformId).firstOrNull;
    final dateStr = DateFormat('MM/dd').format(order.orderTime);
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 0);
    final items = _orderItemsMap[order.id] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailPage(orderId: order.id),
            ),
          );
          _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _parseColor(platform?.colorCode ?? '#999')
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(platform?.name ?? '未知',
                    style: TextStyle(
                        fontSize: 12,
                        color: _parseColor(platform?.colorCode ?? '#999'),
                        fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.orderNo ?? '无订单号',
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(dateStr,
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(currencyFormat.format(order.totalAmount),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  _buildStatusChip(order),
                ],
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: items.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${item.name}${item.spec != null && item.spec!.isNotEmpty ? " (${item.spec})" : ""} x${item.quantity}',
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    ),
    ),
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
      case 'completed':
        color = Colors.grey;
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
      child: Text(
        Order.statusLabels[order.status] ?? order.status,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}