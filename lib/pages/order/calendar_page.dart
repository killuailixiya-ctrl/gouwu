import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/dao/order_dao.dart';
import '../../database/dao/order_item_dao.dart';
import '../../database/dao/series_dao.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/series.dart';
import 'order_detail_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _orderDao = OrderDao();
  final _orderItemDao = OrderItemDao();
  final _seriesDao = SeriesDao();

  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Map<DateTime, List<Order>> _orderMap = {};
  final Map<String, List<OrderItem>> _orderItemsMap = {};
  Map<String, Series> _seriesMap = {};
  Map<String, Color> _seriesColorMap = {};
  bool _loading = true;

  static const _seriesColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.red,
    Colors.brown,
    Colors.cyan,
    Colors.amber,
    Colors.deepOrange,
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final year = _currentMonth.year;
      final month = _currentMonth.month;

      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

      final orders = await _orderDao.getByDateRange(startDate, endDate);

      final orderMap = <DateTime, List<Order>>{};
      final allSeriesIds = <String>{};

      for (final order in orders) {
        final date = DateTime(order.orderTime.year, order.orderTime.month, order.orderTime.day);
        orderMap.putIfAbsent(date, () => []).add(order);

        final items = await _orderItemDao.getByOrderId(order.id);
        _orderItemsMap[order.id] = items;
        for (final item in items) {
          if (item.seriesId != null) allSeriesIds.add(item.seriesId!);
        }
      }

      final allSeries = await _seriesDao.getAll();
      final seriesMap = <String, Series>{};
      final seriesColorMap = <String, Color>{};
      var colorIndex = 0;

      for (final series in allSeries) {
        seriesMap[series.id] = series;
        if (allSeriesIds.contains(series.id) || colorIndex < allSeries.length) {
          seriesColorMap[series.id] = _seriesColors[colorIndex % _seriesColors.length];
          colorIndex++;
        }
      }

      for (final id in allSeriesIds) {
        seriesColorMap.putIfAbsent(id, () => _seriesColors[colorIndex++ % _seriesColors.length]);
      }

      setState(() {
        _orderMap = orderMap;
        _seriesMap = seriesMap;
        _seriesColorMap = seriesColorMap;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _previousMonth() {
    setState(() {
      if (_currentMonth.month == 1) {
        _currentMonth = DateTime(_currentMonth.year - 1, 12);
      } else {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      }
    });
    _loadData();
  }

  void _nextMonth() {
    setState(() {
      if (_currentMonth.month == 12) {
        _currentMonth = DateTime(_currentMonth.year + 1, 1);
      } else {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      }
    });
    _loadData();
  }

  Set<String> _getSeriesIdsForDate(DateTime date) {
    final orders = _orderMap[date] ?? [];
    final seriesIds = <String>{};
    for (final order in orders) {
      final items = _orderItemsMap[order.id] ?? [];
      for (final item in items) {
        if (item.seriesId != null) seriesIds.add(item.seriesId!);
      }
    }
    return seriesIds;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('购买日历'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildMonthHeader(),
                  const SizedBox(height: 16),
                  _buildCalendarGrid(),
                  const SizedBox(height: 20),
                  _buildLegend(),
                  const SizedBox(height: 16),
                  _buildMonthSummary(),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _previousMonth,
        ),
        Text(
          DateFormat('yyyy年 M月').format(_currentMonth),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _nextMonth,
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstDayOfWeek = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    final previousMonthDays = DateTime(_currentMonth.year, _currentMonth.month, 0).day;

    final weekHeaders = ['一', '二', '三', '四', '五', '六', '日'];

    final totalCells = <int>[];
    final startOffset = firstDayOfWeek - 1;
    for (int i = startOffset - 1; i >= 0; i--) {
      totalCells.add(-(previousMonthDays - i));
    }
    for (int i = 1; i <= daysInMonth; i++) {
      totalCells.add(i);
    }
    final remainingCells = (7 - (totalCells.length % 7)) % 7;
    for (int i = 1; i <= remainingCells; i++) {
      totalCells.add(-i);
    }

    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 0);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: weekHeaders.map((h) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(h,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14)),
                ),
              )).toList(),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.85,
            ),
            itemCount: totalCells.length,
            itemBuilder: (context, index) {
              final day = totalCells[index];
              final isCurrentMonth = day > 0;
              final today = DateTime.now();
              final currentDate = isCurrentMonth
                  ? DateTime(_currentMonth.year, _currentMonth.month, day)
                  : null;

              final isToday = currentDate != null &&
                  currentDate.year == today.year &&
                  currentDate.month == today.month &&
                  currentDate.day == today.day;

              final seriesIds = currentDate != null ? _getSeriesIdsForDate(currentDate) : <String>{};
              final orders = currentDate != null ? (_orderMap[currentDate] ?? []) : <Order>[];
              final totalAmount = orders.fold<double>(0, (sum, o) => sum + o.totalAmount);

              return InkWell(
                onTap: (currentDate != null && orders.isNotEmpty)
                    ? () => _showDayOrders(currentDate, orders)
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                      bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                    ),
                    color: isToday
                        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: [
                        Text(
                          day.abs().toString(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isCurrentMonth
                                ? (isToday
                                    ? Theme.of(context).colorScheme.primary
                                    : null)
                                : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (seriesIds.isNotEmpty && seriesIds.length <= 3)
                          Wrap(
                            spacing: 2,
                            runSpacing: 2,
                            children: seriesIds.map((sid) => Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _seriesColorMap[sid] ?? Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            )).toList(),
                          )
                        else if (seriesIds.length > 3)
                          Wrap(
                            spacing: 2,
                            runSpacing: 2,
                            children: [
                              ...seriesIds.take(2).map((sid) => Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _seriesColorMap[sid] ?? Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              )),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                                child: const Text('', style: TextStyle(fontSize: 8)),
                              ),
                            ],
                          ),
                        if (totalAmount > 0)
                          Text(
                            currencyFormat.format(totalAmount),
                            style: TextStyle(
                              fontSize: 9,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showDayOrders(DateTime date, List<Order> orders) {
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 0);
    final dateStr = DateFormat('yyyy年M月d日 EEEE', 'zh_CN').format(date);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(dateStr,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${orders.length}笔 · ${currencyFormat.format(orders.fold<double>(0, (s, o) => s + o.totalAmount))}',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: orders.length,
                  itemBuilder: (_, i) => _buildOrderCard(orders[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 0);
    final items = _orderItemsMap[order.id] ?? [];
    final itemNames = items.map((e) => e.name).take(2).join('、');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          Navigator.pop(context);
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: order.id)),
          );
          _loadData();
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (itemNames.isNotEmpty)
                      Text(itemNames,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(order.statusLabel,
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        const SizedBox(width: 8),
                        Text('${items.length}件',
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
              Text(currencyFormat.format(order.totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    if (_seriesColorMap.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('IP/系列',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: _seriesColorMap.entries.map((e) {
                final name = _seriesMap[e.key]?.name ?? e.key;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: e.value,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(name, style: const TextStyle(fontSize: 13)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSummary() {
    final totalOrders = _orderMap.values.fold<int>(0, (s, l) => s + l.length);
    final totalAmount = _orderMap.values.fold<double>(0, (s, orders) => s + orders.fold<double>(0, (s2, o) => s2 + o.totalAmount));
    final daysWithOrders = _orderMap.keys.length;
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_currentMonth.month}月统计',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatItem(Icons.shopping_bag, '$totalOrders笔', '订单'),
                const SizedBox(width: 24),
                _buildStatItem(Icons.calendar_today, '$daysWithOrders天', '购买日'),
                const SizedBox(width: 24),
                _buildStatItem(Icons.payments, currencyFormat.format(totalAmount), '总额'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}