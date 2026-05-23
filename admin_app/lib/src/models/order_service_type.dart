enum OrderServiceType {
  dineIn,
  takeaway,
  delivery;

  String get value {
    switch (this) {
      case OrderServiceType.dineIn:
        return 'dine_in';
      case OrderServiceType.takeaway:
        return 'takeaway';
      case OrderServiceType.delivery:
        return 'delivery';
    }
  }

  String get label {
    switch (this) {
      case OrderServiceType.dineIn:
        return 'Dine-in';
      case OrderServiceType.takeaway:
        return 'Takeaway';
      case OrderServiceType.delivery:
        return 'Delivery';
    }
  }

  String get banglaLabel {
    switch (this) {
      case OrderServiceType.dineIn:
        return 'ডাইন ইন';
      case OrderServiceType.takeaway:
        return 'টেকওয়ে';
      case OrderServiceType.delivery:
        return 'ডেলিভারি';
    }
  }

  static OrderServiceType? tryParse(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final type in OrderServiceType.values) {
      if (type.value == normalized || type.name.toLowerCase() == normalized) {
        return type;
      }
    }
    if (normalized == 'dine-in' || normalized == 'dinein') {
      return OrderServiceType.dineIn;
    }
    return null;
  }
}
