import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

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
    try {
      final lookup = await InternetAddress.lookup(
        'example.com',
      ).timeout(Duration(seconds: 3));
      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _hasNetworkRoute(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((result) => result != ConnectivityResult.none);
  }
}
