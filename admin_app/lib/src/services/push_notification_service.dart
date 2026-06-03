import 'package:flutter/foundation.dart';

import 'system_notification_service.dart';

typedef PushTokenCallback =
    Future<void> Function(String token, String platform);

/// POS-terminal builds rely on the app's realtime sync plus local notification
/// service while the app is running. Firebase Messaging currently raises the
/// Android minSdk floor above Android 5.1/API 22, so this service intentionally
/// stays as a no-op until a separate modern APK flavor is introduced.
class PushNotificationService {
  PushNotificationService();

  String? get token => null;
  String get platform => 'disabled';

  Future<void> initialize({
    required SystemNotificationService systemNotifications,
    required PushTokenCallback onToken,
  }) async {
    if (kDebugMode) {
      debugPrint('[QB-NOTIF] FCM disabled for POS terminal APK');
    }
  }

  Future<void> dispose() async {}
}
