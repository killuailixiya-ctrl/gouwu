import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/dao/order_dao.dart';
import '../../database/dao/order_item_dao.dart';
import '../../database/dao/series_dao.dart';
import '../../database/dao/category_dao.dart';
import '../../models/series.dart';
import '../../models/category.dart';
import '../../theme/glass_container.dart';
import '../../theme/app_animations.dart';
import '../settings/category_manage_page.dart';
import '../settings/platform_manage_page.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final _orderDao = OrderDao();
  final _orderItemDao = OrderItemDao();
  final _seriesDao = SeriesDao();
  final _categoryDao = CategoryDao();

  double _monthlyTotal = 0;
  Map<String, double> _platformSpending = {};
  List<MapEntry<Series, double>> _seriesSpending = [];
  List<MapEntry<Category, double>> _categorySpending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final monthlyTotal = await _orderDao.getMonthlyTotal(now.year, now.month);
      final platformSpending = await _orderDao.getPlatformSpending();

      final allSeries = await _seriesDao.getAll();
      final seriesSpending = <MapEntry<Series, double>>[];
      for (final s in allSeries) {
        final stats = await _seriesDao.getStats(s.id);
        final spent = (stats['total_spent'] as num?)?.toDouble() ?? 0;
        if (spent > 0) {
          seriesSpending.add(MapEntry(s, spent));
        }
      }
      seriesSpending.sort((a, b) => b.value.compareTo(a.value));

      final allCategories = await _categoryDao.getAll();
      final categorySpendingMap = await _orderItemDao.getCategorySpending();
      final categorySpending = <MapEntry<Category, double>>[];
      for (final c in allCategories) {
        final spent = categorySpendingMap[c.id] ?? 0;
        categorySpending.add(MapEntry(c, spent));
      }
      categorySpending.sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _monthlyTotal = monthlyTotal;
        _platformSpending = platformSpending;
        _seriesSpending = seriesSpending;
        _categorySpending = categorySpending;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('消费统计'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlatformManagePage()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  AppAnimations.scaleFadeIn(_buildMonthlyCard(currencyFormat)),
                  const SizedBox(height: 16),
                  _buildPlatformChart(),
                  const SizedBox(height: 16),
                  _buildSeriesSpending(currencyFormat),
                  const SizedBox(height: 16),
                  _buildCategorySpending(currencyFormat),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthlyCard(NumberFormat currencyFormat) {
    final now = DateTime.now();
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('${now.year}年${now.month}月',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(currencyFormat.format(_monthlyTotal),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 4),
          Text('本月消费总额',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildPlatformChart() {
    if (_platformSpending.isEmpty) return const SizedBox.shrink();

    final total = _platformSpending.values.fold<double>(0, (a, b) => a + b);
    final entries = _platformSpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final platformColors = {
      '淘宝': const Color(0xFFFF5000),
      '拼多多': const Color(0xFFE02E24),
      'B站会员购': const Color(0xFFFB7299),
      '闲鱼': const Color(0xFFFFC300),
      '微店': const Color(0xFF07C160),
      '京东': const Color(0xFFC91623),
    };

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('平台消费分布',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...entries.map((entry) {
            final pct = total > 0 ? entry.value / total : 0.0;
            final color = platformColors[entry.key] ?? Colors.grey;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(entry.key,
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      Text(
                        '¥${entry.value.toStringAsFixed(0)} (${(pct * 100).toStringAsFixed(0)}%)',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: pct),
                      duration: AppAnimations.medium,
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return LinearProgressIndicator(
                          value: value,
                          backgroundColor: color.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation(color),
                          minHeight: 6,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSeriesSpending(NumberFormat currencyFormat) {
    if (_seriesSpending.isEmpty) return const SizedBox.shrink();

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('IP消费排行',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._seriesSpending.take(10).toList().asMap().entries.map((e) {
            final entry = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                          entry.key.name.isNotEmpty
                              ? entry.key.name[0]
                              : '?',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(entry.key.name,
                        style: const TextStyle(fontSize: 14)),
                  ),
                  Text(currencyFormat.format(entry.value),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategorySpending(NumberFormat currencyFormat) {
    if (_categorySpending.isEmpty) return const SizedBox.shrink();

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('品类分布',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CategoryManagePage()),
                  );
                  _loadData();
                },
                child: const Text('管理'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categorySpending.map((entry) {
              return Chip(
                avatar: Icon(
                  _getCategoryIcon(entry.key.id),
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: Text(
                    '${entry.key.name} ¥${entry.value.toStringAsFixed(0)}'),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String id) {
    switch (id) {
      case 'figure':
        return Icons.person;
      case 'goods':
        return Icons.star;
      case 'poster':
        return Icons.image;
      case 'cosplay':
        return Icons.checkroom;
      case 'nendoroid':
        return Icons.face;
      case 'plush':
        return Icons.toys;
      case 'book':
        return Icons.book;
      case 'cd':
        return Icons.album;
      default:
        return Icons.category;
    }
  }
}