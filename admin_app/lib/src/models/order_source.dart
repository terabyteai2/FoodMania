enum OrderSource {
  localLan,
  cloud,
  manual;

  String get value {
    switch (this) {
      case OrderSource.localLan:
        return 'local_lan';
      case OrderSource.cloud:
        return 'cloud';
      case OrderSource.manual:
        return 'manual';
    }
  }

  String get label {
    switch (this) {
      case OrderSource.localLan:
        return 'Legacy LAN';
      case OrderSource.cloud:
        return 'Cloud';
      case OrderSource.manual:
        return 'Manual';
    }
  }

  static OrderSource parse(
    String? value, {
    OrderSource fallback = OrderSource.cloud,
  }) {
    if (value == null) return fallback;
    final normalized = value.trim().toLowerCase();
    if (normalized == 'cloud_customer' ||
        normalized == 'customer_cloud' ||
        normalized == 'online' ||
        normalized == 'web_cloud') {
      return OrderSource.cloud;
    }
    for (final source in OrderSource.values) {
      if (source.value == normalized ||
          source.name.toLowerCase() == normalized) {
        return source;
      }
    }
    return fallback;
  }
}
