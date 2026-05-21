enum OrderStatus {
  pending,
  accepted,
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
      case OrderStatus.preparing:
        return 'Accepted';
      case OrderStatus.ready:
        return 'Accepted';
      case OrderStatus.served:
        return 'Served';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  OrderStatus get adminStatus {
    switch (this) {
      case OrderStatus.pending:
        return OrderStatus.pending;
      case OrderStatus.preparing:
      case OrderStatus.ready:
        return OrderStatus.accepted;
      case OrderStatus.accepted:
      case OrderStatus.served:
      case OrderStatus.cancelled:
        return this;
    }
  }

  bool get isOpen {
    final status = adminStatus;
    return status == OrderStatus.pending || status == OrderStatus.accepted;
  }

  int get priority {
    switch (this) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.accepted:
        return 1;
      case OrderStatus.preparing:
        return 2;
      case OrderStatus.ready:
        return 3;
      case OrderStatus.served:
        return 4;
      case OrderStatus.cancelled:
        return 99;
    }
  }

  bool canTransitionTo(OrderStatus next) {
    final current = adminStatus;
    final target = next.adminStatus;
    if (current == target) return true;
    if (current == OrderStatus.served) return target == OrderStatus.served;
    if (target == OrderStatus.cancelled) return current != OrderStatus.served;
    if (current == OrderStatus.cancelled) {
      return target == OrderStatus.cancelled;
    }
    if (current == OrderStatus.pending) {
      return target == OrderStatus.accepted;
    }
    return current == OrderStatus.accepted && target == OrderStatus.served;
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
