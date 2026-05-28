import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/category.dart';
import '../../database/dao/category_dao.dart';

class CategoryManagePage extends StatefulWidget {
  const CategoryManagePage({super.key});

  @override
  State<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends State<CategoryManagePage> {
  final _categoryDao = CategoryDao();
  final _uuid = const Uuid();

  List<Category> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final categories = await _categoryDao.getAll();
      setState(() {
        _categories = categories;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addCategory() async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加品类'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '品类名称',
            hintText: '如：手办、谷子、海报',
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
      final category = Category(
        id: _uuid.v4(),
        name: result,
        sortOrder: _categories.length,
      );
      await _categoryDao.insert(category);
      _loadData();
    }
  }

  Future<void> _editCategory(Category category) async {
    final nameController = TextEditingController(text: category.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑品类'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '品类名称',
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
      await _categoryDao.update(category.copyWith(name: result));
      _loadData();
    }
  }

  Future<void> _deleteCategory(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${category.name}」'),
        content: const Text('删除后无法恢复，确定要删除此品类吗？'),
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
      await _categoryDao.delete(category.id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('品类管理'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.category_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('还没有品类',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Text('点击右下角添加品类',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _categories.length,
                  itemBuilder: (_, i) {
                    final category = _categories[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.category,
                              color: Theme.of(context).colorScheme.primary, size: 20),
                        ),
                        title: Text(category.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _editCategory(category),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              onPressed: () => _deleteCategory(category),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        child: const Icon(Icons.add),
      ),
    );
  }
}