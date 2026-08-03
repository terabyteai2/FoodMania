import '../core/localization/app_strings.dart';

class OrderItem {
  OrderItem({
    required this.id,
    required this.orderId,
    required this.menuItemId,
    required this.name,
    required this.qty,
    required this.price,
    required this.lineTotal,
    this.nameEn = '',
    this.nameBn = '',
    this.costPriceSnapshot = 0,
    this.note,
    this.kotBatchId,
    this.kotSentAt,
    this.parcel = false,
  });

  final String id;
  final String orderId;
  final String menuItemId;
  final String name;
  final String nameEn;
  final String nameBn;
  final int qty;
  final double price;
  final double lineTotal;
  final double costPriceSnapshot;
  final String? note;
  final String? kotBatchId;
  final DateTime? kotSentAt;
  final bool parcel;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'menuItemId': menuItemId,
      'name': name,
      'nameEn': nameEn,
      'nameBn': nameBn,
      'qty': qty,
      'price': price,
      'lineTotal': lineTotal,
      'costPriceSnapshot': costPriceSnapshot,
      'note': note,
      'kotBatchId': kotBatchId,
      'kotSentAt': kotSentAt?.toIso8601String(),
      'parcel': parcel ? 1 : 0,
    };
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'menuItemId': menuItemId,
      'name': name,
      'nameEn': nameEn,
      'nameBn': nameBn,
      'qty': qty,
      'price': price,
      'lineTotal': lineTotal,
      'costPriceSnapshot': costPriceSnapshot,
      'note': note,
      'kotBatchId': kotBatchId,
      'kotSentAt': kotSentAt?.toIso8601String(),
      'parcel': parcel,
    };
  }

  factory OrderItem.fromMap(Map<String, Object?> map) {
    final name = _text(map['name']) ?? '';
    final legacySplit = _splitLegacy(name);
    return OrderItem(
      id: _text(map['id']) ?? '',
      orderId: _text(map['orderId']) ?? '',
      menuItemId: _text(map['menuItemId']) ?? '',
      name: name,
      nameEn: _text(map['nameEn']) ?? legacySplit.$1,
      nameBn: _text(map['nameBn']) ?? legacySplit.$2,
      qty: _num(map['qty'], fallback: 1).toInt(),
      price: _num(map['price']),
      lineTotal: _num(map['lineTotal']),
      costPriceSnapshot: _num(map['costPriceSnapshot']),
      note: _text(map['note']),
      kotBatchId: _text(map['kotBatchId']),
      kotSentAt: DateTime.tryParse(map['kotSentAt']?.toString() ?? ''),
      parcel: map['parcel'] == true || map['parcel'] == 1,
    );
  }

  String localizedName(AppLanguage language) {
    final primary = language == AppLanguage.bn ? nameBn : nameEn;
    if (primary.trim().isNotEmpty) return primary.trim();
    final secondary = language == AppLanguage.bn ? nameEn : nameBn;
    if (secondary.trim().isNotEmpty) return secondary.trim();
    return name.trim();
  }

  static String? _text(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static double _num(Object? value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }

  static (String, String) _splitLegacy(String value) {
    if (!value.contains('/')) return (value.trim(), '');
    final parts = value.split('/');
    return (parts.first.trim(), parts.skip(1).join('/').trim());
  }
}

class OrderRequestItem {
  OrderRequestItem({
    required this.menuItemId,
    required this.qty,
    this.note,
    this.existingOrderItemId,
    this.unitPrice,
    this.lineTotal,
    this.nameSuffix,
    this.nameOverride,
    this.nameEnOverride,
    this.nameBnOverride,
    this.parcel,
  });

  final String menuItemId;
  final int qty;
  final String? note;
  final String? existingOrderItemId;
  final double? unitPrice;
  final double? lineTotal;
  final String? nameSuffix;
  final String? nameOverride;
  final String? nameEnOverride;
  final String? nameBnOverride;

  /// True = pack to go; false = dine-in line; null = keep the existing flag.
  final bool? parcel;

  factory OrderRequestItem.fromJson(Map<String, Object?> json) {
    final rawId = json['menuItemId'] ?? json['id'];
    final rawQty = json['qty'] ?? json['quantity'];
    if (rawId is! String || rawId.trim().isEmpty) {
      throw FormatException('Each item must include a menuItemId.');
    }
    if (rawQty is! num) {
      throw FormatException('Each item must include a numeric qty.');
    }
    return OrderRequestItem(
      menuItemId: rawId.trim(),
      qty: rawQty.toInt(),
      note: json['note']?.toString(),
      existingOrderItemId: json['existingOrderItemId']?.toString(),
      unitPrice: _jsonDouble(json['unitPrice'] ?? json['price']),
      lineTotal: _jsonDouble(json['lineTotal']),
      nameSuffix: json['nameSuffix']?.toString(),
      nameOverride: json['name']?.toString(),
      nameEnOverride: json['nameEn']?.toString(),
      nameBnOverride: json['nameBn']?.toString(),
      parcel: json['parcel'] is bool ? json['parcel'] as bool : null,
    );
  }

  static double? _jsonDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
