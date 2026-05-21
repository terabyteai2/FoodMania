class DailyStockCount {
  DailyStockCount({
    required this.id,
    required this.inventoryItemId,
    required this.countDate,
    required this.quantity,
    required this.createdAt,
  });

  final String id;
  final String inventoryItemId;
  /// Calendar day `yyyy-MM-dd`.
  final String countDate;
  final double quantity;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'inventoryItemId': inventoryItemId,
      'countDate': countDate,
      'quantity': quantity,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DailyStockCount.fromMap(Map<String, Object?> map) {
    return DailyStockCount(
      id: map['id'] as String,
      inventoryItemId: map['inventoryItemId'] as String,
      countDate: map['countDate'] as String,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
