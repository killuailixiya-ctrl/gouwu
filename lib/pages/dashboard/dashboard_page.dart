import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/dao/order_dao.dart';
import '../../database/dao/reminder_dao.dart';
import '../../database/dao/platform_dao.dart';
import '../../database/dao/series_dao.dart';
import '../../models/order.dart';
import '../../models/reminder.dart';
import '../../models/platform.dart';
import '../../models/series.dart';
import '../order/order_edit_page.dart';
import '../order/order_detail_page.dart';
import '../order/screenshot_import_page.dart';
import '../order/calendar_page.dart';
import '../search/search_page.dart';
import '../asset/character_products_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final OrderDao _orderDao = OrderDao();
  final ReminderDao _reminderDao = ReminderDao();
  final PlatformDao _platformDao = PlatformDao();
  final SeriesDao _seriesDao = SeriesDao();

  List<Reminder> _activeReminders = [];
  List<Order> _recentOrders = [];
  List<Platform> _platforms = [];
  List<Series> _topSeries = [];
  double _monthlyTotal = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final reminders = await _reminderDao.getUpcoming(days: 30);
      final orders = await _orderDao.getRecentOrders(limit: 5);
      final platforms = await _platformDao.getAll();
      final allSeries = await _seriesDao.getAll();
      final now = DateTime.now();
      final monthlyTotal =
          await _orderDao.getMonthlyTotal(now.year, now.month);

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
        _platforms = platforms;
        _topSeries = seriesWithCounts.take(6).map((e) => e.key).toList();
        _monthlyTotal = monthlyTotal;
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
                padding: const EdgeInsets.all(16),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
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
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderSection() {
    if (_activeReminders.isEmpty) return const SizedBox.shrink();

    final urgent = _activeReminders
        .where((r) => r.urgencyLevel >= 3)
        .toList();
    final normal = _activeReminders
        .where((r) => r.urgencyLevel < 3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
        const SizedBox(height: 8),
        ...urgent.map(_buildReminderCard),
        ...normal.map(_buildReminderCard),
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
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            reminder.type == 'balance' ? Icons.payment : Icons.local_shipping,
            color: color,
            size: 20,
          ),
        ),
        title: Text(reminder.message ?? reminder.typeLabel,
            style: const TextStyle(fontSize: 14)),
        subtitle: Text(dateStr, style: const TextStyle(fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.check_circle_outline, size: 20),
          onPressed: () async {
            await _reminderDao.dismiss(reminder.id);
            _loadData();
          },
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            icon: Icons.add_shopping_cart,
            label: '手动录入',
            color: Theme.of(context).colorScheme.primary,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrderEditPage()),
              );
              if (result == true) _loadData();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            icon: Icons.photo_camera,
            label: '截图导入',
            color: Colors.green,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
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
    );
  }

  Widget _buildTopSeries() {
    if (_topSeries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('热门IP',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
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
        Text('最近订单',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._recentOrders.map(_buildOrderCard),
      ],
    );
  }

  Widget _buildOrderCard(Order order) {
    final platform = _platforms.where((p) => p.id == order.platformId).firstOrNull;
    final dateStr = DateFormat('MM/dd').format(order.orderTime);
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailPage(orderId: order.id),
            ),
          );
          _loadData();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _parseColor(platform?.colorCode ?? '#999').withValues(alpha: 0.1),
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
      child: Text(order.statusLabel,
          style: TextStyle(fontSize: 10, color: color)),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}