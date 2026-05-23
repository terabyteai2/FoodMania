class DailyReport {
  DailyReport({
    required this.date,
    required this.unexplainedVarianceBdt,
    required this.varianceItemCount,
    required this.headlineEn,
    required this.headlineBn,
    required this.breakdown,
    required this.reorderSuggestions,
  });

  final String date;
  final double unexplainedVarianceBdt;
  final int varianceItemCount;
  final String headlineEn;
  final String headlineBn;
  final List<VarianceBreakdown> breakdown;
  final List<ReorderSuggestion> reorderSuggestions;

  factory DailyReport.fromJson(Map<String, Object?> json) {
    return DailyReport(
      date: (json['date'] as String?) ?? '',
      unexplainedVarianceBdt: _parseDouble(json['unexplainedVarianceBdt']),
      varianceItemCount: _parseInt(json['varianceItemCount']),
      headlineEn: (json['headlineEn'] as String?) ?? '',
      headlineBn: (json['headlineBn'] as String?) ?? '',
      breakdown: ((json['breakdown'] as List?) ?? const [])
          .whereType<Map>()
          .map((row) => VarianceBreakdown.fromJson(row.cast<String, Object?>()))
          .toList(growable: false),
      reorderSuggestions: ((json['reorderSuggestions'] as List?) ?? const [])
          .whereType<Map>()
          .map((row) => ReorderSuggestion.fromJson(row.cast<String, Object?>()))
          .toList(growable: false),
    );
  }
}

class VarianceBreakdown {
  VarianceBreakdown({
    required this.itemId,
    required this.nameEn,
    required this.nameBn,
    required this.varianceQty,
    required this.unit,
    required this.expectedQty,
    required this.actualQty,
    required this.recurringWeeks,
    required this.noteEn,
    required this.varianceBdt,
  });

  final String itemId;
  final String nameEn;
  final String nameBn;
  final double varianceQty;
  final String unit;
  final double expectedQty;
  final double actualQty;
  final int recurringWeeks;
  final String noteEn;
  final double varianceBdt;

  factory VarianceBreakdown.fromJson(Map<String, Object?> json) {
    return VarianceBreakdown(
      itemId: (json['itemId'] as String?) ?? '',
      nameEn: (json['nameEn'] as String?) ?? '',
      nameBn: (json['nameBn'] as String?) ?? '',
      varianceQty: _parseDouble(json['varianceQty']),
      unit: (json['unit'] as String?) ?? 'pcs',
      expectedQty: _parseDouble(json['expectedQty']),
      actualQty: _parseDouble(json['actualQty']),
      recurringWeeks: _parseInt(json['recurringWeeks']),
      noteEn: (json['noteEn'] as String?) ?? '',
      varianceBdt: _parseDouble(json['varianceBdt']),
    );
  }
}

class ReorderSuggestion {
  ReorderSuggestion({
    required this.itemId,
    required this.nameEn,
    required this.nameBn,
    required this.qtyToOrder,
    required this.unit,
    required this.ctaEn,
  });

  final String itemId;
  final String nameEn;
  final String nameBn;
  final double qtyToOrder;
  final String unit;
  final String ctaEn;

  factory ReorderSuggestion.fromJson(Map<String, Object?> json) {
    return ReorderSuggestion(
      itemId: (json['itemId'] as String?) ?? '',
      nameEn: (json['nameEn'] as String?) ?? '',
      nameBn: (json['nameBn'] as String?) ?? '',
      qtyToOrder: _parseDouble(json['qtyToOrder']),
      unit: (json['unit'] as String?) ?? 'pcs',
      ctaEn: (json['ctaEn'] as String?) ?? '',
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
