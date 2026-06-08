import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../database/dao/order_dao.dart';
import '../../database/dao/order_item_dao.dart';
import '../../database/dao/platform_dao.dart';
import '../../database/dao/series_dao.dart';
import '../../database/dao/character_dao.dart';
import '../../database/dao/category_dao.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/platform.dart';
import '../../models/series.dart';
import '../../models/character.dart';
import '../../models/category.dart';

class OrderEditPage extends StatefulWidget {
  final String? orderId;

  const OrderEditPage({super.key, this.orderId});

  @override
  State<OrderEditPage> createState() => _OrderEditPageState();
}

class _OrderEditPageState extends State<OrderEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final OrderDao _orderDao = OrderDao();
  final OrderItemDao _orderItemDao = OrderItemDao();
  final PlatformDao _platformDao = PlatformDao();
  final SeriesDao _seriesDao = SeriesDao();
  final CharacterDao _characterDao = CharacterDao();
  final CategoryDao _categoryDao = CategoryDao();

  List<Platform> _platforms = [];
  List<Series> _seriesList = [];
  List<Category> _categories = [];
  String? _selectedPlatformId;
  DateTime _orderTime = DateTime.now();
  String _orderNo = '';
  String _notes = '';
  bool _isPresell = false;
  DateTime? _balanceDeadline;
  bool _loading = true;

  List<_ItemEntry> _items = [];

  @override
  void initState() {
    super.initState();
    _items = [_ItemEntry(uuid: _uuid)];
    _loadData();
  }

  Future<void> _loadData() async {
    final platforms = await _platformDao.getAll();
    final seriesList = await _seriesDao.getAll();
    final categories = await _categoryDao.getAll();

    if (widget.orderId != null) {
      final order = await _orderDao.getById(widget.orderId!);
      if (order != null) {
        final items = await _orderItemDao.getByOrderId(order.id);
        setState(() {
          _selectedPlatformId = order.platformId;
          _orderTime = order.orderTime;
          _orderNo = order.orderNo ?? '';
          _notes = order.notes ?? '';
          _isPresell = order.isPresell;
          _balanceDeadline = order.balanceDeadline;
          _platforms = platforms;
          _seriesList = seriesList;
          _categories = categories;
          _items = items
              .map((i) => _ItemEntry(
                    uuid: _uuid,
                    id: i.id,
                    name: i.name,
                    spec: i.spec,
                    price: i.unitPrice,
                    quantity: i.quantity,
                    selectedSeriesId: i.seriesId,
                    selectedCharacterId: i.characterId,
                    selectedCategoryId: i.categoryId,
                    imagePath: i.imagePath,
                  ))
              .toList();
          _loading = false;
        });
        return;
      }
    }

    setState(() {
      _platforms = platforms;
      _seriesList = seriesList;
      _categories = categories;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_selectedPlatformId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择平台'), backgroundColor: Colors.red),
      );
      return;
    }

    final orderId = widget.orderId ?? _uuid.v4();
    double totalAmount = 0;
    for (final item in _items) {
      if (item.name.isNotEmpty) {
        totalAmount += item.price * item.quantity;
      }
    }

    final order = Order(
      id: orderId,
      platformId: _selectedPlatformId!,
      orderNo: _orderNo.isNotEmpty ? _orderNo : null,
      totalAmount: totalAmount,
      status: 'pending',
      isPresell: _isPresell,
      balanceDeadline: _balanceDeadline,
      orderTime: _orderTime,
      notes: _notes.isNotEmpty ? _notes : null,
    );

    if (widget.orderId != null) {
      await _orderDao.update(order);
    } else {
      await _orderDao.insert(order);
    }

    await _orderItemDao.deleteByOrderId(orderId);
    for (final item in _items) {
      if (item.name.isNotEmpty) {
        final orderItem = OrderItem(
          id: item.id ?? _uuid.v4(),
          orderId: orderId,
          name: item.name,
          spec: item.spec,
          unitPrice: item.price,
          quantity: item.quantity,
          seriesId: item.selectedSeriesId,
          characterId: item.selectedCharacterId,
          categoryId: item.selectedCategoryId,
          imagePath: item.imagePath,
        );
        await _orderItemDao.insert(orderItem);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存成功'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _addPlatform() async {
    final controller = TextEditingController();
    final colorController = TextEditingController(text: '#2196F3');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加平台'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: '平台名称'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: colorController,
              decoration: const InputDecoration(labelText: '颜色代码'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (result == true && controller.text.isNotEmpty) {
      final platform = Platform(
        id: _uuid.v4(),
        name: controller.text.trim(),
        colorCode: colorController.text.trim(),
      );
      await _platformDao.insert(platform);
      final platforms = await _platformDao.getAll();
      setState(() {
        _platforms = platforms;
        _selectedPlatformId = platform.id;
      });
    }
  }

  Future<void> _addSeries() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加IP'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'IP名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (result == true && controller.text.isNotEmpty) {
      final series = Series(id: _uuid.v4(), name: controller.text.trim());
      await _seriesDao.insert(series);
      final seriesList = await _seriesDao.getAll();
      setState(() {
        _seriesList = seriesList;
        for (final item in _items) {
          if (item.selectedSeriesId == null) {
            item.selectedSeriesId = series.id;
          }
        }
      });
    }
  }

  Future<void> _addCharacter(int itemIndex, String seriesId) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加角色'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '角色名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (result == true && controller.text.isNotEmpty) {
      final character = Character(
        id: _uuid.v4(),
        seriesId: seriesId,
        name: controller.text.trim(),
      );
      await _characterDao.insert(character);
      final characters = await _characterDao.getBySeries(seriesId);
      setState(() {
        _items[itemIndex].characterList = characters;
        _items[itemIndex].selectedCharacterId = character.id;
      });
    }
  }

  void _addItem() {
    setState(() {
      _items.add(_ItemEntry(uuid: _uuid));
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.orderId != null ? '编辑订单' : '手动录入'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
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
                  _buildPlatformSection(),
                  const SizedBox(height: 16),
                  _buildOrderInfoSection(),
                  const SizedBox(height: 16),
                  ..._items.asMap().entries.map((e) => _buildItemSection(e.key, e.value)),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add),
                      label: const Text('添加商品'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPresellSection(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildPlatformSection() {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('平台', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedPlatformId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _platforms.map((p) {
                      return DropdownMenuItem(value: p.id, child: Text(p.name));
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedPlatformId = v),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _addPlatform,
                  child: const Text('添加'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfoSection() {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('订单信息', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _orderNo,
              decoration: const InputDecoration(
                labelText: '订单号',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _orderNo = v,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDatePicker(
                    label: '下单时间',
                    date: _orderTime,
                    onChanged: (d) => setState(() => _orderTime = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _notes,
              decoration: const InputDecoration(
                labelText: '备注',
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

  Widget _buildDatePicker({
    required String label,
    required DateTime date,
    required ValueChanged<DateTime> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(date),
          );
          if (time != null) {
            onChanged(DateTime(
              picked.year,
              picked.month,
              picked.day,
              time.hour,
              time.minute,
            ));
          } else {
            onChanged(picked);
          }
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(DateFormat('yyyy-MM-dd HH:mm').format(date)),
      ),
    );
  }

  Widget _buildItemSection(int index, _ItemEntry item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('商品 ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_items.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () => _removeItem(index),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: item.name,
              decoration: const InputDecoration(
                labelText: '商品名称',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => item.name = v,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.price > 0 ? item.price.toString() : '',
                    decoration: const InputDecoration(
                      labelText: '单价',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        item.price = double.tryParse(v) ?? 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: item.quantity > 1
                        ? item.quantity.toString()
                        : '1',
                    decoration: const InputDecoration(
                      labelText: '数量',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        item.quantity = int.tryParse(v) ?? 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: item.spec,
              decoration: const InputDecoration(
                labelText: '规格',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => item.spec = v,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: item.selectedSeriesId,
                    decoration: const InputDecoration(
                      labelText: 'IP',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _seriesList.map((s) {
                      return DropdownMenuItem(
                          value: s.id, child: Text(s.name));
                    }).toList(),
                    onChanged: (v) async {
                      setState(() => item.selectedSeriesId = v);
                      if (v != null) {
                        final characters =
                            await _characterDao.getBySeries(v);
                        item.characterList = characters;
                        item.selectedCharacterId = null;
                        setState(() {});
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _addSeries,
                  child: const Text('添加'),
                ),
              ],
            ),
            if (item.selectedSeriesId != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: item.selectedCharacterId,
                      decoration: const InputDecoration(
                        labelText: '角色',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      items: item.characterList.map((c) {
                        return DropdownMenuItem(
                            value: c.id, child: Text(c.name));
                      }).toList(),
                      onChanged: (v) =>
                          setState(() => item.selectedCharacterId = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () =>
                        _addCharacter(index, item.selectedSeriesId!),
                    child: const Text('添加'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: item.selectedCategoryId,
              decoration: const InputDecoration(
                labelText: '分类',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _categories.map((c) {
                return DropdownMenuItem(value: c.id, child: Text(c.name));
              }).toList(),
              onChanged: (v) =>
                  setState(() => item.selectedCategoryId = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresellSection() {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('预售订单',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              value: _isPresell,
              onChanged: (v) => setState(() => _isPresell = v),
            ),
            if (_isPresell) ...[
              const SizedBox(height: 8),
              _buildDatePicker(
                label: '尾款截止日期',
                date: _balanceDeadline ?? DateTime.now(),
                onChanged: (d) => setState(() => _balanceDeadline = d),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemEntry {
  final Uuid uuid;
  String? id;
  String name;
  String? spec;
  double price;
  int quantity;
  String? selectedSeriesId;
  String? selectedCharacterId;
  String? selectedCategoryId;
  String? imagePath;
  List<Character> characterList;

  _ItemEntry({
    required this.uuid,
    this.id,
    this.name = '',
    this.spec,
    this.price = 0,
    this.quantity = 1,
    this.selectedSeriesId,
    this.selectedCharacterId,
    this.selectedCategoryId,
    this.imagePath,
    List<Character>? characterList,
  }) : characterList = characterList ?? [];
}