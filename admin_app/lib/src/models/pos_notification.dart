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
