import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('terminal app has no active Bluetooth dependency or permission', () {
    final pubspec = _read('pubspec.yaml');
    final manifest = _read('android/app/src/main/AndroidManifest.xml');

    expect(pubspec, isNot(contains('print_bluetooth_thermal')));
    expect(pubspec, isNot(contains('flutter_bluetooth_serial')));
    expect(manifest, isNot(contains('android.permission.BLUETOOTH')));
  });

  test('terminal shell exposes only Orders, Menu, Home, and More tabs', () {
    final app = _read('lib/src/app.dart');

    expect(app, contains('enum _AppTab { orders, menu, home, settings }'));
    expect(app, contains('bottomNavigationBar: _FloatingBottomNav'));
    expect(app, contains("'Orders'"));
    expect(app, contains("'Menu'"));
    expect(app, contains("'Home'"));
    expect(app, contains("'More'"));
    expect(app, isNot(contains('_AppTab.stock')));
  });

  test('terminal update channel and APK filename are terminal-specific', () {
    final api = _read('lib/src/services/cloud_api_service.dart');
    final installer = _read(
      'lib/src/services/app_update_installer_service.dart',
    );

    expect(api, contains("queryParameters: const {'app': 'terminal'}"));
    expect(installer, contains('quickbites-terminal-'));
  });
}
