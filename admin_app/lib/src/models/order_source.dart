enum OrderSource {
  localLan,
  cloud,
  facebookMessenger,
  whatsapp,
  desktopPos,
  manual;

  String get value {
    switch (this) {
      case OrderSource.localLan:
        return 'local_lan';
      case OrderSource.cloud:
        return 'cloud';
      case OrderSource.facebookMessenger:
        return 'facebook_messenger';
      case OrderSource.whatsapp:
        return 'whatsapp';
      case OrderSource.desktopPos:
        return 'desktop_pos';
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
      case OrderSource.facebookMessenger:
        return 'Messenger';
      case OrderSource.whatsapp:
        return 'WhatsApp';
      case OrderSource.desktopPos:
        return 'Desktop POS';
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
        normalized == 'customer_web' ||
        normalized == 'web_cloud') {
      return OrderSource.cloud;
    }
    if (normalized == 'facebook' ||
        normalized == 'messenger' ||
        normalized == 'fb_messenger' ||
        normalized == 'facebook_messenger') {
      return OrderSource.facebookMessenger;
    }
    if (normalized == 'wa' ||
        normalized == 'whats_app' ||
        normalized == 'whatsapp_business') {
      return OrderSource.whatsapp;
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
