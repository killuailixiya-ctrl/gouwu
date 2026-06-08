import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'pages/dashboard/dashboard_page.dart';
import 'pages/order/order_list_page.dart';
import 'pages/asset/series_list_page.dart';
import 'pages/stats/stats_page.dart';

class GouWuApp extends StatelessWidget {
  const GouWuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '购物',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final _refreshNotifier = ValueNotifier<int>(0);

  final _dashboardKey = GlobalKey<DashboardPageState>();
  final _seriesListKey = GlobalKey<SeriesListPageState>();
  final _orderListKey = GlobalKey<OrderListPageState>();
  final _statsKey = GlobalKey<StatsPageState>();

  @override
  void dispose() {
    _refreshNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardPage(key: _dashboardKey, refreshNotifier: _refreshNotifier),
          SeriesListPage(key: _seriesListKey, refreshNotifier: _refreshNotifier),
          OrderListPage(key: _orderListKey, refreshNotifier: _refreshNotifier),
          StatsPage(key: _statsKey, refreshNotifier: _refreshNotifier),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          print('[MainPage] tab switched to: $index, refreshNotifier=${_refreshNotifier.value} -> ${_refreshNotifier.value + 1}');
          setState(() => _currentIndex = index);
          _refreshNotifier.value++;
          // Manually refresh each page
          _dashboardKey.currentState?.refresh();
          _seriesListKey.currentState?.refresh();
          _orderListKey.currentState?.refresh();
          _statsKey.currentState?.refresh();
        },
        animationDuration: const Duration(milliseconds: 300),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: '资产',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '订单',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '统计',
          ),
        ],
      ),
    );
  }
}