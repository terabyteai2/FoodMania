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
        return 'Parcel';
      case OrderServiceType.delivery:
        return 'Delivery';
    }
  }

  String get banglaLabel {
    switch (this) {
      case OrderServiceType.dineIn:
        return 'ডাইন ইন';
      case OrderServiceType.takeaway:
        return 'পার্সেল';
      case OrderServiceType.delivery:
        return 'ডেলিভারি';
    }
  }

  String localized(bool isBn) => isBn ? banglaLabel : label;

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
