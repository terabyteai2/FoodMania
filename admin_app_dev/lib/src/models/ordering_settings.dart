class DiscountPreset {
  const DiscountPreset({
    required this.id,
    required this.label,
    required this.kind,
    required this.value,
  });

  final String id;
  final String label;
  final String kind;
  final double value;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'kind': kind,
    'value': value,
  };

  factory DiscountPreset.fromJson(Map<String, Object?> json) => DiscountPreset(
    id: json['id']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    kind: json['kind']?.toString() ?? 'percent',
    value: _double(json['value']),
  );
}

class OrderingSettings {
  const OrderingSettings({
    this.vatRatePercent = 0,
    this.serviceChargePercent = 0,
    this.discountPresets = const [],
    this.dailySalesTarget,
  });

  final double vatRatePercent;
  final double serviceChargePercent;
  final List<DiscountPreset> discountPresets;

  /// Owner-configured daily sales target (৳) for Control Tower's pace card.
  /// Null = not configured, so consumers can fall back to their own default.
  final double? dailySalesTarget;

  Map<String, Object?> toJson() => {
    'vatRatePercent': vatRatePercent,
    'serviceChargePercent': serviceChargePercent,
    'discountPresets': discountPresets
        .map((preset) => preset.toJson())
        .toList(growable: false),
    'dailySalesTarget': dailySalesTarget,
  };

  factory OrderingSettings.fromJson(Map<String, Object?> json) =>
      OrderingSettings(
        vatRatePercent: _double(json['vatRatePercent']),
        serviceChargePercent: _double(json['serviceChargePercent']),
        discountPresets: _mapList(
          json['discountPresets'],
          DiscountPreset.fromJson,
        ),
        dailySalesTarget: _nullableDouble(json['dailySalesTarget']),
      );
}

List<T> _mapList<T>(Object? raw, T Function(Map<String, Object?>) mapper) {
  if (raw is! List) return <T>[];
  return raw
      .whereType<Map>()
      .map((item) => mapper(Map<String, Object?>.from(item)))
      .toList(growable: false);
}

double _double(Object? raw) =>
    raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;

double? _nullableDouble(Object? raw) => raw == null ? null : _double(raw);
