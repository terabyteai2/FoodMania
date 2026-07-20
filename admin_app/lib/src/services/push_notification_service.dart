import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/pos_notification.dart';
import 'system_notification_service.dart';

export 'package:firebase_messaging/firebase_messaging.dart'
    show RemoteMessage;

typedef PushTokenCallback =
    Future<void> Function(String token, String platform);

typedef NotificationTapCallback = Future<void> Function(
  Map<String, String> data,
);

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  final data = message.data;
  final type = data['type'] ?? '';
  final serial = data['serialNumber'] ?? '';
  final orderId = data['orderId'] ?? '';
  final actionTarget = data['actionTarget'] ?? 'orders';
  final title = message.notification?.title ?? data['title'] ?? 'Order update';
  final body = message.notification?.body ?? data['body'] ?? 'Serial #$serial';

  debugPrint(
    '[QB-FCM-BG] type=$type serial=$serial title=$title orderId=$orderId '
    'actionTarget=$actionTarget',
  );

  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: androidInit);
  try {
    await plugin.initialize(settings);
  } catch (e) {
    debugPrint('[QB-FCM-BG] local notifications init failed: $e');
    return;
  }

  final statusVal = (data['status'] ?? '').toString().toLowerCase();
  final channelId = (statusVal == 'accepted' ||
      statusVal == 'completed' ||
      statusVal == 'served')
      ? 'pos_accepted_orders_v2'
      : 'pos_pending_orders_v2';

  final notificationId = orderId.isNotEmpty
      ? Object.hash(orderId, type).abs() & 0x7fffffff
      : DateTime.now().millisecondsSinceEpoch & 0x7fffffff;

  try {
    await plugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId == 'pos_accepted_orders_v2'
              ? 'Accepted order alerts'
              : 'Pending order alerts',
          channelDescription: channelId == 'pos_accepted_orders_v2'
              ? 'Sound plays when an order is accepted.'
              : 'Sound plays when a new order needs attention.',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.public,
          playSound: true,
          enableVibration: true,
        ),
      ),
      payload: actionTarget,
    );
    debugPrint(
      '[QB-FCM-BG] notification shown id=$notificationId channel=$channelId',
    );
  } catch (e) {
    debugPrint('[QB-FCM-BG] notification show failed: $e');
  }
}

class PushNotificationService {
  PushNotificationService();

  FirebaseMessaging? _messaging;
  String? _currentToken;
  SystemNotificationService? _systemNotifications;
  NotificationTapCallback? _onTap;
  StreamSubscription<String?>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _tapSubscription;
  bool _initialized = false;

  bool _fcmAvailable = false;

  bool get isFcmAvailable => _fcmAvailable;
  String? get token => _currentToken;
  String get platform => 'android';

  Future<void> initialize({
    required SystemNotificationService systemNotifications,
    required PushTokenCallback onToken,
    NotificationTapCallback? onNotificationTap,
  }) async {
    if (_initialized) return;
    _initialized = true;

    _systemNotifications = systemNotifications;
    _onTap = onNotificationTap;

    try {
      _messaging = FirebaseMessaging.instance;
    } catch (e) {
      debugPrint('[QB-FCM] FirebaseMessaging unavailable: $e');
      _fcmAvailable = false;
      return;
    }
    _fcmAvailable = true;

    // Register the top-level background handler.
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Request notification permission (Android 13+).
    final permission = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      provisional: false,
    );
    debugPrint(
      '[QB-FCM] permission granted=${permission.authorizationStatus}',
    );

    // Get the current FCM registration token.
    _currentToken = await _messaging!.getToken();
    if (_currentToken != null && _currentToken!.isNotEmpty) {
      await onToken(_currentToken!, platform);
    }
    debugPrint('[QB-FCM] initial token=${_currentToken?.isNotEmpty == true}');

    // Listen for token refresh.
    _tokenSubscription =
        _messaging!.onTokenRefresh.listen((String refreshedToken) {
      _currentToken = refreshedToken;
      unawaited(onToken(refreshedToken, platform));
      debugPrint('[QB-FCM] token refreshed');
    });

    // Foreground messages: show as OS notification.
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    // Notification tapped while app was in background.
    _tapSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was launched by tapping a notification (killed state).
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? '';
    final serial = data['serialNumber'] ?? '';
    final orderId = data['orderId'] ?? '';
    final actionTarget = data['actionTarget'] ?? 'orders';

    final title = message.notification?.title ?? data['title'] ?? 'Order update';
    final body =
        message.notification?.body ?? data['body'] ?? 'Serial #$serial';

    debugPrint(
      '[QB-FCM-FG] type=$type serial=$serial orderId=$orderId title=$title',
    );

    final statusVal = (data['status'] ?? '').toString().toLowerCase();
    final notifType = (statusVal == 'accepted' ||
            statusVal == 'completed' ||
            statusVal == 'served')
        ? PosNotificationType.acceptedOrder
        : statusVal == 'pending'
        ? PosNotificationType.pendingOrder
        : PosNotificationType.system;

    final stableId = orderId.isNotEmpty
        ? Object.hash(orderId, type).abs() & 0x7fffffff
        : DateTime.now().millisecondsSinceEpoch & 0x7fffffff;

    unawaited(
      _systemNotifications?.show(
        id: stableId,
        title: title,
        body: body,
        payload: actionTarget,
        type: notifType,
        playSound: true,
        actionTarget: actionTarget,
      ),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = Map<String, String>.from(
      message.data.map((k, v) => MapEntry(k, v.toString())),
    );
    debugPrint('[QB-FCM] notification tapped data=$data');
    if (_onTap != null && data.isNotEmpty) {
      unawaited(_onTap!(data));
    }
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _tapSubscription?.cancel();
    _initialized = false;
  }
}
