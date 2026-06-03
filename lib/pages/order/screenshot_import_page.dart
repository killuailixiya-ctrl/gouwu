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
import '../../services/ocr_service.dart';
import '../settings/platform_manage_page.dart';

class ScreenshotImportPage extends StatefulWidget {
  const ScreenshotImportPage({super.key});

  @override
  State<ScreenshotImportPage> createState() => _ScreenshotImportPageState();
}

class _ScreenshotImportPageState extends State<ScreenshotImportPage> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final _imagePicker = ImagePicker();
  final _orderDao = OrderDao();
  final _orderItemDao = OrderItemDao();
  final _platformDao = PlatformDao();
  final _seriesDao = SeriesDao();
  final _characterDao = CharacterDao();
  final _categoryDao = CategoryDao();
  final _dedupService = DedupService();
  final _reminderService = ReminderService();
  final _ocrService = OcrService();
  final _productDao = ProductDao();

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

  final List<_ImportItemEntry> _items = [];
  Uint8List? _imageBytes;

  bool _saving = false;
  bool _ocrProcessing = false;
  bool _loading = true;

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

      _items.add(_ImportItemEntry());
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Web 端暂不支持此功能，请在移动端使用'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
        await _runOcr(bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _runOcr(Uint8List imageBytes) async {
    setState(() => _ocrProcessing = true);
    File? tempFile;
    try {
      final tempDir = await getTemporaryDirectory();
      tempFile = File('${tempDir.path}/ocr_temp.jpg');
      await tempFile.writeAsBytes(imageBytes);

      final result = await _ocrService.recognizeFromFile(tempFile.path);
      if (!mounted) return;
      setState(() {
        if (result.orderNo != null) {
          _orderNo = result.orderNo;
        }
        if (result.totalAmount != null && _items.isNotEmpty) {
          _items[0].unitPrice = result.totalAmount!;
          _items[0].quantity = 1;
        }
        if (result.productNames.isNotEmpty) {
          _items.clear();
          for (final name in result.productNames) {
            _items.add(_ImportItemEntry()..name = name);
          }
        }
        _ocrProcessing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _ocrProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('文字识别失败：$e'), backgroundColor: Colors.orange),
        );
      }
    } finally {
      try { tempFile?.deleteSync(); } catch (_) {}
    }
  }

  void _addItem() {
    setState(() {
      _items.add(_ImportItemEntry());
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _addPlatform() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加平台'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '平台名称',
            hintText: '如：淘宝、京东、拼多多',
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
        await _platformDao.insert(Platform(
          id: _uuid.v4(),
          name: name,
          colorCode: '#999999',
          sortOrder: _platforms.length,
        ));
        final platforms = await _platformDao.getAll();
        setState(() {
          _platforms = platforms;
          _selectedPlatformId ??= platforms.first.id;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加失败：$e'), backgroundColor: Colors.red),
          );
        }
      }
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
        await _seriesDao.insert(Series(id: _uuid.v4(), name: name));
        final seriesList = await _seriesDao.getAll();
        setState(() => _seriesList = seriesList);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加失败：$e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _addCharacter(String seriesId) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加角色'),
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
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      try {
        await _characterDao.insert(Character(
          id: _uuid.v4(),
          seriesId: seriesId,
          name: name,
        ));
        final characterList = await _characterDao.getBySeries(seriesId);
        setState(() => _characterList = characterList);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加失败：$e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _onPlatformChanged(String platformId) async {
    setState(() => _selectedPlatformId = platformId);
  }

  Future<void> _onSeriesChanged(int itemIndex, String? seriesId) async {
    if (seriesId != null && seriesId.isNotEmpty) {
      final characters = await _characterDao.getBySeries(seriesId);
      setState(() {
        _items[itemIndex].selectedSeriesId = seriesId;
        _items[itemIndex].selectedCharacterId = null;
        _characterList = characters;
      });
    } else {
      setState(() {
        _items[itemIndex].selectedSeriesId = null;
        _items[itemIndex].selectedCharacterId = null;
        _characterList = [];
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一个商品'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final orderId = _uuid.v4();

      String? screenshotPath;
      if (_imageBytes != null) {
        final imageDir = await _getScreenshotDir();
        if (imageDir.isNotEmpty) {
          final imageFile = File('$imageDir/$orderId.jpg');
          await imageFile.writeAsBytes(_imageBytes!);
          screenshotPath = imageFile.path;
        }
      }

      final order = Order(
        id: orderId,
        platformId: _selectedPlatformId ?? 'other',
        status: _status,
        isPresell: _isPresell,
        totalAmount: _items.fold<double>(
            0, (sum, item) => sum + (item.unitPrice * item.quantity)),
        orderTime: _orderTime,
        balanceDeadline: _balanceDeadline,
        orderNo: _orderNo,
        notes: _notes,
        screenshotPath: screenshotPath,
      );

      final orderItems = <OrderItem>[];
      for (final entry in _items) {
        orderItems.add(OrderItem(
          id: _uuid.v4(),
          orderId: order.id,
          name: entry.name,
          spec: entry.spec,
          unitPrice: entry.unitPrice,
          quantity: entry.quantity,
          categoryId: entry.selectedCategoryId,
          seriesId: entry.selectedSeriesId,
          characterId: entry.selectedCharacterId,
          imagePath: entry.imagePath,
        ));
      }

      await _orderDao.insert(order);
      for (final item in orderItems) {
        await _orderItemDao.insert(item);

        final normalized = _dedupService.normalizeName(item.name);
        await _productDao.upsert(Product(
          id: _uuid.v4(),
          normalizedName: normalized,
          displayName: item.name,
          categoryId: item.categoryId,
          seriesId: item.seriesId,
          characterId: item.characterId,
        ));
      }

      await _reminderService.generateReminders(order);

      final dupResults = await _dedupService.checkBatch(orderItems);
      if (dupResults.isNotEmpty && mounted) {
        final messages = dupResults
            .map((r) => r.matchedProduct?.displayName ?? '未知商品')
            .take(3)
            .toList();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('相似度提醒'),
            content: Text('检测到可能与以下商品重复：\n${messages.join('\n')}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('我知道了'),
              ),
            ],
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String> _getScreenshotDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final screenshotDir = Directory('${dir.path}/screenshots');
    if (!await screenshotDir.exists()) {
      await screenshotDir.create(recursive: true);
    }
    return screenshotDir.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('截图导入'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildImageSection(),
                  const SizedBox(height: 16),
                  _buildOrderInfoSection(),
                  const SizedBox(height: 16),
                  _buildItemsSection(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildImageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('截图预览', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_imageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.memory(
                      _imageBytes!,
                      fit: BoxFit.contain,
                      height: 250,
                    ),
                    if (_ocrProcessing)
                      Container(
                        height: 250,
                        color: Colors.black26,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 12),
                              Text('正在识别...', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('重新选择'),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('移除'),
                    onPressed: () => setState(() {
                      _imageBytes = null;
                    }),
                  ),
                ],
              ),
            ] else ...[
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: InkWell(
                  onTap: () => _pickImage(ImageSource.gallery),
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text('点击选择截图',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text('支持淘宝、京东、拼多多等购物平台订单截图',
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
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('订单信息', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedPlatformId,
                    decoration: const InputDecoration(
                      labelText: '平台',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _platforms.map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name, style: const TextStyle(fontSize: 14)),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) _onPlatformChanged(v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 22),
                  onPressed: _addPlatform,
                  tooltip: '添加平台',
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.settings, size: 22),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PlatformManagePage()),
                    );
                    final platforms = await _platformDao.getAll();
                    setState(() {
                      _platforms = platforms;
                      if (_selectedPlatformId == null && platforms.isNotEmpty) {
                        _selectedPlatformId = platforms.first.id;
                      }
                    });
                  },
                  tooltip: '管理平台',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDateTimePicker(
                    label: '下单时间',
                    value: dateFormat.format(_orderTime),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _orderTime,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null && mounted) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_orderTime),
                        );
                        if (time != null) {
                          setState(() {
                            _orderTime = DateTime(
                                date.year, date.month, date.day, time.hour, time.minute);
                          });
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: '状态',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'paid', child: Text('已付款', style: TextStyle(fontSize: 14))),
                      DropdownMenuItem(value: 'shipped', child: Text('已发货', style: TextStyle(fontSize: 14))),
                      DropdownMenuItem(value: 'received', child: Text('已收货', style: TextStyle(fontSize: 14))),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _status = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _orderNo,
                    decoration: const InputDecoration(
                      labelText: '订单号（选填）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => _orderNo = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('预售商品', style: TextStyle(fontSize: 14)),
              value: _isPresell,
              onChanged: (v) => setState(() => _isPresell = v),
              dense: true,
            ),
            if (_isPresell)
              _buildDateTimePicker(
                label: '尾款截止日期',
                value: _balanceDeadline != null
                    ? dateFormat.format(_balanceDeadline!)
                    : '点击选择',
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (date != null) {
                    setState(() => _balanceDeadline = date);
                  }
                },
              ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _notes,
              decoration: const InputDecoration(
                labelText: '备注（选填）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (v) => _notes = v,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimePicker({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(value, style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('商品明细',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加商品'),
              onPressed: _addItem,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._items.asMap().entries.map((entry) => _buildItemCard(entry.key, entry.value)),
      ],
    );
  }

  Future<String> _getItemImageDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final itemDir = Directory('${dir.path}/item_images');
    if (!await itemDir.exists()) {
      await itemDir.create(recursive: true);
    }
    return itemDir.path;
  }

  Future<void> _pickItemImage(int index) async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    final dir = await _getItemImageDir();
    final destPath = '$dir/item_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
    await File(picked.path).copy(destPath);

    setState(() => _items[index].imagePath = destPath);
  }

  Widget _buildItemCard(int index, _ImportItemEntry item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text('商品 ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                if (_items.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _removeItem(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 10),
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
                    initialValue: item.name,
                    decoration: const InputDecoration(
                      labelText: '商品名称 *',
                      hintText: '按照截图中商品名称填写',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => item.name = v,
                    validator: (v) => (v == null || v.trim().isEmpty) ? '请输入商品名称' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: item.selectedSeriesId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'IP/系列',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('无', style: TextStyle(fontSize: 13)),
                      ),
                      ..._seriesList.map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name, style: const TextStyle(fontSize: 13)),
                      )),
                    ],
                    onChanged: (v) => _onSeriesChanged(index, v),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: _addSeries,
                  tooltip: '添加IP',
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: item.selectedCharacterId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '角色',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('无', style: TextStyle(fontSize: 13)),
                      ),
                      ..._characterList.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, style: const TextStyle(fontSize: 13)),
                      )),
                    ],
                    onChanged: (v) {
                      setState(() => item.selectedCharacterId = v);
                    },
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () {
                    if (item.selectedSeriesId != null) {
                      _addCharacter(item.selectedSeriesId!);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请先选择IP/系列')),
                      );
                    }
                  },
                  tooltip: '添加角色',
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: item.unitPrice > 0 ? item.unitPrice.toString() : '',
                    decoration: const InputDecoration(
                      labelText: '单价 *',
                      prefixText: '¥ ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => item.unitPrice = double.tryParse(v) ?? 0,
                    validator: (v) {
                      if (v == null || v.isEmpty) return '请输入单价';
                      final price = double.tryParse(v);
                      if (price == null || price <= 0) return '请输入有效价格';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: item.quantity > 0 ? item.quantity.toString() : '1',
                    decoration: const InputDecoration(
                      labelText: '数量',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => item.quantity = int.tryParse(v) ?? 1,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<String>(
                    initialValue: item.selectedCategoryId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '品类',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('无', style: TextStyle(fontSize: 13)),
                      ),
                      ..._categories.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, style: const TextStyle(fontSize: 13)),
                      )),
                    ],
                    onChanged: (v) => setState(() => item.selectedCategoryId = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: item.spec,
              decoration: const InputDecoration(
                labelText: '规格/备注（选填）',
                hintText: '如：颜色、尺寸、版本',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => item.spec = v,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }
}

class _ImportItemEntry {
  String name = '';
  String spec = '';
  double unitPrice = 0;
  int quantity = 1;
  String? selectedSeriesId;
  String? selectedCharacterId;
  String? selectedCategoryId;
  String? imagePath;
}