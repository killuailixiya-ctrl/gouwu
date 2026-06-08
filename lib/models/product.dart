class Product {
  final String id;
  final String normalizedName;
  final String displayName;
  final String? categoryId;
  final String? seriesId;
  final String? characterId;
  final double avgPrice;
  final int totalOwned;
  final DateTime? firstBought;
  final DateTime? lastBought;
  final String? coverImage;
  final String? imageHash;
  final String? nameVector;
  final bool isFavorite;
  final String? notes;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.normalizedName,
    required this.displayName,
    this.categoryId,
    this.seriesId,
    this.characterId,
    this.avgPrice = 0,
    this.totalOwned = 1,
    this.firstBought,
    this.lastBought,
    this.coverImage,
    this.imageHash,
    this.nameVector,
    this.isFavorite = false,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'normalized_name': normalizedName,
        'display_name': displayName,
        'category_id': categoryId,
        'series_id': seriesId,
        'character_id': characterId,
        'avg_price': avgPrice,
        'total_owned': totalOwned,
        'first_bought': firstBought?.toIso8601String(),
        'last_bought': lastBought?.toIso8601String(),
        'cover_image': coverImage,
        'image_hash': imageHash,
        'name_vector': nameVector,
        'is_favorite': isFavorite ? 1 : 0,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as String,
        normalizedName: map['normalized_name'] as String,
        displayName: map['display_name'] as String,
        categoryId: map['category_id'] as String?,
        seriesId: map['series_id'] as String?,
        characterId: map['character_id'] as String?,
        avgPrice: (map['avg_price'] as num?)?.toDouble() ?? 0,
        totalOwned: map['total_owned'] as int? ?? 1,
        firstBought: map['first_bought'] != null
            ? DateTime.parse(map['first_bought'] as String)
            : null,
        lastBought: map['last_bought'] != null
            ? DateTime.parse(map['last_bought'] as String)
            : null,
        coverImage: map['cover_image'] as String?,
        imageHash: map['image_hash'] as String?,
        nameVector: map['name_vector'] as String?,
        isFavorite: (map['is_favorite'] as int?) == 1,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Product copyWith({
    String? id,
    String? normalizedName,
    String? displayName,
    String? categoryId,
    String? seriesId,
    String? characterId,
    double? avgPrice,
    int? totalOwned,
    DateTime? firstBought,
    DateTime? lastBought,
    String? coverImage,
    String? imageHash,
    String? nameVector,
    bool? isFavorite,
    String? notes,
  }) =>
      Product(
        id: id ?? this.id,
        normalizedName: normalizedName ?? this.normalizedName,
        displayName: displayName ?? this.displayName,
        categoryId: categoryId ?? this.categoryId,
        seriesId: seriesId ?? this.seriesId,
        characterId: characterId ?? this.characterId,
        avgPrice: avgPrice ?? this.avgPrice,
        totalOwned: totalOwned ?? this.totalOwned,
        firstBought: firstBought ?? this.firstBought,
        lastBought: lastBought ?? this.lastBought,
        coverImage: coverImage ?? this.coverImage,
        imageHash: imageHash ?? this.imageHash,
        nameVector: nameVector ?? this.nameVector,
        isFavorite: isFavorite ?? this.isFavorite,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}