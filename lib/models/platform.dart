class Platform {
  final String id;
  final String name;
  final String? icon;
  final String colorCode;
  final int sortOrder;
  final bool isActive;

  Platform({
    required this.id,
    required this.name,
    this.icon,
    required this.colorCode,
    this.sortOrder = 0,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color_code': colorCode,
        'sort_order': sortOrder,
        'is_active': isActive ? 1 : 0,
      };

  factory Platform.fromMap(Map<String, dynamic> map) => Platform(
        id: map['id'] as String,
        name: map['name'] as String,
        icon: map['icon'] as String?,
        colorCode: map['color_code'] as String,
        sortOrder: map['sort_order'] as int? ?? 0,
        isActive: (map['is_active'] as int?) == 1,
      );

  Platform copyWith({
    String? id,
    String? name,
    String? icon,
    String? colorCode,
    int? sortOrder,
    bool? isActive,
  }) =>
      Platform(
        id: id ?? this.id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        colorCode: colorCode ?? this.colorCode,
        sortOrder: sortOrder ?? this.sortOrder,
        isActive: isActive ?? this.isActive,
      );

  static List<Platform> defaultPlatforms() => [
        Platform(
          id: 'taobao',
          name: '淘宝',
          colorCode: '#FF5000',
          sortOrder: 1,
        ),
        Platform(
          id: 'pinduoduo',
          name: '拼多多',
          colorCode: '#E02E24',
          sortOrder: 2,
        ),
        Platform(
          id: 'bilibili',
          name: 'B站会员购',
          colorCode: '#FB7299',
          sortOrder: 3,
        ),
        Platform(
          id: 'xianyu',
          name: '闲鱼',
          colorCode: '#FFC300',
          sortOrder: 4,
        ),
        Platform(
          id: 'weidian',
          name: '微店',
          colorCode: '#07C160',
          sortOrder: 5,
        ),
        Platform(
          id: 'jd',
          name: '京东',
          colorCode: '#C91623',
          sortOrder: 6,
        ),
        Platform(
          id: 'other',
          name: '其他',
          colorCode: '#999999',
          sortOrder: 99,
        ),
      ];
}