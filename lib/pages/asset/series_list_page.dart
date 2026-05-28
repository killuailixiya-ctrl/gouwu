import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/series.dart';
import '../../models/character.dart';
import '../../database/dao/series_dao.dart';
import '../../database/dao/character_dao.dart';
import 'character_list_page.dart';
import 'character_products_page.dart';
import '../search/search_page.dart';

class SeriesListPage extends StatefulWidget {
  const SeriesListPage({super.key});

  @override
  State<SeriesListPage> createState() => _SeriesListPageState();
}

class _SeriesListPageState extends State<SeriesListPage> {
  final _seriesDao = SeriesDao();
  final _characterDao = CharacterDao();
  final _uuid = const Uuid();

  List<Series> _seriesList = [];
  Map<String, Map<String, dynamic>> _stats = {};
  final Set<String> _expandedSeriesIds = {};
  final Map<String, List<Character>> _charactersCache = {};
  final Map<String, Map<String, Map<String, dynamic>>> _characterStatsCache = {};
  bool _loading = true;
  bool _manageMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _expandedSeriesIds.clear();
    _charactersCache.clear();
    _characterStatsCache.clear();
    try {
      final seriesList = await _seriesDao.getAll();
      final stats = <String, Map<String, dynamic>>{};
      for (final s in seriesList) {
        stats[s.id] = await _seriesDao.getStats(s.id);
      }
      setState(() {
        _seriesList = seriesList;
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载数据失败：$e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleExpand(String seriesId) async {
    if (_expandedSeriesIds.contains(seriesId)) {
      setState(() => _expandedSeriesIds.remove(seriesId));
      return;
    }
    setState(() => _expandedSeriesIds.add(seriesId));
    if (!_charactersCache.containsKey(seriesId)) {
      try {
        final characters = await _characterDao.getBySeries(seriesId);
        final statsMap = <String, Map<String, dynamic>>{};
        for (final c in characters) {
          statsMap[c.id] = await _characterDao.getStats(c.id);
        }
        setState(() {
          _charactersCache[seriesId] = characters;
          _characterStatsCache[seriesId] = statsMap;
        });
      } catch (e) {
        setState(() => _expandedSeriesIds.remove(seriesId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载角色失败：$e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _toggleManageMode() {
    setState(() {
      _manageMode = !_manageMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('确定要删除选中的 $count 个IP吗？删除后无法恢复。'),
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
      for (final id in _selectedIds.toList()) {
        await _seriesDao.delete(id);
      }
      _selectedIds.clear();
      _manageMode = false;
      _loadData();
    }
  }

  Future<void> _addSeries() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加IP/系列'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'IP名称',
            hintText: '如：原神、初音未来、明日方舟',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      try {
        final series = Series(id: _uuid.v4(), name: name);
        await _seriesDao.insert(series);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加失败：$e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<String> _getCoverDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final coverDir = Directory('${dir.path}/covers');
    if (!await coverDir.exists()) {
      await coverDir.create(recursive: true);
    }
    return coverDir.path;
  }

  Future<void> _pickAndSaveCover(Series series) async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Web 端暂不支持此功能，请在移动端使用'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;

      final coverDir = await _getCoverDir();
      final destPath = '$coverDir/${series.id}.jpg';
      final destFile = File(destPath);
      await File(picked.path).copy(destPath);
      if (!await destFile.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('图片保存失败，请重试'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      await _seriesDao.update(series.copyWith(coverImage: destPath));
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('设置封面失败：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editSeriesName(Series series) async {
    final controller = TextEditingController(text: series.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改IP名称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'IP名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && name != series.name) {
      await _seriesDao.update(series.copyWith(name: name));
      _loadData();
    }
  }

  Future<void> _deleteSeries(Series series) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${series.name}」'),
        content: const Text('删除后无法恢复，确定要删除此IP吗？'),
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
      await _seriesDao.delete(series.id);
      _loadData();
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _seriesList.removeAt(oldIndex);
      _seriesList.insert(newIndex, item);
    });
    for (int i = 0; i < _seriesList.length; i++) {
      final s = _seriesList[i];
      await _seriesDao.updateSortOrder(s.id, i);
    }
  }

  Widget _buildSeriesList() {
    final list = ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.all(16),
      itemCount: _seriesList.length,
      onReorder: _onReorder,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: child,
          ),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final series = _seriesList[index];
        return _buildSeriesCard(series, index: index, key: ValueKey(series.id));
      },
    );

    if (_manageMode) return list;
    return RefreshIndicator(onRefresh: _loadData, child: list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _manageMode ? Text('已选择 ${_selectedIds.length} 项') : const Text('我的资产'),
        actions: [
          if (_manageMode && _selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteSelected,
            ),
          IconButton(
            icon: Icon(_manageMode ? Icons.close : Icons.checklist),
            onPressed: _toggleManageMode,
          ),
          if (!_manageMode)
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
          : _seriesList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.category_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('还没有添加IP/系列',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Text('点击右下角添加你的第一个IP吧',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : _buildSeriesList(),
      floatingActionButton: _manageMode
          ? null
          : FloatingActionButton(
              onPressed: _addSeries,
              child: const Icon(Icons.add),
            ),
    );
  }

  void _showSeriesOptions(Series series) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 16),
            Text(series.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('修改名称'),
              onTap: () {
                Navigator.pop(ctx);
                _editSeriesName(series);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('设置封面图片'),
              subtitle: series.coverImage != null ? const Text('已设置', style: TextStyle(color: Colors.green)) : null,
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSaveCover(series);
              },
            ),
            if (series.coverImage != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.orange),
                title: const Text('移除封面图片', style: TextStyle(color: Colors.orange)),
                onTap: () {
                  Navigator.pop(ctx);
                  final path = series.coverImage!;
                  if (File(path).existsSync()) File(path).deleteSync();
                  _seriesDao.update(series.copyWith(clearCoverImage: true));
                  _loadData();
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除IP', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteSeries(series);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.auto_awesome,
          color: Theme.of(context).colorScheme.primary, size: 24),
    );
  }

  Widget _buildSeriesCard(Series series, {required int index, Key? key}) {
    final stat = _stats[series.id] ?? {};
    final characterCount = stat['character_count'] ?? 0;
    final productCount = stat['product_count'] ?? 0;
    final totalSpent = (stat['total_spent'] as num?)?.toDouble() ?? 0.0;
    final isSelected = _selectedIds.contains(series.id);
    final isExpanded = _expandedSeriesIds.contains(series.id);
    final characters = _charactersCache[series.id];
    final charStats = _characterStatsCache[series.id];

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              if (_manageMode) {
                _toggleSelection(series.id);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CharacterListPage(series: series),
                  ),
                ).then((_) => _loadData());
              }
            },
            onLongPress: _manageMode
                ? null
                : () => _showSeriesOptions(series),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_manageMode) ...[
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(series.id),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (!_manageMode)
                    ReorderableDragStartListener(
                      index: index,
                      child: Icon(Icons.drag_indicator_rounded,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                            size: 20),
                    ),
                  const SizedBox(width: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: series.coverImage != null && File(series.coverImage!).existsSync()
                        ? Image.file(
                            File(series.coverImage!),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildDefaultIcon(),
                          )
                        : _buildDefaultIcon(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(series.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        if (productCount == 0 && characterCount == 0)
                          Text('暂无商品和角色',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant))
                        else ...[
                          Text(
                            '$characterCount个角色 · $productCount件商品',
                            style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          if (totalSpent > 0) ...[
                            const SizedBox(height: 2),
                            Text('总消费 ¥${totalSpent.toStringAsFixed(0)}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.primary)),
                          ],
                        ],
                      ],
                    ),
                  ),
                  if (!_manageMode)
                    GestureDetector(
                      onTap: () => _toggleExpand(series.id),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isExpanded && characters != null && charStats != null) ...[
            const Divider(height: 1),
            ...characters.map((c) => _buildCharacterRow(c, charStats)),
          ],
        ],
      ),
    );
  }

  Widget _buildCharacterRow(Character character, Map<String, Map<String, dynamic>> charStats) {
    final stat = charStats[character.id] ?? {};
    final productCount = stat['product_count'] ?? 0;
    final totalSpent = (stat['total_spent'] as num?)?.toDouble() ?? 0.0;

    return InkWell(
      onTap: () {
        final series = _seriesList.firstWhere((s) => s.id == character.seriesId);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CharacterProductsPage(
              seriesId: character.seriesId,
              seriesName: series.name,
              characterId: character.id,
              characterName: character.name,
            ),
          ),
        ).then((_) => _loadData());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (character.avatarPath != null && File(character.avatarPath!).existsSync())
              ClipOval(
                child: Image.file(
                  File(character.avatarPath!),
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildCharacterDefaultAvatar(character),
                ),
              )
            else
              _buildCharacterDefaultAvatar(character),
            const SizedBox(width: 12),
            Expanded(
              child: Text(character.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            Text('$productCount件',
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            if (totalSpent > 0) ...[
              const SizedBox(width: 8),
              Text('¥${totalSpent.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary)),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterDefaultAvatar(Character character) {
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      radius: 16,
      child: Text(character.name[0],
          style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.bold,
              fontSize: 12)),
    );
  }
}
