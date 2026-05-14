class InventoryItem {
  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.quantity,
    required this.minThreshold,
    required this.costPerUnit,
    required this.createdAt,
    required this.updatedAt,
    this.notes = '',
  });

  final String id;
  final String name;
  final String category;
  final String unit;
  final double quantity;
  final double minThreshold;
  final double costPerUnit;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLowStock => quantity > 0 && quantity <= minThreshold;
  bool get isOutOfStock => quantity <= 0;

  InventoryItem copyWith({
    String? id,
    String? name,
    String? category,
    String? unit,
    double? quantity,
    double? minThreshold,
    double? costPerUnit,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      minThreshold: minThreshold ?? this.minThreshold,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'unit': unit,
      'quantity': quantity,
      'minThreshold': minThreshold,
      'costPerUnit': costPerUnit,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory InventoryItem.fromMap(Map<String, Object?> map) {
    return InventoryItem(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String? ?? '',
      unit: map['unit'] as String? ?? 'pcs',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      minThreshold: (map['minThreshold'] as num?)?.toDouble() ?? 0,
      costPerUnit: (map['costPerUnit'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
