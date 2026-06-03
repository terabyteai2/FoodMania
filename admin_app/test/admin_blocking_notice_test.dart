import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/features/system/admin_blocking_notice_screen.dart';
import 'package:local_pos/src/models/admin_blocking_notice.dart';
import 'package:local_pos/src/models/server_config.dart';
import 'package:local_pos/src/services/cloud_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const audioGlobalChannel = MethodChannel('xyz.luan/audioplayers.global');
  const audioPlayerChannel = MethodChannel('xyz.luan/audioplayers');

  setUpAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(audioGlobalChannel, (_) async => null);
    messenger.setMockMethodCallHandler(audioPlayerChannel, (_) async => null);
  });

  tearDownAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(audioGlobalChannel, null);
    messenger.setMockMethodCallHandler(audioPlayerChannel, null);
  });

  test('AdminBlockingNotice parses wrapped backend response', () {
    final notice = AdminBlockingNotice.fromJson({
      'data': {
        'enabled': true,
        'title': 'Service notice',
        'message': 'Please wait.',
        'updatedAt': '2026-06-02T12:00:00+00:00',
      },
    });

    expect(notice.isBlocking, isTrue);
    expect(notice.title, 'Service notice');
    expect(notice.message, 'Please wait.');
    expect(notice.updatedAt, DateTime.parse('2026-06-02T12:00:00+00:00'));
  });

  test('CloudApiService fetches public admin blocking notice', () async {
    late http.Request captured;
    final service = CloudApiService(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'data': {
              'enabled': true,
              'title': 'Service notice',
              'message': 'Please wait.',
              'updatedAt': null,
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
        deviceToken: '',
        autoSyncIntervalSeconds: 30,
      ),
      serverConfig: ServerConfig(
        serverId: '',
        restaurantId: '',
        outletId: '',
        restaurantName: '',
        outletName: '',
      ),
    );

    final notice = await service.fetchAdminBlockingNotice();

    expect(captured.method, 'GET');
    expect(captured.url.path, '/admin/blocking-notice');
    expect(notice.isBlocking, isTrue);
    service.close();
  });

  test(
    'controller caches active notice and clears only after server disables it',
    () async {
      SharedPreferences.setMockInitialValues({});
      var enabled = true;
      var requestFails = false;
      final service = CloudApiService(
        client: MockClient((request) async {
          if (requestFails) {
            throw http.ClientException('offline');
          }
          return http.Response(
            jsonEncode({
              'data': {
                'enabled': enabled,
                'title': enabled ? 'Service notice' : '',
                'message': enabled ? 'Please wait.' : '',
                'updatedAt': null,
              },
              'error': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final controller = PosAppController(cloudApiService: service)
        ..cloudConfig = CloudConfig(
          baseUrl: 'https://api.example.com',
          enabled: false,
          deviceToken: '',
          autoSyncIntervalSeconds: 30,
        );

      await controller.refreshAdminBlockingNotice();
      var preferences = await SharedPreferences.getInstance();

      expect(controller.hasAdminBlockingNotice, isTrue);
      expect(
        preferences.getString('local_pos_admin_blocking_notice'),
        isNotNull,
      );

      requestFails = true;
      await controller.refreshAdminBlockingNotice();
      preferences = await SharedPreferences.getInstance();

      expect(controller.hasAdminBlockingNotice, isTrue);
      expect(
        preferences.getString('local_pos_admin_blocking_notice'),
        isNotNull,
      );

      requestFails = false;
      enabled = false;
      await controller.refreshAdminBlockingNotice();
      preferences = await SharedPreferences.getInstance();

      expect(controller.hasAdminBlockingNotice, isFalse);
      expect(preferences.getString('local_pos_admin_blocking_notice'), isNull);
      controller.dispose();
    },
  );

  testWidgets('blocking notice screen has no dismiss action', (tester) async {
    var retryCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AdminBlockingNoticeScreen(
          notice: const AdminBlockingNotice(
            enabled: true,
            title: 'Service notice',
            message: 'Please wait while support completes maintenance.',
            updatedAt: null,
          ),
          refreshing: false,
          onRetry: () => retryCount += 1,
        ),
      ),
    );

    expect(find.text('Service notice'), findsOneWidget);
    expect(
      find.text('Please wait while support completes maintenance.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.text('Check again'), findsOneWidget);

    await tester.tap(find.text('Check again'));
    await tester.pump();
    expect(retryCount, 1);
  });
}
