class InventorySupplier {
  const InventorySupplier({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.phone = '',
    this.notes = '',
    this.isActive = true,
  });

  final String id;
  final String name;
  final String phone;
  final String notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'notes': notes,
    'isActive': isActive ? 1 : 0,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'notes': notes,
  };

  factory InventorySupplier.fromMap(Map<String, Object?> map) {
    final active = map['isActive'];
    return InventorySupplier(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      isActive: active is bool ? active : (active as num? ?? 1) != 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
