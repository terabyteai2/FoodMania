import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/constants/cloud_defaults.dart';
import '../models/server_config.dart';
import 'cloud_api_service.dart';

class CloudRealtimeService {
  WebSocket? _socket;
  String? _channelName;
  String? _activeDeviceToken;
  bool _subscribed = false;
  bool _disposed = false;
  Timer? _reconnectTimer;

  // Backoff state
  int _retryCount = 0;
  static const _maxBackoffSeconds = 60;

  bool get isSubscribed => _subscribed;
  String? get channelName => _channelName;

  /// Sends a JSON payload to the server over the open socket.
  /// Returns false when the socket is not connected (callers fall back to REST).
  Future<bool> sendMessage(Map<String, Object?> payload) async {
    final socket = _socket;
    if (socket == null || !_subscribed || socket.readyState != WebSocket.open) {
      return false;
    }
    try {
      socket.add(jsonEncode(payload));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> connect({
    required CloudRealtimeConfig config,
    required ServerConfig serverConfig,
    required void Function(Map<String, Object?> event) onEvent,
    void Function(String message)? onLog,
  }) async {
    // config.enabled is false when the Python backend is used — connect via WS directly
    final baseUrl = _wsBaseUrl(config, serverConfig);
    if (baseUrl == null) return;

    final nextChannel = serverConfig.outletId;
    final nextToken = config.deviceToken;
    // Re-use the existing socket only if BOTH the outlet and the device token
    // are unchanged. On re-login the outlet may be the same but a fresh JWT
    // is minted — keeping the old WebSocket would silently drop orders.
    if (_subscribed &&
        _channelName == nextChannel &&
        _activeDeviceToken == nextToken) {
      return;
    }

    await disconnect();
    _disposed = false;
    _channelName = nextChannel;
    _activeDeviceToken = nextToken;
    _retryCount = 0;

    await _connectLoop(
      wsUrl: baseUrl,
      outletId: serverConfig.outletId,
      deviceToken: config.deviceToken,
      onEvent: onEvent,
      onLog: onLog,
    );
  }

  Future<void> _connectLoop({
    required String wsUrl,
    required String outletId,
    required String deviceToken,
    required void Function(Map<String, Object?> event) onEvent,
    void Function(String message)? onLog,
  }) async {
    if (_disposed) return;
    final uri =
        '$wsUrl/ws/$outletId?token=${Uri.encodeQueryComponent(deviceToken)}';
    try {
      final parsedUri = Uri.parse(uri);
      final ngrokExtra = CloudDefaults.ngrokBrowserBypassHeaders(parsedUri);
      // dart:io WebSocket.connect requires a String URL, not Uri.
      _socket = await WebSocket.connect(
        uri,
        headers: ngrokExtra.isEmpty ? null : ngrokExtra,
      ).timeout(const Duration(seconds: 10));
      _subscribed = true;
      _retryCount = 0;
      onLog?.call('Cloud realtime connected: $outletId');

      _socket!.listen(
        (message) {
          if (message is String) {
            try {
              final decoded = jsonDecode(message);
              if (decoded is Map) {
                final payload = Map<String, Object?>.from(decoded);
                if (payload['type'] == 'ping') return; // keepalive
                onEvent(payload);
              }
            } catch (_) {}
          }
        },
        onDone: () {
          _subscribed = false;
          onLog?.call('Cloud realtime disconnected.');
          _scheduleReconnect(
            wsUrl: wsUrl,
            outletId: outletId,
            deviceToken: deviceToken,
            onEvent: onEvent,
            onLog: onLog,
          );
        },
        onError: (error) {
          _subscribed = false;
          onLog?.call('Cloud realtime error: $error');
          _scheduleReconnect(
            wsUrl: wsUrl,
            outletId: outletId,
            deviceToken: deviceToken,
            onEvent: onEvent,
            onLog: onLog,
          );
        },
        cancelOnError: true,
      );
    } catch (e) {
      _subscribed = false;
      onLog?.call('Cloud realtime connect failed: $e');
      _scheduleReconnect(
        wsUrl: wsUrl,
        outletId: outletId,
        deviceToken: deviceToken,
        onEvent: onEvent,
        onLog: onLog,
      );
    }
  }

  void _scheduleReconnect({
    required String wsUrl,
    required String outletId,
    required String deviceToken,
    required void Function(Map<String, Object?> event) onEvent,
    void Function(String message)? onLog,
  }) {
    if (_disposed) return;
    _retryCount++;
    final backoff = Duration(
      seconds: (_retryCount * 2).clamp(2, _maxBackoffSeconds),
    );
    onLog?.call('Reconnecting in ${backoff.inSeconds}s...');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(backoff, () {
      _connectLoop(
        wsUrl: wsUrl,
        outletId: outletId,
        deviceToken: deviceToken,
        onEvent: onEvent,
        onLog: onLog,
      );
    });
  }

  Future<void> disconnect() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final socket = _socket;
    _socket = null;
    _channelName = null;
    _activeDeviceToken = null;
    _subscribed = false;
    await socket?.close();
  }

  /// Derives the WebSocket base URL from the cloud config / server config.
  /// The Python backend serves WS at the same base URL as REST.
  String? _wsBaseUrl(CloudRealtimeConfig config, ServerConfig serverConfig) {
    // deviceToken is stored in CloudRealtimeConfig via a custom field;
    // we derive the WS URL from the base REST URL stored in CloudRealtimeConfig.
    // If supabaseUrl is empty (Python backend), use the REST base URL instead.
    final raw = config.supabaseUrl.trim().isNotEmpty
        ? config.supabaseUrl.trim()
        : config.restBaseUrl.trim();
    if (raw.isEmpty) return null;

    // Convert http(s):// → ws(s)://
    if (raw.startsWith('https://')) {
      return 'wss://${raw.substring('https://'.length)}';
    } else if (raw.startsWith('http://')) {
      return 'ws://${raw.substring('http://'.length)}';
    }
    return raw;
  }
}
