import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/platform.dart';
import '../../database/dao/platform_dao.dart';

class PlatformManagePage extends StatefulWidget {
  const PlatformManagePage({super.key});

  @override
  State<PlatformManagePage> createState() => _PlatformManagePageState();
}

class _PlatformManagePageState extends State<PlatformManagePage> {
  final _platformDao = PlatformDao();
  final _uuid = const Uuid();

  List<Platform> _platforms = [];
  bool _loading = true;

  final _platformColors = {
    '淘宝': 'FF5000',
    '拼多多': 'E02E24',
    'B站会员购': 'FB7299',
    '闲鱼': 'FFC300',
    '微店': '07C160',
    '京东': 'C91623',
    '天猫': 'FF0033',
    '抖音': '000000',
    '其他': '999999',
  };

  static const _defaultPlatforms = [
    {'id': 'taobao', 'name': '淘宝', 'color_code': '#FF5000', 'sort_order': 1},
    {'id': 'pinduoduo', 'name': '拼多多', 'color_code': '#E02E24', 'sort_order': 2},
    {'id': 'bilibili', 'name': 'B站会员购', 'color_code': '#FB7299', 'sort_order': 3},
    {'id': 'xianyu', 'name': '闲鱼', 'color_code': '#FFC300', 'sort_order': 4},
    {'id': 'weidian', 'name': '微店', 'color_code': '#07C160', 'sort_order': 5},
    {'id': 'jd', 'name': '京东', 'color_code': '#C91623', 'sort_order': 6},
    {'id': 'other', 'name': '其他', 'color_code': '#999999', 'sort_order': 99},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      var platforms = await _platformDao.getAll();
      if (platforms.isEmpty) {
        for (final p in _defaultPlatforms) {
          final platform = Platform(
            id: p['id'] as String,
            name: p['name'] as String,
            colorCode: p['color_code'] as String,
            sortOrder: p['sort_order'] as int,
          );
          await _platformDao.insert(platform);
        }
        platforms = await _platformDao.getAll();
      }
      setState(() {
        _platforms = platforms;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _resetDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置默认平台'),
        content: const Text('将删除所有自定义平台并恢复默认平台列表，确定继续吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('重置', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final currentPlatforms = await _platformDao.getAll();
      for (final p in currentPlatforms) {
        await _platformDao.delete(p.id);
      }
      for (final p in _defaultPlatforms) {
        final platform = Platform(
          id: p['id'] as String,
          name: p['name'] as String,
          colorCode: p['color_code'] as String,
          sortOrder: p['sort_order'] as int,
        );
        await _platformDao.insert(platform);
      }
      _loadData();
    }
  }

  Future<void> _addPlatform() async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加平台'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '平台名称',
            hintText: '如：淘宝、拼多多、B站会员购',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final colorCode = _platformColors[result] ?? '999999';
      final platform = Platform(
        id: _uuid.v4(),
        name: result,
        colorCode: colorCode,
        sortOrder: _platforms.length,
      );
      await _platformDao.insert(platform);
      _loadData();
    }
  }

  Future<void> _editPlatform(Platform platform) async {
    final nameController = TextEditingController(text: platform.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑平台'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '平台名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _platformDao.update(platform.copyWith(name: result));
      _loadData();
    }
  }

  Future<void> _deletePlatform(Platform platform) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${platform.name}」'),
        content: const Text('删除后无法恢复，确定要删除此平台吗？'),
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
      await _platformDao.delete(platform.id);
      _loadData();
    }
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('平台管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: '重置默认',
            onPressed: _resetDefaults,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _platforms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.store_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('还没有平台',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Text('点击右下角添加平台',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _platforms.length,
                  itemBuilder: (_, i) {
                    final platform = _platforms[i];
                    final color = _parseColor(platform.colorCode);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.store, color: color, size: 20),
                        ),
                        title: Text(platform.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _editPlatform(platform),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              onPressed: () => _deletePlatform(platform),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPlatform,
        child: const Icon(Icons.add),
      ),
    );
  }
}