enum OrderPaymentMethod {
  cash,
  card,
  bkash,
  nagad,
  payLater,
  split;

  String get value {
    switch (this) {
      case OrderPaymentMethod.cash:
        return 'cash';
      case OrderPaymentMethod.card:
        return 'card';
      case OrderPaymentMethod.bkash:
        return 'bkash';
      case OrderPaymentMethod.nagad:
        return 'nagad';
      case OrderPaymentMethod.payLater:
        return 'pay_later';
      case OrderPaymentMethod.split:
        return 'split';
    }
  }

  String get label {
    switch (this) {
      case OrderPaymentMethod.cash:
        return 'Cash';
      case OrderPaymentMethod.card:
        return 'Card';
      case OrderPaymentMethod.bkash:
        return 'bKash';
      case OrderPaymentMethod.nagad:
        return 'Nagad';
      case OrderPaymentMethod.payLater:
        return 'Pay later';
      case OrderPaymentMethod.split:
        return 'Split';
    }
  }

  String get banglaLabel {
    switch (this) {
      case OrderPaymentMethod.cash:
        return 'নগদ';
      case OrderPaymentMethod.card:
        return 'কার্ড';
      case OrderPaymentMethod.bkash:
        return 'বিকাশ';
      case OrderPaymentMethod.nagad:
        return 'Nagad';
      case OrderPaymentMethod.payLater:
        return 'পরে';
      case OrderPaymentMethod.split:
        return 'বিভক্ত';
    }
  }

  static OrderPaymentMethod? tryParse(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final method in OrderPaymentMethod.values) {
      if (method.value == normalized ||
          method.name.toLowerCase() == normalized) {
        return method;
      }
    }
    if (normalized == 'paylater' || normalized == 'pay later') {
      return OrderPaymentMethod.payLater;
    }
    return null;
  }
}
