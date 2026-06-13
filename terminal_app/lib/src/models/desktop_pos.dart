import 'dart:convert';

class PosFloorTable {
  const PosFloorTable({
    required this.id,
    required this.label,
    this.seats = 4,
    this.sortOrder = 0,
  });

  final String id;
  final String label;
  final int seats;
  final int sortOrder;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'seats': seats,
    'sortOrder': sortOrder,
  };

  factory PosFloorTable.fromJson(Map<String, Object?> json) => PosFloorTable(
    id: json['id']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    seats: _int(json['seats'], fallback: 4),
    sortOrder: _int(json['sortOrder']),
  );
}

class PosFloorZone {
  const PosFloorZone({
    required this.id,
    required this.name,
    required this.tables,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final int sortOrder;
  final List<PosFloorTable> tables;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'sortOrder': sortOrder,
    'tables': tables.map((table) => table.toJson()).toList(growable: false),
  };

  factory PosFloorZone.fromJson(Map<String, Object?> json) => PosFloorZone(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Main',
    sortOrder: _int(json['sortOrder']),
    tables: _mapList(json['tables'], PosFloorTable.fromJson),
  );
}

class PosDiscountPreset {
  const PosDiscountPreset({
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

  factory PosDiscountPreset.fromJson(Map<String, Object?> json) =>
      PosDiscountPreset(
        id: json['id']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        kind: json['kind']?.toString() ?? 'percent',
        value: _double(json['value']),
      );
}

class DesktopPosSettings {
  const DesktopPosSettings({
    required this.floorLayout,
    this.vatRatePercent = 0,
    this.serviceChargePercent = 0,
    this.discountPresets = const [],
    this.dailySalesTarget,
  });

  final List<PosFloorZone> floorLayout;
  final double vatRatePercent;
  final double serviceChargePercent;
  final List<PosDiscountPreset> discountPresets;

  /// Owner-configured daily sales target (৳) for Control Tower's pace card.
  /// Null = not configured → consumers fall back to their own default.
  final double? dailySalesTarget;

  int get tableCount =>
      floorLayout.fold(0, (total, zone) => total + zone.tables.length);

  Map<String, Object?> toJson() => {
    'floorLayout': floorLayout
        .map((zone) => zone.toJson())
        .toList(growable: false),
    'vatRatePercent': vatRatePercent,
    'serviceChargePercent': serviceChargePercent,
    'discountPresets': discountPresets
        .map((preset) => preset.toJson())
        .toList(growable: false),
    'dailySalesTarget': dailySalesTarget,
  };

  factory DesktopPosSettings.fromJson(
    Map<String, Object?> json, {
    int fallbackTableCount = 10,
  }) {
    final zones = _mapList(json['floorLayout'], PosFloorZone.fromJson);
    return DesktopPosSettings(
      floorLayout: zones.isEmpty ? fallbackFloor(fallbackTableCount) : zones,
      vatRatePercent: _double(json['vatRatePercent']),
      serviceChargePercent: _double(json['serviceChargePercent']),
      discountPresets: _mapList(
        json['discountPresets'],
        PosDiscountPreset.fromJson,
      ),
      dailySalesTarget: _nullableDouble(json['dailySalesTarget']),
    );
  }

  static List<PosFloorZone> fallbackFloor(int count) => [
    PosFloorZone(
      id: 'main',
      name: 'Main',
      tables: [
        for (var index = 1; index <= count.clamp(0, 200); index++)
          PosFloorTable(
            id: 'table-$index',
            label: '$index',
            sortOrder: index - 1,
          ),
      ],
    ),
  ];
}

class PosShift {
  const PosShift({
    required this.id,
    required this.status,
    required this.openingCash,
    required this.openingDenominations,
    required this.openedAt,
    this.expectedCash,
    this.countedCash,
    this.varianceCash,
    this.closingDenominations = const {},
    this.openedByAccountId,
    this.closedByAccountId,
    this.closedAt,
  });

  final String id;
  final String status;
  final double openingCash;
  final double? expectedCash;
  final double? countedCash;
  final double? varianceCash;
  final Map<String, int> openingDenominations;
  final Map<String, int> closingDenominations;
  final String? openedByAccountId;
  final String? closedByAccountId;
  final DateTime openedAt;
  final DateTime? closedAt;

  bool get isOpen => status == 'open';

  Map<String, Object?> toJson() => {
    'id': id,
    'status': status,
    'openingCash': openingCash,
    'expectedCash': expectedCash,
    'countedCash': countedCash,
    'varianceCash': varianceCash,
    'openingDenominations': openingDenominations,
    'closingDenominations': closingDenominations,
    'openedByAccountId': openedByAccountId,
    'closedByAccountId': closedByAccountId,
    'openedAt': openedAt.toIso8601String(),
    'closedAt': closedAt?.toIso8601String(),
  };

  factory PosShift.fromJson(Map<String, Object?> json) => PosShift(
    id: json['id']?.toString() ?? '',
    status: json['status']?.toString() ?? 'open',
    openingCash: _double(json['openingCash']),
    expectedCash: _nullableDouble(json['expectedCash']),
    countedCash: _nullableDouble(json['countedCash']),
    varianceCash: _nullableDouble(json['varianceCash']),
    openingDenominations: _intMap(json['openingDenominations']),
    closingDenominations: _intMap(json['closingDenominations']),
    openedByAccountId: json['openedByAccountId']?.toString(),
    closedByAccountId: json['closedByAccountId']?.toString(),
    openedAt: _date(json['openedAt']) ?? DateTime.now(),
    closedAt: _date(json['closedAt']),
  );

  Map<String, Object?> toMap() => {
    ...toJson(),
    'openingDenominations': jsonEncode(openingDenominations),
    'closingDenominations': jsonEncode(closingDenominations),
  };

  factory PosShift.fromMap(Map<String, Object?> map) => PosShift.fromJson({
    ...map,
    'openingDenominations': _json(map['openingDenominations']),
    'closingDenominations': _json(map['closingDenominations']),
  });
}

class PosSettlementLine {
  const PosSettlementLine({
    required this.eventId,
    required this.paymentMethod,
    required this.amount,
    this.payerLabel,
  });

  final String eventId;
  final String paymentMethod;
  final double amount;
  final String? payerLabel;

  Map<String, Object?> toJson() => {
    'eventId': eventId,
    'paymentMethod': paymentMethod,
    'amount': amount,
    'payerLabel': payerLabel,
  };
}

class PosReportSnapshot {
  const PosReportSnapshot({
    required this.sales,
    required this.orders,
    required this.covers,
    required this.paymentSplit,
    required this.hourlySales,
    required this.items,
    required this.staff,
    this.coversByHour = const {},
    this.auditCounts = const {},
    this.priorSameWeekdayHourlyAverage = const {},
  });

  final double sales;
  final int orders;
  final int covers;
  final Map<String, double> paymentSplit;
  final Map<int, double> hourlySales;
  final List<Map<String, Object?>> items;
  final List<Map<String, Object?>> staff;
  final Map<int, int> coversByHour;
  final Map<String, int> auditCounts;
  final Map<int, double> priorSameWeekdayHourlyAverage;

  Map<String, Object?> toJson() => {
    'sales': sales,
    'orders': orders,
    'covers': covers,
    'paymentSplit': paymentSplit,
    'hourlySales': {
      for (final entry in hourlySales.entries) '${entry.key}': entry.value,
    },
    'coversByHour': {
      for (final entry in coversByHour.entries) '${entry.key}': entry.value,
    },
    'auditCounts': auditCounts,
    'priorSameWeekdayHourlyAverage': {
      for (final entry in priorSameWeekdayHourlyAverage.entries)
        '${entry.key}': entry.value,
    },
    'items': items,
    'staff': staff,
  };

  factory PosReportSnapshot.fromJson(Map<String, Object?> json) =>
      PosReportSnapshot(
        sales: _double(json['sales']),
        orders: _int(json['orders']),
        covers: _int(json['covers']),
        paymentSplit: _stringDoubleMap(json['paymentSplit']),
        hourlySales: _intDoubleMap(json['hourlySales']),
        coversByHour: _intIntMap(json['coversByHour']),
        auditCounts: _stringIntMap(json['auditCounts']),
        priorSameWeekdayHourlyAverage: _intDoubleMap(
          json['priorSameWeekdayHourlyAverage'],
        ),
        items: _mapList(json['items'], (item) => item),
        staff: _mapList(json['staff'], (item) => item),
      );
}

List<T> _mapList<T>(Object? raw, T Function(Map<String, Object?>) mapper) {
  if (raw is! List) return <T>[];
  return raw
      .whereType<Map>()
      .map((item) => mapper(Map<String, Object?>.from(item)))
      .toList(growable: false);
}

Map<String, Object?> _json(Object? raw) {
  if (raw is Map) return Map<String, Object?>.from(raw);
  if (raw is! String || raw.isEmpty) return {};
  final value = jsonDecode(raw);
  return value is Map ? Map<String, Object?>.from(value) : {};
}

Map<String, int> _intMap(Object? raw) {
  final value = _json(raw);
  return {for (final entry in value.entries) entry.key: _int(entry.value)};
}

Map<String, double> _stringDoubleMap(Object? raw) => {
  for (final entry in _json(raw).entries) entry.key: _double(entry.value),
};

Map<String, int> _stringIntMap(Object? raw) => {
  for (final entry in _json(raw).entries) entry.key: _int(entry.value),
};

Map<int, double> _intDoubleMap(Object? raw) => {
  for (final entry in _json(raw).entries)
    if (int.tryParse(entry.key) != null)
      int.parse(entry.key): _double(entry.value),
};

Map<int, int> _intIntMap(Object? raw) => {
  for (final entry in _json(raw).entries)
    if (int.tryParse(entry.key) != null)
      int.parse(entry.key): _int(entry.value),
};

int _int(Object? raw, {int fallback = 0}) =>
    raw is num ? raw.toInt() : int.tryParse('$raw') ?? fallback;

double _double(Object? raw) =>
    raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;

double? _nullableDouble(Object? raw) => raw == null ? null : _double(raw);

DateTime? _date(Object? raw) => raw == null ? null : DateTime.tryParse('$raw');
