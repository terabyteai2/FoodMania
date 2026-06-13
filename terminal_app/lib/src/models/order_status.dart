enum OrderStatus {
  pending,
  accepted,
  completed,
  rejected,
  // Legacy kitchen/desktop states kept so existing persisted and backend rows
  // still parse. FOH/mobile admin flow maps these onto the QuickBytes states.
  preparing,
  ready,
  served,
  cancelled;

  String get value => name;

  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.rejected:
        return 'Rejected';
      case OrderStatus.preparing:
        return 'Accepted';
      case OrderStatus.ready:
        return 'Accepted';
      case OrderStatus.served:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Rejected';
    }
  }

  OrderStatus get adminStatus {
    switch (this) {
      case OrderStatus.pending:
        return OrderStatus.pending;
      case OrderStatus.completed:
      case OrderStatus.served:
        return OrderStatus.completed;
      case OrderStatus.rejected:
      case OrderStatus.cancelled:
        return OrderStatus.rejected;
      case OrderStatus.preparing:
      case OrderStatus.ready:
        return OrderStatus.accepted;
      case OrderStatus.accepted:
        return this;
    }
  }

  bool get isOpen {
    final status = adminStatus;
    return status == OrderStatus.pending || status == OrderStatus.accepted;
  }

  bool get isCompleted => adminStatus == OrderStatus.completed;

  bool get isRejected => adminStatus == OrderStatus.rejected;

  int get priority {
    final status = adminStatus;
    if (status == OrderStatus.pending) return 0;
    if (status == OrderStatus.accepted) return 1;
    if (status == OrderStatus.completed) return 4;
    return 99;
  }

  bool canTransitionTo(OrderStatus next) {
    final current = adminStatus;
    final target = next.adminStatus;
    if (current == target) return true;
    if (current == OrderStatus.completed) {
      return target == OrderStatus.completed;
    }
    if (target == OrderStatus.rejected) {
      return current != OrderStatus.completed;
    }
    if (current == OrderStatus.rejected) {
      return target == OrderStatus.rejected;
    }
    if (current == OrderStatus.pending) {
      return target == OrderStatus.accepted;
    }
    return current == OrderStatus.accepted && target == OrderStatus.completed;
  }

  static OrderStatus? tryParse(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final status in OrderStatus.values) {
      if (status.value == normalized) return status;
    }
    return null;
  }
}
