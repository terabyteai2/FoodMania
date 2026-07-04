class ReceiptScanResult {
  ReceiptScanResult({
    required this.items,
    required this.provider,
    required this.pageCount,
    required this.warnings,
  });

  final List<ReceiptScanLine> items;
  final String provider;
  final int pageCount;
  final List<String> warnings;

  factory ReceiptScanResult.fromJson(Map<String, Object?> json) {
    return ReceiptScanResult(
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((row) => ReceiptScanLine.fromJson(row.cast<String, Object?>()))
          .toList(growable: false),
      provider: (json['provider'] as String?) ?? '',
      pageCount: _parseInt(json['pageCount']),
      warnings: ((json['warnings'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

class ReceiptScanLine {
  ReceiptScanLine({
    required this.nameEn,
    required this.nameBn,
    required this.qty,
    required this.unit,
    required this.unitPriceBdt,
    required this.totalBdt,
  });

  final String nameEn;
  final String nameBn;
  final double qty;
  final String unit;
  final double unitPriceBdt;
  final double totalBdt;

  factory ReceiptScanLine.fromJson(Map<String, Object?> json) {
    return ReceiptScanLine(
      nameEn: (json['nameEn'] as String?) ?? '',
      nameBn: (json['nameBn'] as String?) ?? '',
      qty: _parseDouble(json['qty']),
      unit: (json['unit'] as String?) ?? 'pcs',
      unitPriceBdt: _parseDouble(json['unitPriceBdt']),
      totalBdt: _parseDouble(json['totalBdt']),
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
