class Category {
  final String id;
  final String name;
  final String? icon;
  final int sortOrder;
  final String? parentId;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    this.icon,
    this.sortOrder = 0,
    this.parentId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'sort_order': sortOrder,
        'parent_id': parentId,
        'created_at': createdAt.toIso8601String(),
      };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as String,
        name: map['name'] as String,
        icon: map['icon'] as String?,
        sortOrder: map['sort_order'] as int? ?? 0,
        parentId: map['parent_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Category copyWith({
    String? id,
    String? name,
    String? icon,
    int? sortOrder,
    String? parentId,
  }) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        sortOrder: sortOrder ?? this.sortOrder,
        parentId: parentId ?? this.parentId,
        createdAt: createdAt,
      );

  static List<Category> defaultCategories() => [
        Category(id: 'figure', name: '手办', sortOrder: 1),
        Category(id: 'goods', name: '谷子', sortOrder: 2),
        Category(id: 'poster', name: '海报', sortOrder: 3),
        Category(id: 'cosplay', name: 'COS服', sortOrder: 4),
        Category(id: 'nendoroid', name: '黏土人', sortOrder: 5),
        Category(id: 'plush', name: '毛绒/抱枕', sortOrder: 6),
        Category(id: 'book', name: '画集/设定集', sortOrder: 7),
        Category(id: 'cd', name: 'CD/BD', sortOrder: 8),
        Category(id: 'other', name: '其他', sortOrder: 99),
      ];
}