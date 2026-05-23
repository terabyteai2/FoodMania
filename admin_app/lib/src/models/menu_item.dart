import 'dart:convert';

import '../core/localization/app_strings.dart';
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
    this.nameEn = '',
    this.nameBn = '',
    this.descriptionEn = '',
    this.descriptionBn = '',
    this.categoryEn = '',
    this.categoryBn = '',
    this.syncStatus = SyncStatus.synced,
    this.version = 1,
    this.deletedAt,
    this.imageUrl,
    this.preparationTimeMinutes,
    this.tags = const [],
  });

  final String id;
  final String name;
  final String nameEn;
  final String nameBn;
  final String description;
  final String descriptionEn;
  final String descriptionBn;
  final String category;
  final String categoryEn;
  final String categoryBn;
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
    String? nameEn,
    String? nameBn,
    String? description,
    String? descriptionEn,
    String? descriptionBn,
    String? category,
    String? categoryEn,
    String? categoryBn,
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
      nameEn: nameEn ?? this.nameEn,
      nameBn: nameBn ?? this.nameBn,
      description: description ?? this.description,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      descriptionBn: descriptionBn ?? this.descriptionBn,
      category: category ?? this.category,
      categoryEn: categoryEn ?? this.categoryEn,
      categoryBn: categoryBn ?? this.categoryBn,
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
      'nameEn': nameEn,
      'nameBn': nameBn,
      'description': description,
      'descriptionEn': descriptionEn,
      'descriptionBn': descriptionBn,
      'category': category,
      'categoryEn': categoryEn,
      'categoryBn': categoryBn,
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
      'nameEn': nameEn,
      'nameBn': nameBn,
      'description': description,
      'descriptionEn': descriptionEn,
      'descriptionBn': descriptionBn,
      'category': category,
      'categoryEn': categoryEn,
      'categoryBn': categoryBn,
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
    final name = map['name'] as String;
    final description = map['description'] as String? ?? '';
    final category = map['category'] as String? ?? 'General';
    return MenuItem(
      id: map['id'] as String,
      name: name,
      nameEn: _text(map['nameEn']) ?? name,
      nameBn: _text(map['nameBn']) ?? _splitLegacy(name).$2,
      description: description,
      descriptionEn: _text(map['descriptionEn']) ?? description,
      descriptionBn:
          _text(map['descriptionBn']) ?? _splitLegacy(description).$2,
      category: category,
      categoryEn: _text(map['categoryEn']) ?? category,
      categoryBn: _text(map['categoryBn']) ?? _splitLegacy(category).$2,
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

  String localizedName(AppLanguage language) {
    return _localized(language, nameEn, nameBn, name);
  }

  String localizedDescription(AppLanguage language) {
    return _localized(language, descriptionEn, descriptionBn, description);
  }

  String localizedCategory(AppLanguage language) {
    return _localized(language, categoryEn, categoryBn, category);
  }

  String searchText(AppLanguage language) {
    return [
      name,
      nameEn,
      nameBn,
      description,
      descriptionEn,
      descriptionBn,
      category,
      categoryEn,
      categoryBn,
      localizedName(language),
      localizedDescription(language),
      localizedCategory(language),
    ].join(' ').toLowerCase();
  }

  static String _localized(
    AppLanguage language,
    String english,
    String bangla,
    String fallback,
  ) {
    final primary = language == AppLanguage.bn ? bangla : english;
    if (primary.trim().isNotEmpty) return primary.trim();
    final secondary = language == AppLanguage.bn ? english : bangla;
    if (secondary.trim().isNotEmpty) return secondary.trim();
    return fallback.trim();
  }

  static String? _text(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static (String, String) _splitLegacy(String value) {
    if (!value.contains('/')) return (value.trim(), '');
    final parts = value.split('/');
    return (parts.first.trim(), parts.skip(1).join('/').trim());
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
