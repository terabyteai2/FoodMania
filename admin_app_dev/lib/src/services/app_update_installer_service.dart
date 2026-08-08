import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/app_update_info.dart';

class AppRuntimeInfo {
  const AppRuntimeInfo({
    required this.supported,
    required this.versionName,
    required this.versionCode,
  });

  final bool supported;
  final String versionName;
  final int versionCode;
}

class AppUpdateInstallerService {
  AppUpdateInstallerService({http.Client? client})
    : _client = client ?? http.Client();

  static const MethodChannel _channel = MethodChannel(
    'com.terabyteai.foodmania/app_update',
  );

  final http.Client _client;

  Future<AppRuntimeInfo> runtimeInfo() async {
    if (!Platform.isAndroid) {
      return AppRuntimeInfo(supported: false, versionName: '', versionCode: 0);
    }
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'runtimeInfo',
      );
      return AppRuntimeInfo(
        supported: true,
        versionName: result?['versionName']?.toString() ?? '',
        versionCode: _intValue(result?['versionCode']),
      );
    } catch (_) {
      return AppRuntimeInfo(supported: true, versionName: '', versionCode: 0);
    }
  }

  Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('canRequestPackageInstalls') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openInstallPermissionSettings');
  }

  Future<String> downloadApk(AppUpdateInfo update) async {
    final uri = Uri.parse(update.apkUrl);
    final request = http.Request('GET', uri);
    final response = await _client
        .send(request)
        .timeout(
          Duration(seconds: 60),
          onTimeout: () {
            throw TimeoutException('APK download timed out.');
          },
        );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('APK download failed: HTTP ${response.statusCode}');
    }

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/quickbites-admin-${update.versionCode}.apk',
    );
    final sink = file.openWrite();
    try {
      await response.stream.pipe(sink);
    } catch (_) {
      await sink.close();
      rethrow;
    }
    final bytes = await file.length();
    if (bytes <= 0) {
      throw Exception('Downloaded APK is empty.');
    }
    return file.path;
  }

  Future<void> installApk(String path) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('installApk', {'path': path});
  }

  void close() {
    _client.close();
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
