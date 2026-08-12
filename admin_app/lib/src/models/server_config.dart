class ServerConfig {
  ServerConfig({
    required this.serverId,
    required this.restaurantId,
    required this.outletId,
    required this.restaurantName,
    required this.outletName,
    this.publicSlug = '',
    this.outletPhone = '',
    this.tableCount = 10,
    this.customerMenuTheme = 'sultans_hearth',
    this.deliveryCharge = 0,
    this.shiftHoursEnabled = false,
    this.shiftStartMinute,
    this.shiftEndMinute,
    this.logoUrl,
    this.logoBitmapUrl,
  });

  final String serverId;
  final String restaurantId;
  final String outletId;
  final String restaurantName;
  final String outletName;
  final String publicSlug;
  // Restaurant contact phone (Outlet.phone on the backend) — distinct from the
  // account holder's own phone. Empty string = "not configured" (null-safe invariant).
  final String outletPhone;
  final int tableCount;
  final String customerMenuTheme;
  final double deliveryCharge;

  /// Optional operating shift for the completed-orders list and the app's
  /// local "today" totals. While [shiftHoursEnabled] is false the calendar
  /// day applies; enabling it honors the open/close window below, where a
  /// shift crossing midnight still counts the after-midnight orders (up to
  /// close) toward the previous day's shift. Minutes are since local
  /// midnight; null means unset.
  final bool shiftHoursEnabled;
  final int? shiftStartMinute;
  final int? shiftEndMinute;
  final String? logoUrl;
  final String? logoBitmapUrl;

  ServerConfig copyWith({
    String? serverId,
    String? restaurantId,
    String? outletId,
    String? restaurantName,
    String? outletName,
    String? publicSlug,
    String? outletPhone,
    int? tableCount,
    String? customerMenuTheme,
    double? deliveryCharge,
    bool? shiftHoursEnabled,
    Object? shiftStartMinute = _sentinel,
    Object? shiftEndMinute = _sentinel,
    Object? logoUrl = _sentinel,
    Object? logoBitmapUrl = _sentinel,
  }) {
    return ServerConfig(
      serverId: serverId ?? this.serverId,
      restaurantId: restaurantId ?? this.restaurantId,
      outletId: outletId ?? this.outletId,
      restaurantName: restaurantName ?? this.restaurantName,
      outletName: outletName ?? this.outletName,
      publicSlug: publicSlug ?? this.publicSlug,
      outletPhone: outletPhone ?? this.outletPhone,
      tableCount: tableCount ?? this.tableCount,
      customerMenuTheme: customerMenuTheme ?? this.customerMenuTheme,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      shiftHoursEnabled: shiftHoursEnabled ?? this.shiftHoursEnabled,
      shiftStartMinute: identical(shiftStartMinute, _sentinel)
          ? this.shiftStartMinute
          : shiftStartMinute as int?,
      shiftEndMinute: identical(shiftEndMinute, _sentinel)
          ? this.shiftEndMinute
          : shiftEndMinute as int?,
      logoUrl: identical(logoUrl, _sentinel)
          ? this.logoUrl
          : logoUrl as String?,
      logoBitmapUrl: identical(logoBitmapUrl, _sentinel)
          ? this.logoBitmapUrl
          : logoBitmapUrl as String?,
    );
  }
}

const Object _sentinel = Object();

class CloudConfig {
  CloudConfig({
    required this.baseUrl,
    required this.enabled,
    required this.deviceToken,
    required this.autoSyncIntervalSeconds,
  });

  final String baseUrl;
  final bool enabled;
  final String deviceToken;
  final int autoSyncIntervalSeconds;

  bool get hasValidBaseUrl {
    final uri = Uri.tryParse(baseUrl.trim());
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  bool get hasDeviceToken => deviceToken.trim().isNotEmpty;
  bool get canConnect => enabled && hasValidBaseUrl;
  bool get canSync => canConnect && hasDeviceToken;

  CloudConfig copyWith({
    String? baseUrl,
    bool? enabled,
    String? deviceToken,
    int? autoSyncIntervalSeconds,
  }) {
    return CloudConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      enabled: enabled ?? this.enabled,
      deviceToken: deviceToken ?? this.deviceToken,
      autoSyncIntervalSeconds:
          autoSyncIntervalSeconds ?? this.autoSyncIntervalSeconds,
    );
  }
}
