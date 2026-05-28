class OrderItem {
  final String id;
  final String orderId;
  final String? productId;
  final String name;
  final String? spec;
  final double unitPrice;
  final int quantity;
  final String? itemStatus;
  final String? imagePath;
  final String? imageHash;
  final String? categoryId;
  final String? seriesId;
  final String? characterId;
  final String? sourceText;
  final int sortOrder;
  final DateTime createdAt;

  OrderItem({
    required this.id,
    required this.orderId,
    this.productId,
    required this.name,
    this.spec,
    this.unitPrice = 0,
    this.quantity = 1,
    this.itemStatus,
    this.imagePath,
    this.imageHash,
    this.categoryId,
    this.seriesId,
    this.characterId,
    this.sourceText,
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get totalPrice => unitPrice * quantity;

  Map<String, dynamic> toMap() => {
        'id': id,
        'order_id': orderId,
        'product_id': productId,
        'name': name,
        'spec': spec,
        'unit_price': unitPrice,
        'quantity': quantity,
        'item_status': itemStatus,
        'image_path': imagePath,
        'image_hash': imageHash,
        'category_id': categoryId,
        'series_id': seriesId,
        'character_id': characterId,
        'source_text': sourceText,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        id: map['id'] as String,
        orderId: map['order_id'] as String,
        productId: map['product_id'] as String?,
        name: map['name'] as String,
        spec: map['spec'] as String?,
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
        quantity: map['quantity'] as int? ?? 1,
        itemStatus: map['item_status'] as String?,
        imagePath: map['image_path'] as String?,
        imageHash: map['image_hash'] as String?,
        categoryId: map['category_id'] as String?,
        seriesId: map['series_id'] as String?,
        characterId: map['character_id'] as String?,
        sourceText: map['source_text'] as String?,
        sortOrder: map['sort_order'] as int? ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  OrderItem copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? name,
    String? spec,
    double? unitPrice,
    int? quantity,
    String? itemStatus,
    String? imagePath,
    String? imageHash,
    String? categoryId,
    String? seriesId,
    String? characterId,
    String? sourceText,
    int? sortOrder,
  }) =>
      OrderItem(
        id: id ?? this.id,
        orderId: orderId ?? this.orderId,
        productId: productId ?? this.productId,
        name: name ?? this.name,
        spec: spec ?? this.spec,
        unitPrice: unitPrice ?? this.unitPrice,
        quantity: quantity ?? this.quantity,
        itemStatus: itemStatus ?? this.itemStatus,
        imagePath: imagePath ?? this.imagePath,
        imageHash: imageHash ?? this.imageHash,
        categoryId: categoryId ?? this.categoryId,
        seriesId: seriesId ?? this.seriesId,
        characterId: characterId ?? this.characterId,
        sourceText: sourceText ?? this.sourceText,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
      );
}