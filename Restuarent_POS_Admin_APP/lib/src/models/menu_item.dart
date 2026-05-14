import 'dart:convert';

import 'sync_status.dart';

class MenuItem {
  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.isAvailable,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.synced,
    this.version = 1,
    this.deletedAt,
    this.imageUrl,
    this.preparationTimeMinutes,
    this.tags = const [],
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final double price;
  final String? imageUrl;
  final bool isAvailable;
  final int? preparationTimeMinutes;
  final List<String> tags;
  final SyncStatus syncStatus;
  final int version;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  MenuItem copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    double? price,
    String? imageUrl,
    bool? isAvailable,
    int? preparationTimeMinutes,
    List<String>? tags,
    SyncStatus? syncStatus,
    int? version,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      preparationTimeMinutes:
          preparationTimeMinutes ?? this.preparationTimeMinutes,
      tags: tags ?? this.tags,
      syncStatus: syncStatus ?? this.syncStatus,
      version: version ?? this.version,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable ? 1 : 0,
      'preparationTimeMinutes': preparationTimeMinutes,
      'tags': jsonEncode(tags),
      'syncStatus': syncStatus.value,
      'version': version,
      'deletedAt': deletedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'preparationTimeMinutes': preparationTimeMinutes,
      'tags': tags,
      'syncStatus': syncStatus.value,
      'version': version,
      'deletedAt': deletedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MenuItem.fromMap(Map<String, Object?> map) {
    return MenuItem(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
      price: (map['price'] as num).toDouble(),
      imageUrl: map['imageUrl'] as String?,
      isAvailable: _decodeBool(map['isAvailable']),
      preparationTimeMinutes: map['preparationTimeMinutes'] as int?,
      tags: _decodeTags(map['tags']),
      syncStatus: SyncStatus.parse(map['syncStatus'] as String?),
      version: map['version'] as int? ?? 1,
      deletedAt: _tryParseDate(map['deletedAt'] as String?),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  static DateTime? _tryParseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static bool _decodeBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return true;
  }

  static List<String> _decodeTags(Object? rawTags) {
    if (rawTags is List) {
      return rawTags.map((tag) => tag.toString()).toList(growable: false);
    }
    if (rawTags is! String || rawTags.trim().isEmpty) return [];
    final decoded = jsonDecode(rawTags);
    if (decoded is List) {
      return decoded.map((tag) => tag.toString()).toList(growable: false);
    }
    return [];
  }
}
