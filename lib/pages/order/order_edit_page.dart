import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/platform.dart';
import '../../models/series.dart';
import '../../models/character.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../database/dao/order_dao.dart';
import '../../database/dao/order_item_dao.dart';
import '../../database/dao/platform_dao.dart';
import '../../database/dao/series_dao.dart';
import '../../database/dao/character_dao.dart';
import '../../database/dao/category_dao.dart';
import '../../database/dao/product_dao.dart';
import '../../services/dedup_service.dart';
import '../../services/reminder_service.dart';
import '../../database/database_helper.dart';
import '../settings/platform_manage_page.dart';

class OrderEditPage extends StatefulWidget {
  final Order? existingOrder;

  const OrderEditPage({super.key, this.existingOrder});

  @override
  State<OrderEditPage> createState() => _OrderEditPageState();
}

class _OrderEditPageState extends State<OrderEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final _orderDao = OrderDao();
  final _orderItemDao = OrderItemDao();
  final _platformDao = PlatformDao();
  final _seriesDao = SeriesDao();
  final _characterDao = CharacterDao();
  final _categoryDao = CategoryDao();
  final _dedupService = DedupService();
  final _reminderService = ReminderService();
  final _productDao = ProductDao();
  final _imagePicker = ImagePicker();

  List<Platform> _platforms = [];
  List<Series> _seriesList = [];
  List<Character> _characterList = [];
  List<Category> _categories = [];

  String? _selectedPlatformId;
  String _status = 'paid';
  bool _isPresell = false;
  DateTime _orderTime = DateTime.now();
  DateTime? _balanceDeadline;
  String? _orderNo;
  String? _notes;

  final List<_ItemEntry> _items = [];
  Uint8List? _orderImageBytes;
  String? _existingScreenshotPath;

  bool _saving = false;
  bool _loading = true;

  String? _safeDropdownValue(String? value, List<String> validIds) {
    if (value == null) return null;
    if (validIds.contains(value)) return value;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final platforms = await _platformDao.getAll();
      final seriesList = await _seriesDao.getAll();
      final categories = await _categoryDao.getAll();

      setState(() {
        _platforms = platforms;
        _seriesList = seriesList;
        _categories = categories;
        _selectedPlatformId = platforms.isNotEmpty ? platforms.first.id : null;
        _loading = false;
      });

      if (widget.existingOrder != null) {
        _loadExistingOrder();
      } else {
        _items.add(_ItemEntry());
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadExistingOrder() async {
    final order = widget.existingOrder!;
    final items = await _orderItemDao.getByOrderId(order.id);

    final seriesIds = items.where((i) => i.seriesId != null).map((i) => i.seriesId!).toSet();
    List<Character> allCharacters = [];
    for (final sid in seriesIds) {
      final chars = await _characterDao.getBySeries(sid);
      allCharacters.addAll(chars);
    }

    setState(() {
      _selectedPlatformId = order.platformId;
      _status = order.status;
      _isPresell = order.isPresell;
      _orderTime = order.orderTime;
      _balanceDeadline = order.balanceDeadline;
      _orderNo = order.orderNo;
      _notes = order.notes;
      _characterList = allCharacters;
      _existingScreenshotPath = order.screenshotPath;
      if (_existingScreenshotPath != null && File(_existingScreenshotPath!).existsSync()) {
        _orderImageBytes = File(_existingScreenshotPath!).readAsBytesSync();
      }
      _items.clear();
      for (final item in items) {
        _items.add(_ItemEntry.fromOrderItem(item));
      }
    });
  }

  Future<void> _onPlatformChanged(String? platformId) async {
    setState(() => _selectedPlatformId = platformId);
  }

  Future<void> _loadCharacters(String seriesId) async {
    final characters = await _characterDao.getBySeries(seriesId);
    setState(() => _characterList = characters);
  }

  Future<void> _addSeriesQuick(int itemIndex) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('快速添加IP/系列'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'IP名称',
            hintText: '如：原神、初音未来',
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
      final series = Series(id: _uuid.v4(), name: name);
      await _seriesDao.insert(series);
      final seriesList = await _seriesDao.getAll();
      setState(() {
        _seriesList = seriesList;
        _items[itemIndex].selectedSeriesId = series.id;
        _items[itemIndex].selectedCharacterId = null;
      });
      _loadCharacters(series.id);
    }
  }

  Future<void> _addCharacterQuick(int itemIndex, String seriesId) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('快速添加角色'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '角色名称',
            hintText: '如：钟离、胡桃',
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
      final character = Character(
        id: _uuid.v4(),
        name: name,
        seriesId: seriesId,
      );
      await _characterDao.insert(character);
      await _loadCharacters(seriesId);
      setState(() => _items[itemIndex].selectedCharacterId = character.id);
    }
  }

  Future<void> _addItem() async {
    setState(() => _items.add(_ItemEntry()));
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() => _items.removeAt(index));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPlatformId == null || _selectedPlatformId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择下单平台')),
      );
      return;
    }

    _formKey.currentState!.save();

    final validItems = _items.where((item) => item.nameController.text.trim().isNotEmpty).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一个商品')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final orderId = widget.existingOrder?.id ?? _uuid.v4();
      debugPrint('========== [SAVE] 开始保存 ==========');
      debugPrint('[SAVE] orderId = $orderId');
      debugPrint('[SAVE] itemCount = ${validItems.length}');
      final totalAmount = validItems.fold<double>(
          0, (sum, item) => sum + (item.priceController.text.isEmpty ? 0 : double.parse(item.priceController.text)) * item.quantity);

      String? screenshotPath = _existingScreenshotPath;
      if (_orderImageBytes != null && _existingScreenshotPath == null) {
        final dir = await _getScreenshotDir();
        screenshotPath = '$dir/${orderId}_screenshot.jpg';
        await File(screenshotPath).writeAsBytes(_orderImageBytes!);
      } else if (_orderImageBytes == null && _existingScreenshotPath != null) {
        try {
          await File(_existingScreenshotPath!).delete();
        } catch (_) {}
        screenshotPath = null;
      }

      final order = Order(
        id: orderId,
        platformId: _selectedPlatformId!,
        orderNo: _orderNo,
        totalAmount: totalAmount,
        status: _status,
        isPresell: _isPresell,
        balanceDeadline: _isPresell ? _balanceDeadline : null,
        orderTime: _orderTime,
        notes: _notes,
        screenshotPath: screenshotPath,
      );

      final orderItems = <OrderItem>[];
      for (int i = 0; i < validItems.length; i++) {
        final item = validItems[i];
        final price = item.priceController.text.isEmpty ? 0.0 : double.parse(item.priceController.text);
        final orderItem = OrderItem(
          id: _uuid.v4(),
          orderId: orderId,
          name: item.nameController.text.trim(),
          spec: item.specController.text.trim().isEmpty ? null : item.specController.text.trim(),
          unitPrice: price,
          quantity: item.quantity,
          categoryId: item.selectedCategoryId,
          seriesId: item.selectedSeriesId,
          characterId: item.selectedCharacterId,
          sortOrder: i,
          imagePath: item.imagePath,
        );
        orderItems.add(orderItem);
      }

      for (final item in orderItems) {
        debugPrint('[SAVE] item: id=${item.id} orderId=${item.orderId} name=${item.name}');
      }

      final dedupResults = await _dedupService.checkBatch(orderItems,
        excludeNormalizedNames: widget.existingOrder != null
            ? (await _orderItemDao.getByOrderId(widget.existingOrder!.id))
                .map((i) => _dedupService.normalizeName(i.name))
                .toSet()
            : null);
      if (mounted) {
        final duplicates = dedupResults.where((r) => r.isPossibleDuplicate).toList();
        if (duplicates.isNotEmpty) {
          await _showDedupDialog(duplicates);
        }
      }

      final db = await DatabaseHelper().database;
      await db.transaction((txn) async {
        if (widget.existingOrder != null) {
          await _orderDao.update(order);
          await _orderItemDao.deleteByOrderId(orderId);
        } else {
          await _orderDao.insert(order);
        }

        await _orderItemDao.insertBatch(orderItems);

        for (final item in orderItems) {
          final normalizedName = _dedupService.normalizeName(item.name);
          final existingProduct = await _productDao.findByNormalizedName(normalizedName);
          if (existingProduct != null) {
            final newAvgPrice = (existingProduct.avgPrice * existingProduct.totalOwned + item.unitPrice) / (existingProduct.totalOwned + 1);
            await _productDao.update(existingProduct.copyWith(
              avgPrice: newAvgPrice,
              totalOwned: existingProduct.totalOwned + 1,
              lastBought: DateTime.now(),
            ));
          } else {
            final product = Product(
              id: _uuid.v4(),
              normalizedName: normalizedName,
              displayName: item.name,
              categoryId: item.categoryId,
              seriesId: item.seriesId,
              characterId: item.characterId,
              avgPrice: item.unitPrice,
              totalOwned: item.quantity,
              lastBought: DateTime.now(),
            );
            await _productDao.insert(product);
          }
        }

        await _reminderService.generateReminders(order);
      });

      final verifyItems = await _orderItemDao.getByOrderId(orderId);
      debugPrint('[SAVE] 事务提交后验证: orderId=$orderId, itemsInDb=${verifyItems.length}');
      for (final vi in verifyItems) {
        debugPrint('[SAVE] dbItem: id=${vi.id} orderId=${vi.orderId} name=${vi.name}');
      }
      debugPrint('========== [SAVE] 保存完成 ==========');

      setState(() => _saving = false);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('保存失败: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), duration: const Duration(seconds: 4)),
        );
      }
    }
  }

  Future<void> _showDedupDialog(List<DedupResult> results) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('重复购买提醒'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: results.map((r) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    r.level == 'high' ? Icons.error : Icons.info,
                    color: r.level == 'high' ? Colors.red : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '与「${r.matchedProduct?.displayName ?? "未知商品"}」相似度 ${(r.score * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  Future<String> _getScreenshotDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final screenshotDir = Directory('${dir.path}/screenshots');
    if (!await screenshotDir.exists()) {
      await screenshotDir.create(recursive: true);
    }
    return screenshotDir.path;
  }

  Future<String> _getItemImageDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final itemDir = Directory('${dir.path}/item_images');
    if (!await itemDir.exists()) {
      await itemDir.create(recursive: true);
    }
    return itemDir.path;
  }

  Future<void> _pickOrderImage() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Web 端暂不支持此功能，请在移动端使用'), backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() => _orderImageBytes = bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickItemImage(int index) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Web 端暂不支持此功能，请在移动端使用'), backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (picked == null) return;

      final dir = await _getItemImageDir();
      final destPath = '$dir/item_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
      await File(picked.path).copy(destPath);

      setState(() => _items[index].imagePath = destPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择商品图片失败：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickDate(bool isOrderTime) async {
    final initialDate = isOrderTime ? _orderTime : (_balanceDeadline ?? DateTime.now().add(const Duration(days: 30)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isOrderTime) {
          _orderTime = picked;
        } else {
          _balanceDeadline = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('录入订单')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isEdit = widget.existingOrder != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑订单' : '录入订单'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildOrderImageSection(),
            const SizedBox(height: 16),
            _buildOrderInfoSection(),
            const SizedBox(height: 20),
            _buildItemsSection(),
            const SizedBox(height: 20),
            _buildPresellSection(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderImageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('订单截图', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_orderImageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _orderImageBytes!,
                  fit: BoxFit.contain,
                  height: 200,
                  width: double.infinity,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('重新选择'),
                    onPressed: _pickOrderImage,
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('移除'),
                    onPressed: () => setState(() {
                      _orderImageBytes = null;
                      _existingScreenshotPath = null;
                    }),
                  ),
                ],
              ),
            ] else ...[
              InkWell(
                onTap: _pickOrderImage,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 40,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text('点击添加订单截图',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text('（选填）',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('订单信息', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _safeDropdownValue(_selectedPlatformId, _platforms.map((p) => p.id).toList()),
              decoration: const InputDecoration(
                labelText: '平台 *',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              validator: (v) => v == null || v.isEmpty ? '请选择平台' : null,
              onSaved: (v) => _selectedPlatformId = v,
              items: [
                if (_selectedPlatformId != null && !_platforms.any((p) => p.id == _selectedPlatformId))
                  DropdownMenuItem(value: _selectedPlatformId, child: Text(_selectedPlatformId!)),
                ..._platforms.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                const DropdownMenuItem(
                  value: '__manage__',
                  child: Row(
                    children: [
                      Icon(Icons.settings, size: 16),
                      SizedBox(width: 4),
                      Text('管理平台...', style: TextStyle(color: Colors.blue)),
                    ],
                  ),
                ),
              ],
              onChanged: (v) {
                if (v == '__manage__') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PlatformManagePage()),
                  ).then((_) async {
                    final platforms = await _platformDao.getAll();
                    setState(() {
                      _platforms = platforms;
                      if (_selectedPlatformId == null && platforms.isNotEmpty) {
                        _selectedPlatformId = platforms.first.id;
                      }
                    });
                  });
                } else {
                  _onPlatformChanged(v);
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _orderNo,
              decoration: const InputDecoration(
                labelText: '订单号（选填）',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSaved: (v) => _orderNo = v,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '下单时间',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      child: Text(DateFormat('yyyy-MM-dd').format(_orderTime)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: '状态',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSaved: (v) => _status = v ?? 'paid',
                    items: Order.statusLabels.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _notes,
              decoration: const InputDecoration(
                labelText: '备注（选填）',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLines: 2,
              onSaved: (v) => _notes = v,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('商品明细', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加商品'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_items.length, (index) => _buildItemCard(index)),
      ],
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text('商品 ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                const Spacer(),
                if (_items.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    onPressed: () => _removeItem(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _pickItemImage(index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: item.imagePath != null && File(item.imagePath!).existsSync()
                        ? Stack(
                            children: [
                              Image.file(
                                File(item.imagePath!),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => setState(() => item.imagePath = null),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outlineVariant,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 24,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                                const SizedBox(height: 2),
                                Text('商品图', style: TextStyle(fontSize: 10,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: item.nameController,
                    decoration: const InputDecoration(
                      labelText: '商品名称 *',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    validator: (v) {
                      if (_items.length == 1 && (v == null || v.trim().isEmpty)) {
                        return '请输入商品名称';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: item.priceController,
                    decoration: const InputDecoration(
                      labelText: '单价',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                      prefixText: '¥ ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    initialValue: '1',
                    decoration: const InputDecoration(
                      labelText: '数量',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      item.quantity = int.tryParse(v) ?? 1;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.specController,
              decoration: const InputDecoration(
                labelText: '规格（选填，如：通常版、A款）',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _safeDropdownValue(item.selectedCategoryId, _categories.map((c) => c.id).toList()),
                    decoration: const InputDecoration(
                      labelText: '分类',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onSaved: (v) => item.selectedCategoryId = v,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('未选择')),
                      ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (v) => setState(() => item.selectedCategoryId = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _safeDropdownValue(item.selectedSeriesId, _seriesList.map((s) => s.id).toList()),
                    decoration: const InputDecoration(
                      labelText: 'IP/系列',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onSaved: (v) => item.selectedSeriesId = v,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('未选择')),
                      ..._seriesList.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                    ],
                    onChanged: (v) {
                      setState(() {
                        item.selectedSeriesId = v;
                        item.selectedCharacterId = null;
                      });
                      if (v != null) _loadCharacters(v);
                    },
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _addSeriesQuick(index),
                    tooltip: '添加IP',
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _safeDropdownValue(item.selectedCharacterId, _characterList.map((c) => c.id).toList()),
                    decoration: const InputDecoration(
                      labelText: '角色',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onSaved: (v) => item.selectedCharacterId = v,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('未选择')),
                      ..._characterList.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (v) => setState(() => item.selectedCharacterId = v),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: item.selectedSeriesId != null
                        ? () => _addCharacterQuick(index, item.selectedSeriesId!)
                        : null,
                    tooltip: '添加角色',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresellSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('预售设置', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('包含预售商品'),
              subtitle: const Text('开启后可设置尾款截止时间'),
              value: _isPresell,
              onChanged: (v) => setState(() => _isPresell = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_isPresell) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _pickDate(false),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '尾款截止时间',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  child: Text(
                    _balanceDeadline != null
                        ? DateFormat('yyyy-MM-dd').format(_balanceDeadline!)
                        : '请选择日期',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemEntry {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController specController = TextEditingController();
  String? selectedCategoryId;
  String? selectedSeriesId;
  String? selectedCharacterId;
  int quantity = 1;
  String? imagePath;

  _ItemEntry();

  _ItemEntry.fromOrderItem(OrderItem item) {
    nameController.text = item.name;
    priceController.text = item.unitPrice > 0 ? item.unitPrice.toString() : '';
    specController.text = item.spec ?? '';
    selectedCategoryId = item.categoryId;
    selectedSeriesId = item.seriesId;
    selectedCharacterId = item.characterId;
    quantity = item.quantity;
    imagePath = item.imagePath;
  }
}