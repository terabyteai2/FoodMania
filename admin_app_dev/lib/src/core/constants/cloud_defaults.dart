class CloudDefaults {
  CloudDefaults._();

  /// Hint text in forms only (not used as the live default URL).
  static String placeholderBaseUrl = 'https://your-domain.ngrok-free.app';

  /// Hostname only — kept for backwards compatibility with older builds that
  /// still relied on the ngrok tunnel. The live default is now the VPS URL
  /// below; set `POS_NGROK_DOMAIN` only if you want to re-enable ngrok routing.
  /// Build override: `--dart-define=POS_NGROK_DOMAIN=my-tunnel.ngrok-free.dev`
  static const String ngrokStaticDomain = String.fromEnvironment(
    'POS_NGROK_DOMAIN',
    defaultValue: '',
  );

  /// Full public API base (no trailing slash). Empty `POS_CLOUD_API_URL` → VPS default.
  /// Build override: `--dart-define=POS_CLOUD_API_URL=https://other.example.com`
  static const String _cloudApiUrlFromEnvironment = String.fromEnvironment(
    'POS_CLOUD_API_URL',
    defaultValue: 'https://dev.quickbytes.buzz',
  );

  /// Public API base used when no `POS_CLOUD_API_URL` build override is set.
  /// Prefer the configured ngrok tunnel if present, otherwise fall back to
  /// the env-provided `_cloudApiUrlFromEnvironment` (VPS default).
  static String get defaultPublicApiBase {
    final raw = ngrokStaticDomain.trim();
    if (raw.isEmpty) {
      return _cloudApiUrlFromEnvironment.trim().replaceAll(RegExp(r'/+$'), '');
    }
    final low = raw.toLowerCase();
    if (low.startsWith('https://') || low.startsWith('http://')) {
      return raw.replaceAll(RegExp(r'/+$'), '');
    }
    return 'https://$raw';
  }

  /// Default API base compiled into the app (ngrok unless overridden).
  static String get embeddedBaseUrl {
    final fromEnv = _cloudApiUrlFromEnvironment.trim();
    if (fromEnv.isNotEmpty) return fromEnv;
    return defaultPublicApiBase;
  }

  /// Same as [embeddedBaseUrl] — used as the initial CloudConfig base URL.
  static String get baseUrl => embeddedBaseUrl;

  /// ngrok free tier may return an HTML interstitial unless this header is sent.
  static bool hostUsesNgrokTunnel(String host) =>
      host.toLowerCase().contains('ngrok');

  static Map<String, String> ngrokBrowserBypassHeaders(Uri uri) {
    if (!hostUsesNgrokTunnel(uri.host)) return const {};
    return const {'ngrok-skip-browser-warning': 'true'};
  }

  static bool forceCloudSyncEnabled = bool.fromEnvironment(
    'POS_CLOUD_SYNC_ENABLED',
  );

  static bool get hasConfiguredBaseUrl {
    final trimmed = embeddedBaseUrl.trim();
    if (trimmed.isEmpty) return false;
    return trimmed != placeholderBaseUrl;
  }

  static bool get shouldEnableSyncByDefault {
    return forceCloudSyncEnabled || hasConfiguredBaseUrl;
  }

  /// Strips copy/paste noise (e.g. `"Exception: https://..."`), first line only,
  /// and trailing slashes — use for user-typed REST base URLs (staff server URL).
  static String sanitizeManualBaseUrl(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    final lines = s.split(RegExp(r'[\r\n]+'));
    for (final line in lines) {
      final t = line.trim();
      if (t.isNotEmpty) {
        s = t;
        break;
      }
    }
    for (var i = 0; i < 8; i++) {
      final m = RegExp(
        r'^(Exception|CloudApis?Exception|Error)\s*:\s*',
        caseSensitive: false,
      ).firstMatch(s);
      if (m == null) break;
      s = s.substring(m.end).trim();
      if (s.isEmpty) break;
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1).trim();
    }
    return s.trim();
  }

  static String resolveBaseUrl(String? override) {
    final trimmed = sanitizeManualBaseUrl(override ?? '').trim();
    if (trimmed.isEmpty || trimmed == placeholderBaseUrl) {
      return embeddedBaseUrl;
    }
    return trimmed;
  }

  static String customerMenuUrl({
    required String baseUrl,
    required String outletId,
    String? publicSlug,
  }) {
    final resolvedBase = resolveBaseUrl(baseUrl).replaceAll(RegExp(r'/+$'), '');
    final subdomain = (publicSlug ?? '').trim().toLowerCase();
    final isUuidLike = RegExp(
      r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
    ).hasMatch(subdomain);
    if (resolvedBase == 'https://quickbytes.buzz' &&
        !isUuidLike &&
        subdomain.isNotEmpty &&
        RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$').hasMatch(subdomain)) {
      return 'https://$subdomain.quickbytes.buzz';
    }
    return '$resolvedBase/menu/$outletId';
  }
}
