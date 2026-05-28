import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/series.dart';
import '../../models/character.dart';
import '../../database/dao/character_dao.dart';
import '../../database/dao/series_dao.dart';
import 'character_products_page.dart';

class CharacterListPage extends StatefulWidget {
  final Series series;

  const CharacterListPage({super.key, required this.series});

  @override
  State<CharacterListPage> createState() => _CharacterListPageState();
}

class _CharacterListPageState extends State<CharacterListPage> {
  final _characterDao = CharacterDao();
  final _seriesDao = SeriesDao();
  final _uuid = const Uuid();

  List<Character> _characters = [];
  Map<String, Map<String, dynamic>> _stats = {};
  late Series _series;
  bool _loading = true;
  bool _manageMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _series = widget.series;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final series = await _seriesDao.getById(widget.series.id);
      if (series != null) _series = series;
      final characters = await _characterDao.getBySeries(widget.series.id);
      final stats = <String, Map<String, dynamic>>{};
      for (final c in characters) {
        stats[c.id] = await _characterDao.getStats(c.id);
      }
      setState(() {
        _characters = characters;
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
        content: Text('确定要删除选中的 $count 个角色吗？删除后无法恢复。'),
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
        await _characterDao.delete(id);
      }
      _selectedIds.clear();
      _manageMode = false;
      _loadData();
    }
  }

  Future<void> _addCharacter() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('添加角色 - ${widget.series.name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '角色名称',
            hintText: '如：钟离、派蒙、胡桃',
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
        final character = Character(
          id: _uuid.v4(),
          name: name,
          seriesId: widget.series.id,
        );
        await _characterDao.insert(character);
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

  Future<String> _getAvatarDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory('${dir.path}/avatars');
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }
    return avatarDir.path;
  }

  Future<void> _pickAndSaveAvatar(Character character) async {
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

      final avatarDir = await _getAvatarDir();
      final destPath = '$avatarDir/${character.id}.jpg';
      final destFile = File(destPath);
      await File(picked.path).copy(destPath);
      if (!await destFile.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('头像保存失败，请重试'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      await _characterDao.update(character.copyWith(avatarPath: destPath));
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('设置头像失败：$e'), backgroundColor: Colors.red),
        );
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

  Future<void> _pickAndSaveCover() async {
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
      final destPath = '$coverDir/${widget.series.id}.jpg';
      final destFile = File(destPath);
      await File(picked.path).copy(destPath);
      if (!await destFile.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('封面保存失败，请重试'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      await _seriesDao.update(_series.copyWith(coverImage: destPath));
      final updated = await _seriesDao.getById(widget.series.id);
      if (updated != null) _series = updated;
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('设置封面失败：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSeriesCoverOptions() {
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
            Text(widget.series.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('设置封面图片'),
              subtitle: _series.coverImage != null ? const Text('已设置', style: TextStyle(color: Colors.green)) : null,
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSaveCover();
              },
            ),
            if (_series.coverImage != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.orange),
                title: const Text('移除封面图片', style: TextStyle(color: Colors.orange)),
                onTap: () {
                  Navigator.pop(ctx);
                  final path = _series.coverImage!;
                  if (File(path).existsSync()) File(path).deleteSync();
                  _seriesDao.update(_series.copyWith(clearCoverImage: true));
                  _series = _series.copyWith(clearCoverImage: true);
                  _loadData();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCharacterName(Character character) async {
    final controller = TextEditingController(text: character.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改角色名称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '角色名称',
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
    if (name != null && name.isNotEmpty && name != character.name) {
      await _characterDao.update(character.copyWith(name: name));
      _loadData();
    }
  }

  Future<void> _deleteCharacter(Character character) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${character.name}」'),
        content: const Text('删除后无法恢复，确定要删除此角色吗？'),
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
      await _characterDao.delete(character.id);
      _loadData();
    }
  }

  void _showCharacterOptions(Character character) {
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
            Text(character.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('修改名称'),
              onTap: () {
                Navigator.pop(ctx);
                _editCharacterName(character);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('设置头像'),
              subtitle: character.avatarPath != null ? const Text('已设置', style: TextStyle(color: Colors.green)) : null,
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSaveAvatar(character);
              },
            ),
            if (character.avatarPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.orange),
                title: const Text('移除头像', style: TextStyle(color: Colors.orange)),
                onTap: () {
                  Navigator.pop(ctx);
                  final path = character.avatarPath!;
                  if (File(path).existsSync()) File(path).deleteSync();
                  _characterDao.update(character.copyWith(clearAvatar: true));
                  _loadData();
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除角色', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteCharacter(character);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _characters.removeAt(oldIndex);
      _characters.insert(newIndex, item);
    });
    for (int i = 0; i < _characters.length; i++) {
      final c = _characters[i];
      await _characterDao.updateSortOrder(c.id, i);
    }
  }

  Widget _buildCharacterList() {
    final list = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSeriesInfoCard(),
        const SizedBox(height: 16),
        if (_characters.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.person_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text('还没有添加角色',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('点击右下角添加角色',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          )
        else
          ReorderableListView.builder(
            buildDefaultDragHandles: false,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _characters.length,
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
              final character = _characters[index];
              return _buildCharacterCard(character, index: index, key: ValueKey(character.id));
            },
          ),
        const SizedBox(height: 16),
        _buildUnassignedCard(),
      ],
    );

    if (_manageMode) return list;
    return RefreshIndicator(onRefresh: _loadData, child: list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _manageMode ? Text('已选择 ${_selectedIds.length} 项') : Text(widget.series.name),
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
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildCharacterList(),
      floatingActionButton: _manageMode
          ? null
          : FloatingActionButton(
              onPressed: _addCharacter,
              child: const Icon(Icons.person_add),
            ),
    );
  }

  Widget _buildSeriesIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.auto_awesome,
          color: Theme.of(context).colorScheme.primary),
    );
  }

  Widget _buildSeriesInfoCard() {
    final totalProducts = _stats.values.fold<int>(
        0, (sum, s) => sum + ((s['product_count'] as int?) ?? 0));
    final totalSpent = _stats.values.fold<double>(
        0, (sum, s) => sum + ((s['total_spent'] as num?)?.toDouble() ?? 0));

    return GestureDetector(
      onLongPress: _manageMode ? null : _showSeriesCoverOptions,
      child: Card(
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _series.coverImage != null && File(_series.coverImage!).existsSync()
                  ? Image.file(
                      File(_series.coverImage!),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildSeriesIcon(),
                    )
                  : _buildSeriesIcon(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.series.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('${_characters.length}个角色 · $totalProducts件商品',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  if (totalSpent > 0)
                    Text('总消费 ¥${totalSpent.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildAvatar(Character character) {
    if (character.avatarPath != null && File(character.avatarPath!).existsSync()) {
      return ClipOval(
        child: Image.file(
          File(character.avatarPath!),
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildDefaultAvatar(character),
        ),
      );
    }
    return _buildDefaultAvatar(character);
  }

  Widget _buildDefaultAvatar(Character character) {
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      radius: 22,
      child: Text(character.name[0],
          style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCharacterCard(Character character, {required int index, Key? key}) {
    final stat = _stats[character.id] ?? {};
    final productCount = stat['product_count'] ?? 0;
    final totalSpent = (stat['total_spent'] as num?)?.toDouble() ?? 0.0;
    final platforms = stat['platforms'] as String? ?? '';
    final isSelected = _selectedIds.contains(character.id);

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          if (_manageMode) {
            _toggleSelection(character.id);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CharacterProductsPage(
                  seriesId: widget.series.id,
                  seriesName: widget.series.name,
                  characterId: character.id,
                  characterName: character.name,
                ),
              ),
            );
          }
        },
        onLongPress: _manageMode
            ? null
            : () => _showCharacterOptions(character),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (_manageMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(character.id),
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
              const SizedBox(width: 4),
              _buildAvatar(character),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(character.name,
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                    const SizedBox(height: 2),
                    if (productCount == 0)
                      Text('暂无商品',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant))
                    else ...[
                      Text('$productCount件商品',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      if (platforms.isNotEmpty)
                        Text(platforms.split(',').take(3).join(' · '),
                            style: const TextStyle(fontSize: 11)),
                    ],
                  ],
                ),
              ),
              if (totalSpent > 0)
                Text('¥${totalSpent.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary)),
              const SizedBox(width: 4),
              if (!_manageMode)
                Icon(Icons.navigate_next_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnassignedCard() {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CharacterProductsPage(
                seriesId: widget.series.id,
                seriesName: widget.series.name,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(Icons.inventory_2,
                    color: Theme.of(context).colorScheme.onSurfaceVariant, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.series.name} 全部商品',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Icon(Icons.navigate_next_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  size: 22),
            ],
          ),
        ),
      ),
    );
  }
}