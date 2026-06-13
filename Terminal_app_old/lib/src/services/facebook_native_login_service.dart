import 'dart:io';

import 'package:flutter/services.dart';

import '../models/facebook_chatbot_config.dart';

enum FacebookNativeLoginStatus { success, cancelled, unavailable, failed }

class FacebookNativeLoginResult {
  const FacebookNativeLoginResult({
    required this.status,
    this.accessToken = '',
  });

  final FacebookNativeLoginStatus status;
  final String accessToken;
}

class FacebookNativeLoginService {
  static const MethodChannel _channel = MethodChannel(
    'com.terabyteai.foodmania/facebook_login',
  );

  Future<FacebookNativeLoginResult> login(
    FacebookChatbotNativeAndroidConfig config,
  ) async {
    if (!Platform.isAndroid || !config.isConfigured) {
      return const FacebookNativeLoginResult(
        status: FacebookNativeLoginStatus.unavailable,
      );
    }
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('login', {
        'appId': config.appId,
        'clientToken': config.clientToken,
        'scopes': config.scopes,
      });
      final status = result?['status']?.toString().trim() ?? '';
      final accessToken = result?['accessToken']?.toString().trim() ?? '';
      if (status == 'success' && accessToken.isNotEmpty) {
        return FacebookNativeLoginResult(
          status: FacebookNativeLoginStatus.success,
          accessToken: accessToken,
        );
      }
      if (status == 'cancelled') {
        return const FacebookNativeLoginResult(
          status: FacebookNativeLoginStatus.cancelled,
        );
      }
      return const FacebookNativeLoginResult(
        status: FacebookNativeLoginStatus.failed,
      );
    } on MissingPluginException {
      return const FacebookNativeLoginResult(
        status: FacebookNativeLoginStatus.unavailable,
      );
    } on PlatformException {
      return const FacebookNativeLoginResult(
        status: FacebookNativeLoginStatus.failed,
      );
    }
  }
}
