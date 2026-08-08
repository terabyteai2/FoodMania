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
    this.costPrice,
    this.shortCode,
    this.isFavorite = false,
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

  /// Owner-entered ingredient cost; null when unset. Drives Review-tab
  /// food-cost % / margin. Preserved on sync so it isn't wiped by round-trips.
  final double? costPrice;

  /// Serial-by-default, editable short code for fast numeric item lookup in the
  /// POS (the ⚡ search toggle). Null until the backend assigns a serial.
  final int? shortCode;

  /// Outlet-wide favourite flag — favourited items float to the top of the POS
  /// item picker. Defaults false ("not favourited").
  final bool isFavorite;
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
    double? costPrice,
    bool clearCostPrice = false,
    int? shortCode,
    bool clearShortCode = false,
    bool? isFavorite,
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
      costPrice: clearCostPrice ? null : costPrice ?? this.costPrice,
      shortCode: clearShortCode ? null : shortCode ?? this.shortCode,
      isFavorite: isFavorite ?? this.isFavorite,
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
      'costPrice': costPrice,
      'shortCode': shortCode,
      'isFavorite': isFavorite ? 1 : 0,
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
      'costPrice': costPrice,
      'shortCode': shortCode,
      'isFavorite': isFavorite,
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
      costPrice: (map['costPrice'] as num?)?.toDouble(),
      shortCode: (map['shortCode'] as num?)?.toInt(),
      isFavorite: _decodeFlag(map['isFavorite']),
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

  /// Like [_decodeBool] but defaults to false for missing/unknown values —
  /// used for opt-in flags such as [isFavorite].
  static bool _decodeFlag(Object? value) {
    if (value is bool) return value;
    if (value is num) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
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

  MenuItemExtras get extras => MenuItemExtras.fromTags(tags);
}

/// Lightweight metadata sidecar parsed out of the [MenuItem.tags] list. Tags
/// use prefixes so we don't need a backend schema change:
///   `icon:<key>`           – placeholder icon hint, e.g. `icon:pizza`
///   `discount:percent:<n>` – percent-off discount
///   `discount:flat:<n>`    – flat-amount discount
///   `inc:<text>`           – set-meal included item line
///   `option:<name>:<n>`    – required size/variant with price delta
///   `size:<name>:<n>`      – legacy alias for option
///   `addon:<price>:<name>` – add-on entry
class MenuItemExtras {
  const MenuItemExtras({
    this.iconKey,
    this.discountPercent,
    this.discountFlat,
    this.includes = const [],
    this.options = const [],
    this.addOns = const [],
    this.passthrough = const [],
  });

  final String? iconKey;
  final double? discountPercent;
  final double? discountFlat;
  final List<String> includes;
  final List<MenuOption> options;
  final List<MenuAddOn> addOns;

  /// Tags we didn't recognise — kept so toTags() round-trips cleanly.
  final List<String> passthrough;

  bool get hasDiscount =>
      (discountPercent != null && discountPercent! > 0) ||
      (discountFlat != null && discountFlat! > 0);

  String discountBadgeLabel() {
    if (discountPercent != null && discountPercent! > 0) {
      final n = discountPercent!;
      if (n == n.roundToDouble()) return '-${n.toInt()}%';
      return '-${n.toStringAsFixed(1)}%';
    }
    if (discountFlat != null && discountFlat! > 0) {
      final n = discountFlat!;
      if (n == n.roundToDouble()) return '-৳${n.toInt()}';
      return '-৳${n.toStringAsFixed(2)}';
    }
    return '';
  }

  double discountedPrice(double basePrice) {
    if (discountPercent != null && discountPercent! > 0) {
      final off = basePrice * (discountPercent!.clamp(0, 100) / 100.0);
      final v = basePrice - off;
      return v < 0 ? 0 : v;
    }
    if (discountFlat != null && discountFlat! > 0) {
      final v = basePrice - discountFlat!;
      return v < 0 ? 0 : v;
    }
    return basePrice;
  }

  factory MenuItemExtras.fromTags(List<String> tags) {
    String? iconKey;
    double? discountPercent;
    double? discountFlat;
    final includes = <String>[];
    final options = <MenuOption>[];
    final addOns = <MenuAddOn>[];
    final passthrough = <String>[];
    for (final raw in tags) {
      final tag = raw.trim();
      if (tag.isEmpty) continue;
      final lower = tag.toLowerCase();
      if (lower.startsWith('icon:')) {
        final v = tag.substring(5).trim();
        if (v.isNotEmpty) iconKey = v;
      } else if (lower.startsWith('discount:percent:')) {
        discountPercent = double.tryParse(tag.substring(17).trim());
      } else if (lower.startsWith('discount:flat:')) {
        discountFlat = double.tryParse(tag.substring(14).trim());
      } else if (lower.startsWith('inc:')) {
        final v = tag.substring(4).trim();
        if (v.isNotEmpty) includes.add(v);
      } else if (lower.startsWith('option:')) {
        final option = MenuOption.parse(tag.substring(7));
        if (option != null) options.add(option);
      } else if (lower.startsWith('size:')) {
        final option = MenuOption.parse(tag.substring(5));
        if (option != null) options.add(option);
      } else if (lower.startsWith('addon:')) {
        final body = tag.substring(6);
        final i = body.indexOf(':');
        if (i > 0) {
          final price = double.tryParse(body.substring(0, i).trim()) ?? 0;
          final name = body.substring(i + 1).trim();
          if (name.isNotEmpty) addOns.add(MenuAddOn(name: name, price: price));
        }
      } else {
        passthrough.add(tag);
      }
    }
    return MenuItemExtras(
      iconKey: iconKey,
      discountPercent: discountPercent,
      discountFlat: discountFlat,
      includes: includes,
      options: _dedupeOptions(options),
      addOns: addOns,
      passthrough: passthrough,
    );
  }

  List<String> toTags() {
    final out = <String>[];
    if (iconKey != null && iconKey!.isNotEmpty) {
      out.add('icon:$iconKey');
    }
    if (discountPercent != null && discountPercent! > 0) {
      out.add('discount:percent:${_fmt(discountPercent!)}');
    } else if (discountFlat != null && discountFlat! > 0) {
      out.add('discount:flat:${_fmt(discountFlat!)}');
    }
    for (final inc in includes) {
      final v = inc.trim();
      if (v.isNotEmpty) out.add('inc:$v');
    }
    for (final option in options) {
      final name = option.name.trim();
      if (name.isEmpty) continue;
      if (option.hasPriceDelta) {
        out.add('option:$name:${_fmt(option.priceDelta)}');
      } else {
        out.add('option:$name');
      }
    }
    for (final addon in addOns) {
      final name = addon.name.trim();
      if (name.isEmpty) continue;
      out.add('addon:${_fmt(addon.price)}:$name');
    }
    out.addAll(passthrough);
    return out;
  }

  MenuItemExtras copyWith({
    String? iconKey,
    double? discountPercent,
    double? discountFlat,
    bool clearDiscount = false,
    List<String>? includes,
    List<MenuOption>? options,
    List<MenuAddOn>? addOns,
    List<String>? passthrough,
  }) {
    return MenuItemExtras(
      iconKey: iconKey ?? this.iconKey,
      discountPercent: clearDiscount
          ? null
          : (discountPercent ?? this.discountPercent),
      discountFlat: clearDiscount ? null : (discountFlat ?? this.discountFlat),
      includes: includes ?? this.includes,
      options: options ?? this.options,
      addOns: addOns ?? this.addOns,
      passthrough: passthrough ?? this.passthrough,
    );
  }

  static List<MenuOption> _dedupeOptions(List<MenuOption> options) {
    final seen = <String>{};
    final out = <MenuOption>[];
    for (final option in options) {
      final key =
          '${option.name.trim().toLowerCase()}|${option.priceDelta.toStringAsFixed(2)}';
      if (seen.add(key)) out.add(option);
    }
    return out;
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}

class MenuOption {
  const MenuOption({required this.name, this.priceDelta = 0});

  final String name;
  final double priceDelta;

  bool get hasPriceDelta => priceDelta.abs() >= 0.005;

  static MenuOption? parse(String body) {
    final parts = body.split(':').map((part) => part.trim()).toList();
    parts.removeWhere((part) => part.isEmpty);
    if (parts.isEmpty) return null;
    if (parts.length == 1) return MenuOption(name: parts.first);
    final firstPrice = double.tryParse(parts.first);
    if (firstPrice != null) {
      final name = parts.skip(1).join(': ').trim();
      return name.isEmpty
          ? null
          : MenuOption(name: name, priceDelta: firstPrice);
    }
    final lastPrice = double.tryParse(parts.last);
    if (lastPrice != null) {
      final name = parts.take(parts.length - 1).join(': ').trim();
      return name.isEmpty
          ? null
          : MenuOption(name: name, priceDelta: lastPrice);
    }
    return MenuOption(name: parts.join(': '));
  }
}

class MenuAddOn {
  const MenuAddOn({required this.name, required this.price});
  final String name;
  final double price;
}
