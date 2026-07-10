enum PosNotificationType {
  pendingOrder,
  acceptedOrder,
  printSuccess,
  printFailed,
  system;

  String get value => name;

  static PosNotificationType parse(String? value) {
    for (final type in PosNotificationType.values) {
      if (type.value == value) return type;
    }
    return PosNotificationType.system;
  }
}

enum PosNotificationTarget {
  none,
  orders,
  inventory,
  menu,
  receiptPrinter,
  settings,
  messages;

  static PosNotificationTarget parse(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'test') {
      return PosNotificationTarget.none;
    }
    if (normalized == 'pending_orders' ||
        normalized == 'orders' ||
        normalized == 'order') {
      return PosNotificationTarget.orders;
    }
    if (normalized == 'messages' ||
        normalized == 'chat' ||
        normalized == 'chats' ||
        normalized == 'escalation' ||
        normalized == 'needs_help') {
      return PosNotificationTarget.messages;
    }
    if (normalized == 'stock' ||
        normalized == 'inventory' ||
        normalized == 'low_stock') {
      return PosNotificationTarget.inventory;
    }
    if (normalized == 'menu' || normalized == 'menu_items') {
      return PosNotificationTarget.menu;
    }
    if (normalized == 'settings_printer' ||
        normalized == 'receipt_printer' ||
        normalized == 'printer') {
      return PosNotificationTarget.receiptPrinter;
    }
    if (normalized == 'settings' ||
        normalized == 'staff' ||
        normalized == 'sync' ||
        normalized == 'reports') {
      return PosNotificationTarget.settings;
    }
    return PosNotificationTarget.none;
  }
}

class PosNotification {
  PosNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.orderId,
    this.actionTarget,
    this.readAt,
  });

  final String id;
  final PosNotificationType type;
  final String title;
  final String body;
  final String? orderId;
  final String? actionTarget;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  PosNotificationTarget get target {
    final parsed = PosNotificationTarget.parse(actionTarget);
    if (parsed != PosNotificationTarget.none) return parsed;
    return switch (type) {
      PosNotificationType.pendingOrder ||
      PosNotificationType.acceptedOrder ||
      PosNotificationType.printSuccess ||
      PosNotificationType.printFailed => PosNotificationTarget.orders,
      PosNotificationType.system => PosNotificationTarget.none,
    };
  }

  PosNotification copyWith({DateTime? readAt}) {
    return PosNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      orderId: orderId,
      actionTarget: actionTarget,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'type': type.value,
      'title': title,
      'body': body,
      'orderId': orderId,
      'actionTarget': actionTarget,
      'createdAt': createdAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
    };
  }

  factory PosNotification.fromMap(Map<String, Object?> map) {
    return PosNotification(
      id: map['id'] as String,
      type: PosNotificationType.parse(map['type'] as String?),
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      orderId: map['orderId'] as String?,
      actionTarget: map['actionTarget'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      readAt: map['readAt'] == null
          ? null
          : DateTime.tryParse(map['readAt'] as String),
    );
  }
}
