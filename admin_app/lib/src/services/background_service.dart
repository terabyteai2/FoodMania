import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Must be called once before [runApp]. Registers the background isolate
/// callback that stays alive via a foreground-service notification.
Future<void> configureBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: (instance) async => true,
    ),
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      notificationChannelId: 'pos_background_service',
      initialNotificationContent: 'QuickBites is syncing...',
      initialNotificationTitle: 'QuickBites',
      foregroundServiceNotificationId: 888001,
      foregroundServiceTypes: [AndroidForegroundType.dataSync],
    ),
  );
}

/// Call from the controller to start the foreground WebSocket service.
Future<void> startBackgroundWebSocket({
  required String wsUrl,
  required String outletId,
  required String deviceToken,
}) async {
  final service = FlutterBackgroundService();
  final running = await service.isServiceRunning();
  if (!running) {
    await service.start();
    await Future.delayed(const Duration(milliseconds: 500));
  }
  service.invoke('connectWs', {
    'wsUrl': wsUrl,
    'outletId': outletId,
    'deviceToken': deviceToken,
  });
}

/// Call from the controller when the app comes to foreground.
Future<void> stopBackgroundWebSocket() async {
  final service = FlutterBackgroundService();
  if (await service.isServiceRunning()) {
    service.invoke('stopService');
  }
}

/// Top-level entry point for the background isolate.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notificationsPlugin.initialize(
    const InitializationSettings(android: androidInit),
  );

  WebSocket? socket;
  StreamSubscription? wsSubscription;
  Timer? keepAliveTimer;
  final alertedOrderIds = <String>{};

  Future<void> disconnect() async {
    keepAliveTimer?.cancel();
    keepAliveTimer = null;
    await wsSubscription?.cancel();
    wsSubscription = null;
    await socket?.close();
    socket = null;
  }

  void connect(Map<String, dynamic>? data) {
    disconnect();
    if (data == null) return;

    final wsUrl = data['wsUrl'] as String? ?? '';
    final outletId = data['outletId'] as String? ?? '';
    final deviceToken = data['deviceToken'] as String? ?? '';
    if (wsUrl.isEmpty || outletId.isEmpty || deviceToken.isEmpty) return;

    final uri = '$wsUrl/ws/$outletId?token=${Uri.encodeComponent(deviceToken)}';
    debugPrint('[QB-BG] connecting to $uri');

    WebSocket.connect(uri).timeout(const Duration(seconds: 10)).then((ws) {
      socket = ws;
      service.setForegroundNotificationInfo(
        title: 'QuickBites',
        content: 'Connected for real-time updates',
      );
      debugPrint('[QB-BG] connected');

      keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        try {
          socket?.add('{"type":"ping"}');
        } catch (_) {}
      });

      wsSubscription = ws.listen(
        (message) {
          if (message is! String) return;
          try {
            final decoded = jsonDecode(message);
            if (decoded is! Map || decoded['type'] == 'ping') return;

            final eventData = decoded['data'];
            if (eventData is! Map) return;

            final orderId = (eventData['id'] as String? ?? '').trim();
            final rawStatus = (eventData['status'] as String? ?? '').toString().toLowerCase();
            if (orderId.isEmpty) return;

            debugPrint('[QB-BG] ws event type=${decoded['type']} order=$orderId status=$rawStatus');

            // Show notification for new pending orders only.
            if (rawStatus == 'pending' && !alertedOrderIds.contains(orderId)) {
              alertedOrderIds.add(orderId);
              final serial = (eventData['serialNumber'] as String? ?? '');
              final source = (eventData['source'] as String? ?? '');
              final title = source == 'facebook_messenger'
                  ? 'New Messenger order'
                  : 'New pending order';
              final body = serial.isNotEmpty ? 'Serial #$serial needs attention' : 'New order needs attention';

              notificationsPlugin.show(
                orderId.hashCode & 0x7fffffff,
                title,
                body,
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'pos_pending_orders_v2',
                    'Pending order alerts',
                    channelDescription: 'Plays sound for new orders.',
                    importance: Importance.max,
                    priority: Priority.high,
                    fullScreenIntent: true,
                    category: AndroidNotificationCategory.message,
                    visibility: NotificationVisibility.public,
                  ),
                ),
              );
              debugPrint('[QB-BG] notification shown order=$orderId');
            }
          } catch (_) {}
        },
        onDone: () {
          debugPrint('[QB-BG] disconnected, reconnecting in 5s');
          service.setForegroundNotificationInfo(
            title: 'QuickBites',
            content: 'Reconnecting...',
          );
          disconnect();
          Future.delayed(const Duration(seconds: 5), () {
            connect(data);
          });
        },
        onError: (e) {
          debugPrint('[QB-BG] error: $e, reconnecting in 10s');
          service.setForegroundNotificationInfo(
            title: 'QuickBites',
            content: 'Reconnecting...',
          );
          disconnect();
          Future.delayed(const Duration(seconds: 10), () {
            connect(data);
          });
        },
      );
    }).catchError((e) {
      debugPrint('[QB-BG] connect failed: $e, retrying in 10s');
      service.setForegroundNotificationInfo(
        title: 'QuickBites',
        content: 'Reconnecting...',
      );
      Future.delayed(const Duration(seconds: 10), () {
        connect(data);
      });
    });
  }

  service.on('connectWs').listen((data) {
    connect(data);
  });

  service.on('stopService').listen((_) {
    debugPrint('[QB-BG] stopping service');
    disconnect();
    service.stopSelf();
  });
}
