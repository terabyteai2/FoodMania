import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/pos_notification.dart';

/// Wraps `flutter_local_notifications` so the rest of the app can fire OS
/// notifications without touching plugin details. Designed to be safe: any
/// failure (permission denied, plugin not registered on this platform, etc.)
/// is swallowed silently so callers never have to wrap in try/catch.
///
/// Android channels (v2) are created with custom sounds from res/raw/ and
/// mirrored in native [MainActivity] so OEM builds play alert tones without
/// the user toggling channel sound in system settings.
class SystemNotificationService {
  SystemNotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const String _pendingChannelId = 'pos_pending_orders_v2';
  static const String _acceptedChannelId = 'pos_accepted_orders_v2';
  static const String _defaultChannelId = 'pos_orders_default_v2';

  /// Legacy channel IDs — deleted on upgrade so sound settings reset cleanly.
  static const _legacyChannelIds = <String>[
    'pos_pending_orders',
    'pos_accepted_orders',
    'pos_orders_default',
  ];

  static const String _pendingSoundRes = 'pending_order';
  static const String _acceptedSoundRes = 'accepted_order';

  static const String _kFallbackDefaultSoundUri =
      'content://settings/system/notification_sound';

  static const MethodChannel _platform = MethodChannel(
    'com.terabyteai.foodmania/notification_sound',
  );

  String? _systemDefaultSoundUri;

  String get effectiveDefaultSoundUri =>
      _systemDefaultSoundUri ?? _kFallbackDefaultSoundUri;

  Future<void> initialize() async {
    if (_ready) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );
    try {
      await _plugin.initialize(settings);
      _systemDefaultSoundUri = await _fetchSystemDefaultSoundUri();
      _ready = true;
    } catch (error, stack) {
      debugPrint('SystemNotificationService init failed: $error\n$stack');
    }
  }

  /// Request notification permission (Android 13+) and create channels with
  /// sound enabled. Call after install / on first main-shell mount.
  Future<bool> requestNotificationAccess() async {
    await initialize();
    if (!_ready) return false;

    var granted = true;
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final result = await Permission.notification.request();
        granted = result.isGranted;
      }
      await _ensureAndroidPermission();
      if (granted) {
        await _ensureNativeChannels();
      }
    }
    if (granted) {
      await _ensureChannels();
    }
    return granted;
  }

  Future<String?> _fetchSystemDefaultSoundUri() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _platform.invokeMethod<String>('defaultNotificationSoundUri');
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureAndroidPermission() async {
    if (!Platform.isAndroid) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    try {
      final granted = await android.areNotificationsEnabled();
      if (granted != true) {
        await android.requestNotificationsPermission();
      }
    } catch (_) {}
  }

  Future<void> ensurePermissionGranted() async {
    await requestNotificationAccess();
  }

  Future<void> _ensureNativeChannels() async {
    if (!Platform.isAndroid) return;
    try {
      await _platform.invokeMethod<void>('ensureNotificationChannels');
    } catch (error, stack) {
      debugPrint('ensureNotificationChannels failed: $error\n$stack');
    }
  }

  Future<void> _deleteLegacyChannels(
    AndroidFlutterLocalNotificationsPlugin android,
  ) async {
    for (final id in _legacyChannelIds) {
      try {
        await android.deleteNotificationChannel(id);
      } catch (_) {}
    }
  }

  Future<void> _ensureChannels() async {
    if (!Platform.isAndroid) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    await _deleteLegacyChannels(android);

    await _createChannel(
      android,
      id: _pendingChannelId,
      name: 'Pending order alerts',
      description: 'Sound plays when a new order needs attention.',
      sound: const RawResourceAndroidNotificationSound(_pendingSoundRes),
    );

    await _createChannel(
      android,
      id: _acceptedChannelId,
      name: 'Accepted order alerts',
      description: 'Sound plays when an order is accepted.',
      sound: const RawResourceAndroidNotificationSound(_acceptedSoundRes),
    );

    AndroidNotificationSound? defaultSound;
    if (effectiveDefaultSoundUri.isNotEmpty) {
      defaultSound = UriAndroidNotificationSound(effectiveDefaultSoundUri);
    }
    await _createChannel(
      android,
      id: _defaultChannelId,
      name: 'Order alerts',
      description: 'General order notifications with sound.',
      sound: defaultSound,
    );
  }

  Future<void> _createChannel(
    AndroidFlutterLocalNotificationsPlugin android, {
    required String id,
    required String name,
    required String description,
    AndroidNotificationSound? sound,
  }) async {
    try {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          id,
          name,
          description: description,
          importance: Importance.max,
          playSound: true,
          sound: sound,
          enableVibration: true,
        ),
      );
    } catch (e) {
      debugPrint('Could not create channel $id: $e');
    }
  }

  AndroidNotificationSound? _androidSoundForType(PosNotificationType type) {
    switch (type) {
      case PosNotificationType.pendingOrder:
        return const RawResourceAndroidNotificationSound(_pendingSoundRes);
      case PosNotificationType.acceptedOrder:
        return const RawResourceAndroidNotificationSound(_acceptedSoundRes);
      default:
        return null;
    }
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    PosNotificationType type = PosNotificationType.system,
    bool playSound = true,
  }) async {
    if (!_ready) {
      await initialize();
      if (!_ready) return;
    }

    final channelId = _channelIdForType(type);
    final channelName = _channelNameForType(type);
    final iosSound = _iosSoundForType(type);
    final androidSound = playSound ? _androidSoundForType(type) : null;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: _channelDescriptionForType(type),
      importance: Importance.max,
      priority: Priority.high,
      playSound: playSound,
      sound: androidSound,
      enableVibration: true,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
    );
    final darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
      sound: iosSound,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
    try {
      await _plugin.show(id, title, body, details, payload: payload);
    } catch (error, stack) {
      debugPrint('SystemNotificationService show failed: $error\n$stack');
    }
  }

  String _channelIdForType(PosNotificationType type) {
    switch (type) {
      case PosNotificationType.pendingOrder:
        return _pendingChannelId;
      case PosNotificationType.acceptedOrder:
        return _acceptedChannelId;
      default:
        return _defaultChannelId;
    }
  }

  String _channelNameForType(PosNotificationType type) {
    switch (type) {
      case PosNotificationType.pendingOrder:
        return 'Pending order alerts';
      case PosNotificationType.acceptedOrder:
        return 'Accepted order alerts';
      default:
        return 'Order alerts';
    }
  }

  String _channelDescriptionForType(PosNotificationType type) {
    switch (type) {
      case PosNotificationType.pendingOrder:
        return 'Sound plays when a new order needs attention.';
      case PosNotificationType.acceptedOrder:
        return 'Sound plays when an order is accepted.';
      default:
        return 'General order notifications with sound.';
    }
  }

  String? _iosSoundForType(PosNotificationType type) {
    switch (type) {
      case PosNotificationType.pendingOrder:
        return 'pending_order.wav';
      case PosNotificationType.acceptedOrder:
        return 'accepted_order.wav';
      default:
        return null;
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  Future<bool> playDefaultNotificationSound() async {
    if (!Platform.isAndroid) return false;
    try {
      final played =
          await _platform.invokeMethod<bool>('playDefaultNotificationSound');
      return played == true;
    } catch (_) {
      return false;
    }
  }

  Future<String> registerSoundWithSystem(String localPath) async {
    if (!Platform.isAndroid || localPath.isEmpty) return localPath;
    if (localPath.startsWith('content://')) return localPath;
    try {
      final result = await _platform.invokeMethod<String>(
        'registerNotificationSound',
        {'path': localPath},
      );
      if (result != null && result.isNotEmpty) return result;
    } catch (error, stack) {
      debugPrint('registerNotificationSound failed: $error\n$stack');
    }
    return localPath;
  }

  Future<void> configureSound({
    required bool enabled,
    required String soundPath,
  }) async {
    if (enabled && Platform.isAndroid) {
      await requestNotificationAccess();
    }
  }
}
