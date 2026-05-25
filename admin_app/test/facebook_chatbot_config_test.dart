import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:local_pos/src/models/facebook_chatbot_config.dart';
import 'package:local_pos/src/models/server_config.dart';
import 'package:local_pos/src/services/cloud_api_service.dart';

void main() {
  test('FacebookChatbotConfig parses masked backend response', () {
    final config = FacebookChatbotConfig.fromJson({
      'data': {
        'isConfigured': true,
        'isEnabled': true,
        'orderingEnabled': false,
        'pageId': 'page-1',
        'pageName': 'Cafe Page',
        'tokenPreview': 'EAA…abcd',
      },
    });

    expect(config.isConfigured, isTrue);
    expect(config.isEnabled, isTrue);
    expect(config.orderingEnabled, isFalse);
    expect(config.pageName, 'Cafe Page');
    expect(config.tokenPreview, 'EAA…abcd');
  });

  test('FacebookChatbotOAuthStart parses backend response', () {
    final start = FacebookChatbotOAuthStart.fromJson({
      'data': {
        'authorizationUrl': 'https://facebook.example/oauth',
        'expiresInSeconds': 900,
      },
    });

    expect(start.authorizationUrl, 'https://facebook.example/oauth');
    expect(start.expiresInSeconds, 900);
  });

  test('CloudApiService updates Facebook chatbot config with PUT', () async {
    late http.Request captured;
    final service = CloudApiService(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'data': {
              'isConfigured': true,
              'isEnabled': true,
              'orderingEnabled': true,
              'pageId': 'page-1',
              'pageName': 'Cafe Page',
              'tokenPreview': 'EAA…abcd',
            },
            'error': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    service.configure(
      cloudConfig: CloudConfig(
        baseUrl: 'https://api.example.com',
        enabled: true,
        deviceToken: 'device-token',
        autoSyncIntervalSeconds: 30,
      ),
      serverConfig: ServerConfig(
        serverId: 'server-1',
        restaurantId: 'restaurant-1',
        outletId: 'outlet-1',
        restaurantName: 'Cafe',
        outletName: 'Cafe',
      ),
    );

    final config = await service.updateFacebookChatbotConfig(
      pageAccessToken: 'page-token',
      isEnabled: true,
      orderingEnabled: true,
    );

    expect(config.pageId, 'page-1');
    expect(captured.method, 'PUT');
    expect(captured.url.path, '/admin/chatbot/facebook');
    expect(captured.headers['Authorization'], 'Bearer device-token');
    expect(jsonDecode(captured.body)['pageAccessToken'], 'page-token');
  });

  test('CloudApiService starts Facebook OAuth with POST', () async {
    late http.Request captured;
    final service = CloudApiService(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'data': {
              'authorizationUrl': 'https://facebook.example/oauth',
              'expiresInSeconds': 900,
            },
            'error': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    service.configure(
      cloudConfig: CloudConfig(
        baseUrl: 'https://api.example.com',
        enabled: true,
        deviceToken: 'device-token',
        autoSyncIntervalSeconds: 30,
      ),
      serverConfig: ServerConfig(
        serverId: 'server-1',
        restaurantId: 'restaurant-1',
        outletId: 'outlet-1',
        restaurantName: 'Cafe',
        outletName: 'Cafe',
      ),
    );

    final start = await service.startFacebookChatbotOAuth();

    expect(start.authorizationUrl, 'https://facebook.example/oauth');
    expect(captured.method, 'POST');
    expect(captured.url.path, '/admin/chatbot/facebook/oauth/start');
    expect(captured.headers['Authorization'], 'Bearer device-token');
  });
}
