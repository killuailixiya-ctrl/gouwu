class Series {
  final String id;
  final String name;
  final String? aliases;
  final String? coverImage;
  final int sortOrder;
  final DateTime createdAt;

  Series({
    required this.id,
    required this.name,
    this.aliases,
    this.coverImage,
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'aliases': aliases,
        'cover_image': coverImage,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  factory Series.fromMap(Map<String, dynamic> map) => Series(
        id: map['id'] as String,
        name: map['name'] as String,
        aliases: map['aliases'] as String?,
        coverImage: map['cover_image'] as String?,
        sortOrder: map['sort_order'] as int? ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Series copyWith({
    String? id,
    String? name,
    String? aliases,
    String? coverImage,
    bool clearCoverImage = false,
    int? sortOrder,
  }) =>
      Series(
        id: id ?? this.id,
        name: name ?? this.name,
        aliases: aliases ?? this.aliases,
        coverImage: clearCoverImage ? null : (coverImage ?? this.coverImage),
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
      );

  List<String> get aliasList {
    if (aliases == null || aliases!.isEmpty) return [];
    try {
      return (aliases!.split(',').map((e) => e.trim()).toList());
    } catch (_) {
      return [];
    }
  }
}