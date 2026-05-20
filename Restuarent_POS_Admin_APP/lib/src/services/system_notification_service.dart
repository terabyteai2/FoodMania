import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Wraps `flutter_local_notifications` so the rest of the app can fire OS
/// notifications without touching plugin details. Designed to be safe: any
/// failure (permission denied, plugin not registered on this platform, etc.)
/// is swallowed silently so callers never have to wrap in try/catch.
class SystemNotificationService {
  SystemNotificationService();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String _activeChannelId = _defaultChannelId;
  String _activeSoundPath = '';
  bool _activeSoundEnabled = true;
  // System default notification URI, fetched once at init and re-used as the
  // channel sound whenever the user hasn't picked a custom one. Without this,
  // some OEM Android builds (Xiaomi/Oppo/Vivo) create silent channels.
  String? _systemDefaultSoundUri;

  static const String _defaultChannelId = 'foodmania_orders_default';
  static const String _channelName = 'Order alerts';
  static const String _channelDescription =
      'Alerts for new pending orders and print failures.';
  // Hardcoded universal fallback — Android exposes the user's current default
  // notification sound at this URI on every device. Used when the platform
  // channel call returns null (e.g. method not yet registered on first run).
  static const String _kFallbackDefaultSoundUri =
      'content://settings/system/notification_sound';

  /// Best-effort system default sound URI. Public so the in-app audio path
  /// can play it when the user hasn't picked a custom sound.
  String get effectiveDefaultSoundUri =>
      _systemDefaultSoundUri ?? _kFallbackDefaultSoundUri;

  // Bridge to MainActivity for MediaStore-backed sound registration. The
  // NotificationManager runs in system_server and cannot read app-private
  // file:// URIs, so we register the sound via MediaStore and use the
  // content:// URI it returns. See MainActivity.kt.
  static const MethodChannel _platform = MethodChannel(
    'com.terabyteai.foodmania/notification_sound',
  );

  /// Convert a local file path into a content:// URI by inserting the file
  /// into MediaStore.Audio. Returns the original path unchanged on non-Android
  /// platforms or if the platform call fails (we'll fall back to the system
  /// default sound in that case).
  Future<String> registerSoundWithSystem(String localPath) async {
    if (!Platform.isAndroid || localPath.isEmpty) return localPath;
    if (localPath.startsWith('content://')) return localPath;
    try {
      final result = await _platform.invokeMethod<String>(
        'registerNotificationSound',
        {'path': localPath},
      );
      if (result != null && result.isNotEmpty) {
        return result;
      }
    } catch (error, stack) {
      debugPrint('registerNotificationSound failed: $error\n$stack');
    }
    return localPath;
  }

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
      await _ensureAndroidPermission();
      _systemDefaultSoundUri = await _fetchSystemDefaultSoundUri();
      await _ensureChannel();
      _ready = true;
    } catch (error, stack) {
      debugPrint('SystemNotificationService init failed: $error\n$stack');
    }
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
      if (granted == true) return;
      await android.requestNotificationsPermission();
    } catch (_) {
      // Best-effort. User can grant later via system settings.
    }
  }

  /// Re-check the notification permission (e.g. after the user returns from
  /// system settings) and request it again if still missing.
  Future<void> ensurePermissionGranted() async {
    await _ensureAndroidPermission();
  }

  /// Update the sound used for the OS notification channel. The Android
  /// notification system bakes the sound onto a channel at creation time and
  /// won't let us change it later, so we derive a new channel ID whenever the
  /// path changes (channels keyed by hashed path). The old channel becomes
  /// unused but stays installed — that's harmless.
  Future<void> configureSound({
    required bool enabled,
    required String soundPath,
  }) async {
    final trimmed = soundPath.trim();
    if (enabled == _activeSoundEnabled && trimmed == _activeSoundPath && _ready) {
      return;
    }
    _activeSoundEnabled = enabled;
    _activeSoundPath = trimmed;
    _activeChannelId = _channelIdForSound(enabled: enabled, soundPath: trimmed);
    if (_ready) {
      await _ensureChannel();
    }
  }

  Future<void> _ensureChannel() async {
    if (!Platform.isAndroid) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    // Always supply a concrete sound URI when sound is enabled. Some OEM
    // Android builds (Xiaomi MIUI, Oppo ColorOS, Vivo FuntouchOS) create
    // silent channels when `sound: null` is passed, even with playSound=true.
    // Using the system default URI explicitly avoids that.
    AndroidNotificationSound? sound;
    if (_activeSoundEnabled) {
      final effectiveUri = _activeSoundPath.isNotEmpty
          ? _uriForPath(_activeSoundPath)
          : effectiveDefaultSoundUri;
      if (effectiveUri.isNotEmpty) {
        sound = UriAndroidNotificationSound(effectiveUri);
      }
    }
    final channel = AndroidNotificationChannel(
      _activeChannelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: _activeSoundEnabled,
      sound: sound,
      enableVibration: true,
    );
    try {
      await android.createNotificationChannel(channel);
    } catch (error) {
      // Fall back to the default channel if the custom URI fails (e.g. the
      // file isn't readable by the system media player). Re-create with the
      // system default sound so the user still gets an alert.
      _activeChannelId = _defaultChannelId;
      AndroidNotificationSound? fallbackSound;
      if (_activeSoundEnabled) {
        fallbackSound = UriAndroidNotificationSound(effectiveDefaultSoundUri);
      }
      final fallback = AndroidNotificationChannel(
        _activeChannelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: _activeSoundEnabled,
        sound: fallbackSound,
        enableVibration: true,
      );
      try {
        await android.createNotificationChannel(fallback);
      } catch (_) {
        // Give up silently — the next show() will simply not have a channel.
      }
    }
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_ready) {
      await initialize();
      if (!_ready) return;
    }
    final androidDetails = AndroidNotificationDetails(
      _activeChannelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: _activeSoundEnabled,
      enableVibration: true,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
    );
    final darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: _activeSoundEnabled,
      sound: _activeSoundEnabled && _activeSoundPath.isNotEmpty
          ? _activeSoundPath
          : null,
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

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  String _channelIdForSound({required bool enabled, required String soundPath}) {
    if (!enabled || soundPath.isEmpty) return _defaultChannelId;
    // Cheap stable hash of the path so that picking the same file twice
    // re-uses the same channel.
    final hash = soundPath.hashCode.abs().toRadixString(36);
    return 'foodmania_orders_$hash';
  }

  String _uriForPath(String path) {
    if (path.startsWith('content://') ||
        path.startsWith('file://') ||
        path.startsWith('android.resource://')) {
      return path;
    }
    // Use Uri.file to encode spaces / non-ASCII characters properly. Android's
    // notification system rejects un-encoded URIs silently (channel created,
    // no sound plays) so this matters.
    return Uri.file(path).toString();
  }
}
