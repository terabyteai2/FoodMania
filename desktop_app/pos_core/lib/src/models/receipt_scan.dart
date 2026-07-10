/// What the backend decided a scanned document is — a supplier bill (stock-in)
/// or a stock-count sheet. The unified `/inventory/scan` endpoint always returns
/// one of these so the app can route the user to the right screen.
enum StockScanCategory {
  stockIn,
  count;

  /// Wire value sent to / returned by the backend (`stock_in` / `count`).
  String get wire => this == StockScanCategory.stockIn ? 'stock_in' : 'count';

  static StockScanCategory? fromWire(Object? value) {
    switch (value) {
      case 'stock_in':
        return StockScanCategory.stockIn;
      case 'count':
        return StockScanCategory.count;
      default:
        return null;
    }
  }
}

class StockScanResult {
  StockScanResult({
    required this.category,
    required this.items,
    required this.provider,
    required this.pageCount,
    required this.warnings,
  });

  /// Resolved by the backend (LLM) — defaults to stock-in if absent/unknown.
  final StockScanCategory category;
  final List<ReceiptScanLine> items;
  final String provider;
  final int pageCount;
  final List<String> warnings;

  factory StockScanResult.fromJson(Map<String, Object?> json) {
    return StockScanResult(
      category:
          StockScanCategory.fromWire(json['category']) ??
          StockScanCategory.stockIn,
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
    this.matchedInventoryItemId,
  });

  final String nameEn;
  final String nameBn;
  final double qty;
  final String unit;
  final double unitPriceBdt;
  final double totalBdt;

  /// For count scans: the existing inventory item id this line matched, or null.
  /// Always null for stock-in lines.
  final String? matchedInventoryItemId;

  factory ReceiptScanLine.fromJson(Map<String, Object?> json) {
    final matched = (json['matchedInventoryItemId'] as String?)?.trim();
    return ReceiptScanLine(
      nameEn: (json['nameEn'] as String?) ?? '',
      nameBn: (json['nameBn'] as String?) ?? '',
      qty: _parseDouble(json['qty']),
      unit: (json['unit'] as String?) ?? 'pcs',
      unitPriceBdt: _parseDouble(json['unitPriceBdt']),
      totalBdt: _parseDouble(json['totalBdt']),
      matchedInventoryItemId: (matched != null && matched.isNotEmpty)
          ? matched
          : null,
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
