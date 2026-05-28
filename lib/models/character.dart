class Character {
  final String id;
  final String name;
  final String? aliases;
  final String seriesId;
  final String? avatarPath;
  final int sortOrder;
  final DateTime createdAt;

  Character({
    required this.id,
    required this.name,
    this.aliases,
    required this.seriesId,
    this.avatarPath,
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'aliases': aliases,
        'series_id': seriesId,
        'avatar_path': avatarPath,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  factory Character.fromMap(Map<String, dynamic> map) => Character(
        id: map['id'] as String,
        name: map['name'] as String,
        aliases: map['aliases'] as String?,
        seriesId: map['series_id'] as String,
        avatarPath: map['avatar_path'] as String?,
        sortOrder: map['sort_order'] as int? ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Character copyWith({
    String? id,
    String? name,
    String? aliases,
    String? seriesId,
    String? avatarPath,
    bool clearAvatar = false,
    int? sortOrder,
  }) =>
      Character(
        id: id ?? this.id,
        name: name ?? this.name,
        aliases: aliases ?? this.aliases,
        seriesId: seriesId ?? this.seriesId,
        avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
      );

  List<String> get aliasList {
    if (aliases == null || aliases!.isEmpty) return [];
    try {
      return aliases!.split(',').map((e) => e.trim()).toList();
    } catch (_) {
      return [];
    }
  }
}