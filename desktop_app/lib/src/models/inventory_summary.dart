class InventorySummary {
  InventorySummary({
    required this.asOf,
    required this.stockValueBdt,
    required this.varianceTodayBdt,
    required this.varianceItemCount,
    required this.alerts,
    required this.categories,
    required this.items,
  });

  final DateTime asOf;
  final double stockValueBdt;
  final double varianceTodayBdt;
  final int varianceItemCount;
  final int alerts;
  final List<InventoryCategoryBucket> categories;
  final List<InventorySummaryItem> items;

  factory InventorySummary.fromJson(Map<String, Object?> json) {
    return InventorySummary(
      asOf: _parseDate(json['asOf']),
      stockValueBdt: _parseDouble(json['stockValueBdt']),
      varianceTodayBdt: _parseDouble(json['varianceTodayBdt']),
      varianceItemCount: _parseInt(json['varianceItemCount']),
      alerts: _parseInt(json['alerts']),
      categories: ((json['categories'] as List?) ?? const [])
          .whereType<Map>()
          .map((row) => InventoryCategoryBucket.fromJson(row.cast<String, Object?>()))
          .toList(growable: false),
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((row) => InventorySummaryItem.fromJson(row.cast<String, Object?>()))
          .toList(growable: false),
    );
  }
}

class InventoryCategoryBucket {
  InventoryCategoryBucket({
    required this.key,
    required this.labelEn,
    required this.labelBn,
    required this.count,
  });

  final String key;
  final String labelEn;
  final String labelBn;
  final int count;

  factory InventoryCategoryBucket.fromJson(Map<String, Object?> json) {
    return InventoryCategoryBucket(
      key: (json['key'] as String?) ?? '',
      labelEn: (json['labelEn'] as String?) ?? '',
      labelBn: (json['labelBn'] as String?) ?? '',
      count: _parseInt(json['count']),
    );
  }
}

class InventorySummaryItem {
  InventorySummaryItem({
    required this.id,
    required this.nameEn,
    required this.nameBn,
    required this.category,
    required this.unit,
    required this.onHand,
    required this.minThreshold,
    required this.todayIn,
    required this.todayOut,
    required this.todaySpendBdt,
    required this.varianceQty,
    required this.varianceStatus,
    required this.costPerUnit,
  });

  final String id;
  final String nameEn;
  final String nameBn;
  final String category;
  final String unit;
  final double onHand;
  final double minThreshold;
  final double todayIn;
  final double todayOut;
  final double todaySpendBdt;
  final double varianceQty;
  final String varianceStatus;
  final double costPerUnit;

  bool get isOut => varianceStatus == 'out';
  bool get isLow => varianceStatus == 'low';
  bool get hasVariance => varianceStatus == 'variance';

  factory InventorySummaryItem.fromJson(Map<String, Object?> json) {
    return InventorySummaryItem(
      id: (json['id'] as String?) ?? '',
      nameEn: (json['nameEn'] as String?) ?? '',
      nameBn: (json['nameBn'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      unit: (json['unit'] as String?) ?? 'pcs',
      onHand: _parseDouble(json['onHand']),
      minThreshold: _parseDouble(json['minThreshold']),
      todayIn: _parseDouble(json['todayIn']),
      todayOut: _parseDouble(json['todayOut']),
      todaySpendBdt: _parseDouble(json['todaySpendBdt']),
      varianceQty: _parseDouble(json['varianceQty']),
      varianceStatus: (json['varianceStatus'] as String?) ?? 'ok',
      costPerUnit: _parseDouble(json['costPerUnit']),
    );
  }
}

double _parseDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _parseInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime _parseDate(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}
