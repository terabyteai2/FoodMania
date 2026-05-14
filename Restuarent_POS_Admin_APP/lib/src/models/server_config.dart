class ServerConfig {
  ServerConfig({
    required this.serverId,
    required this.restaurantId,
    required this.outletId,
    required this.restaurantName,
    required this.outletName,
    this.tableCount = 10,
  });

  final String serverId;
  final String restaurantId;
  final String outletId;
  final String restaurantName;
  final String outletName;
  final int tableCount;

  ServerConfig copyWith({
    String? serverId,
    String? restaurantId,
    String? outletId,
    String? restaurantName,
    String? outletName,
    int? tableCount,
  }) {
    return ServerConfig(
      serverId: serverId ?? this.serverId,
      restaurantId: restaurantId ?? this.restaurantId,
      outletId: outletId ?? this.outletId,
      restaurantName: restaurantName ?? this.restaurantName,
      outletName: outletName ?? this.outletName,
      tableCount: tableCount ?? this.tableCount,
    );
  }
}

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
