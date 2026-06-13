import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

class GoogleAuthPreflightResult {
  const GoogleAuthPreflightResult({
    required this.ok,
    required this.reasonCode,
    required this.userMessage,
    required this.hasNetworkRoute,
    required this.genericDnsReachable,
    required this.googleDnsReachable,
    required this.googleHttpsReachable,
    this.httpsProbeUrl,
  });

  final bool ok;
  final String reasonCode;
  final String userMessage;
  final bool hasNetworkRoute;
  final bool genericDnsReachable;
  final bool googleDnsReachable;
  final bool googleHttpsReachable;
  final String? httpsProbeUrl;

  String get debugSummary {
    return 'ok=$ok reason=$reasonCode route=$hasNetworkRoute '
        'dnsGeneric=$genericDnsReachable dnsGoogle=$googleDnsReachable '
        'httpsGoogle=$googleHttpsReachable probe=${httpsProbeUrl ?? "-"}';
  }
}

class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Stream<bool> get onlineStream {
    return _connectivity.onConnectivityChanged
        .map(_hasNetworkRoute)
        .distinct()
        .asyncMap((hasRoute) async {
          if (!hasRoute) return false;
          return hasInternetAccess();
        });
  }

  Future<bool> hasNetworkRoute() async {
    final result = await _connectivity.checkConnectivity();
    return _hasNetworkRoute(result);
  }

  Future<bool> hasInternetAccess() async {
    final hasRoute = await hasNetworkRoute();
    if (!hasRoute) return false;
    return _hostLookupSucceeds(
      'example.com',
      timeout: const Duration(seconds: 3),
    );
  }

  Future<GoogleAuthPreflightResult> runGoogleAuthPreflight() async {
    final hasRoute = await hasNetworkRoute();
    if (!hasRoute) {
      return const GoogleAuthPreflightResult(
        ok: false,
        reasonCode: 'no_network_route',
        userMessage:
            'No internet route was detected on this device. Connect to Wi-Fi or mobile data, then try Google sign-in again.',
        hasNetworkRoute: false,
        genericDnsReachable: false,
        googleDnsReachable: false,
        googleHttpsReachable: false,
      );
    }

    final genericDns = await _hostLookupSucceeds(
      'example.com',
      timeout: const Duration(seconds: 3),
    );
    if (!genericDns) {
      return const GoogleAuthPreflightResult(
        ok: false,
        reasonCode: 'dns_unreachable',
        userMessage:
            'This network is connected but DNS is not resolving internet hosts. Switch networks and try again.',
        hasNetworkRoute: true,
        genericDnsReachable: false,
        googleDnsReachable: false,
        googleHttpsReachable: false,
      );
    }

    final googleHosts = <String>[
      'accounts.google.com',
      'oauth2.googleapis.com',
      'www.googleapis.com',
    ];
    var googleDns = false;
    for (final host in googleHosts) {
      if (await _hostLookupSucceeds(
        host,
        timeout: const Duration(seconds: 3),
      )) {
        googleDns = true;
        break;
      }
    }
    if (!googleDns) {
      return const GoogleAuthPreflightResult(
        ok: false,
        reasonCode: 'google_dns_blocked',
        userMessage:
            'Could not resolve Google sign-in hosts from this network. Private DNS, VPN, firewall, or ISP filtering may be blocking Google.',
        hasNetworkRoute: true,
        genericDnsReachable: true,
        googleDnsReachable: false,
        googleHttpsReachable: false,
      );
    }

    final probeUris = <Uri>[
      Uri.parse('https://connectivitycheck.gstatic.com/generate_204'),
      Uri.parse('https://www.google.com/generate_204'),
    ];
    Uri? successfulProbe;
    for (final uri in probeUris) {
      final ok = await _probeHttps204(uri, timeout: const Duration(seconds: 4));
      if (ok) {
        successfulProbe = uri;
        break;
      }
    }
    if (successfulProbe == null) {
      return const GoogleAuthPreflightResult(
        ok: false,
        reasonCode: 'google_https_blocked',
        userMessage:
            'Google sign-in endpoints are unreachable over HTTPS from this network. Try another network or disable VPN/Private DNS.',
        hasNetworkRoute: true,
        genericDnsReachable: true,
        googleDnsReachable: true,
        googleHttpsReachable: false,
      );
    }

    return GoogleAuthPreflightResult(
      ok: true,
      reasonCode: 'ok',
      userMessage: 'Google sign-in preflight checks passed.',
      hasNetworkRoute: true,
      genericDnsReachable: true,
      googleDnsReachable: true,
      googleHttpsReachable: true,
      httpsProbeUrl: successfulProbe.toString(),
    );
  }

  Future<bool> _hostLookupSucceeds(
    String host, {
    required Duration timeout,
  }) async {
    try {
      final lookup = await InternetAddress.lookup(host).timeout(timeout);
      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _probeHttps204(Uri uri, {required Duration timeout}) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      request.followRedirects = true;
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close().timeout(timeout);
      await response.drain<void>();
      return response.statusCode == HttpStatus.noContent ||
          response.statusCode == HttpStatus.ok;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  bool _hasNetworkRoute(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((result) => result != ConnectivityResult.none);
  }
}
