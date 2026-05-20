class CloudDefaults {
  CloudDefaults._();

  /// Hint text in forms only (not used as the live default URL).
  static String placeholderBaseUrl = 'https://your-domain.ngrok-free.app';

  /// Hostname only — must match backend `.env` `NGROK_STATIC_DOMAIN`.
  /// Build override: `--dart-define=POS_NGROK_DOMAIN=my-tunnel.ngrok-free.app`
  static const String ngrokStaticDomain = String.fromEnvironment(
    'POS_NGROK_DOMAIN',
    defaultValue: 'kiwi-equator-banknote.ngrok-free.app',
  );

  /// Full public API base (HTTPS, no trailing slash). Empty `POS_CLOUD_API_URL` → ngrok default.
  /// Build override: `--dart-define=POS_CLOUD_API_URL=https://other.example.com`
  static const String _cloudApiUrlFromEnvironment = String.fromEnvironment(
    'POS_CLOUD_API_URL',
    defaultValue: '',
  );

  /// `https://<ngrokStaticDomain>` when using the repo default tunnel name.
  static String get defaultPublicApiBase {
    final raw = ngrokStaticDomain.trim();
    if (raw.isEmpty) return '';
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

  static String resolveBaseUrl(String? override) {
    final trimmed = override?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == placeholderBaseUrl) {
      return embeddedBaseUrl;
    }
    return trimmed;
  }
}
