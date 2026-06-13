enum AdjustmentType {
  restock('restock'),
  usage('usage'),
  waste('waste'),
  correction('correction');

  const AdjustmentType(this.value);

  final String value;

  static AdjustmentType parse(String? value) {
    for (final type in AdjustmentType.values) {
      if (type.value == value) return type;
    }
    return AdjustmentType.correction;
  }

  String label({bool isBn = false}) {
    switch (this) {
      case AdjustmentType.restock:
        return isBn ? 'রিস্টক' : 'Restock';
      case AdjustmentType.usage:
        return isBn ? 'ব্যবহার' : 'Usage';
      case AdjustmentType.waste:
        return isBn ? 'অপচয়' : 'Waste';
      case AdjustmentType.correction:
        return isBn ? 'সংশোধন' : 'Correction';
    }
  }
}

class StockAdjustment {
  StockAdjustment({
    required this.id,
    required this.inventoryItemId,
    required this.delta,
    required this.type,
    required this.createdAt,
    this.note = '',
    this.totalCostBdt = 0,
    this.supplierId,
    this.supplierName = '',
    this.reason = '',
    this.billRef = '',
    this.createdByAccountId,
    this.createdByRole,
  });

  final String id;
  final String inventoryItemId;
  final double delta;
  final AdjustmentType type;
  final String note;
  final DateTime createdAt;

  /// Purchase total (৳) when [type] is [AdjustmentType.restock].
  final double totalCostBdt;
  final String? supplierId;
  final String supplierName;
  final String reason;
  final String billRef;
  final String? createdByAccountId;
  final String? createdByRole;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'inventoryItemId': inventoryItemId,
      'delta': delta,
      'type': type.value,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'totalCostBdt': totalCostBdt,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'reason': reason,
      'billRef': billRef,
      'createdByAccountId': createdByAccountId,
      'createdByRole': createdByRole,
    };
  }

  factory StockAdjustment.fromMap(Map<String, Object?> map) {
    return StockAdjustment(
      id: map['id'] as String,
      inventoryItemId: map['inventoryItemId'] as String,
      delta: (map['delta'] as num).toDouble(),
      type: AdjustmentType.parse(map['type'] as String?),
      note: map['note'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      totalCostBdt: (map['totalCostBdt'] as num?)?.toDouble() ?? 0,
      supplierId: map['supplierId'] as String?,
      supplierName: map['supplierName'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      billRef: map['billRef'] as String? ?? '',
      createdByAccountId: map['createdByAccountId'] as String?,
      createdByRole: map['createdByRole'] as String?,
    );
  }
}
