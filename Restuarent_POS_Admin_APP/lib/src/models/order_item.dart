class OrderItem {
  OrderItem({
    required this.id,
    required this.orderId,
    required this.menuItemId,
    required this.name,
    required this.qty,
    required this.price,
    required this.lineTotal,
  });

  final String id;
  final String orderId;
  final String menuItemId;
  final String name;
  final int qty;
  final double price;
  final double lineTotal;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'menuItemId': menuItemId,
      'name': name,
      'qty': qty,
      'price': price,
      'lineTotal': lineTotal,
    };
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'menuItemId': menuItemId,
      'name': name,
      'qty': qty,
      'price': price,
      'lineTotal': lineTotal,
    };
  }

  factory OrderItem.fromMap(Map<String, Object?> map) {
    return OrderItem(
      id: map['id'] as String,
      orderId: map['orderId'] as String,
      menuItemId: map['menuItemId'] as String,
      name: map['name'] as String,
      qty: (map['qty'] as num).toInt(),
      price: (map['price'] as num).toDouble(),
      lineTotal: (map['lineTotal'] as num).toDouble(),
    );
  }
}

class OrderRequestItem {
  OrderRequestItem({required this.menuItemId, required this.qty});

  final String menuItemId;
  final int qty;

  factory OrderRequestItem.fromJson(Map<String, Object?> json) {
    final rawId = json['menuItemId'] ?? json['id'];
    final rawQty = json['qty'] ?? json['quantity'];
    if (rawId is! String || rawId.trim().isEmpty) {
      throw FormatException('Each item must include a menuItemId.');
    }
    if (rawQty is! num) {
      throw FormatException('Each item must include a numeric qty.');
    }
    return OrderRequestItem(menuItemId: rawId.trim(), qty: rawQty.toInt());
  }
}
