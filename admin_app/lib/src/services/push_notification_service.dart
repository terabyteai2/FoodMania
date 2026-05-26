import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/pos_notification.dart';
import 'system_notification_service.dart';

typedef PushTokenCallback =
    Future<void> Function(String token, String platform);

// Top-level background handler — runs in its own Dart isolate when the app is
// killed or backgrounded. Must be annotated with @pragma so the AOT compiler
// keeps it reachable. We show a local notification here so the alert appears
// even when FCM decides not to auto-display (e.g. data-only messages, or when
// the app is backgrounded but not killed on some OEMs).
@pragma('vm:entry-point')
Future<void> quickBytesFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (error) {
    debugPrint('[QB-NOTIF] background firebase init skipped: $error');
  }

  final title =
      message.notification?.title ??
      message.data['title']?.toString() ??
      'New order';
  final body =
      message.notification?.body ??
      message.data['body']?.toString() ??
      'Open QuickBites to review.';
  final status = message.data['status']?.toString() ?? '';
  final normalized = status.trim().toLowerCase();
  final type =
      (normalized == 'accepted' || normalized == 'served')
          ? PosNotificationType.acceptedOrder
          : PosNotificationType.pendingOrder;

  debugPrint(
    '[QB-NOTIF] background handler id=${message.messageId} '
    'title=$title type=${type.name} data=${message.data}',
  );

  // Show a local notification via flutter_local_notifications so it
  // surfaces on OEMs that strip the FCM-delivered notification, and
  // for the backgrounded-but-not-killed case where FCM won't auto-show.
  final sysNotif = SystemNotificationService();
  await sysNotif.initialize();
  final notifId =
      (message.messageId ?? '$title|${DateTime.now()}').hashCode.abs() &
      0x7fffffff;
  await sysNotif.show(
    id: notifId,
    title: title,
    body: body,
    payload: message.data['actionTarget']?.toString(),
    type: type,
    playSound: true,
  );
}

class PushNotificationService {
  PushNotificationService();

  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;
  String? _token;
  String _platform = 'unknown';

  String? get token => _token;
  String get platform => _platform;

  Future<void> initialize({
    required SystemNotificationService systemNotifications,
    required PushTokenCallback onToken,
  }) async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      debugPrint('[QB-NOTIF] FCM disabled on this platform');
      return;
    }
    _platform = Platform.isAndroid ? 'android' : 'ios';

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      FirebaseMessaging.onBackgroundMessage(
        quickBytesFirebaseMessagingBackgroundHandler,
      );
    } catch (error, stack) {
      debugPrint(
        '[QB-NOTIF] Firebase push disabled; add google-services.json for '
        'real device push. error=$error\n$stack',
      );
      return;
    }

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint(
        '[QB-NOTIF] FCM permission=${settings.authorizationStatus.name}',
      );
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) {
        debugPrint('[QB-NOTIF] FCM token unavailable');
      } else {
        await _handleToken(token, onToken);
      }
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => unawaited(_handleToken(token, onToken)),
        onError: (Object error) {
          debugPrint('[QB-NOTIF] FCM token refresh error=$error');
        },
      );
      _foregroundSub = FirebaseMessaging.onMessage.listen(
        (message) => unawaited(
          _handleForegroundMessage(message, systemNotifications),
        ),
        onError: (Object error) {
          debugPrint('[QB-NOTIF] FCM foreground stream error=$error');
        },
      );
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint(
          '[QB-NOTIF] message opened id=${message.messageId} data=${message.data}',
        );
      });
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        debugPrint(
          '[QB-NOTIF] initial message id=${initial.messageId} data=${initial.data}',
        );
      }
    } catch (error, stack) {
      debugPrint('[QB-NOTIF] FCM initialize failed: $error\n$stack');
    }
  }

  Future<void> _handleToken(String token, PushTokenCallback onToken) async {
    _token = token;
    debugPrint(
      '[QB-NOTIF] FCM token platform=$_platform len=${token.length}',
    );
    await onToken(token, _platform);
  }

  Future<void> _handleForegroundMessage(
    RemoteMessage message,
    SystemNotificationService systemNotifications,
  ) async {
    final title =
        message.notification?.title ?? message.data['title']?.toString() ?? 'Order update';
    final body =
        message.notification?.body ?? message.data['body']?.toString() ?? 'Open QuickBites to review.';
    final type = _notificationType(message.data['status']?.toString());
    final id = (message.messageId ?? '$title|$body|${DateTime.now()}')
            .hashCode
            .abs() &
        0x7fffffff;
    debugPrint(
      '[QB-NOTIF] foreground message id=${message.messageId} '
      'title=$title data=${message.data}',
    );
    await systemNotifications.show(
      id: id,
      title: title,
      body: body,
      payload: message.data['actionTarget']?.toString(),
      type: type,
      playSound: true,
    );
  }

  PosNotificationType _notificationType(String? status) {
    final normalized = (status ?? '').trim().toLowerCase();
    if (normalized == 'accepted' || normalized == 'served') {
      return PosNotificationType.acceptedOrder;
    }
    return PosNotificationType.pendingOrder;
  }

  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    await _tokenRefreshSub?.cancel();
  }
}
