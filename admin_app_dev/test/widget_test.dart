import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';

void main() {
  test('app theme exposes the QuickBytes blue admin color system', () {
    final theme = AppTheme.light();

    expect(theme.colorScheme.primary.toARGB32(), PosColors.primary.toARGB32());
    expect(
      theme.colorScheme.secondary.toARGB32(),
      PosColors.secondary.toARGB32(),
    );
    expect(theme.useMaterial3, isTrue);
  });

  test('mobile shell uses a hamburger side drawer, not a bottom nav', () {
    final app = File('lib/src/app.dart').readAsStringSync();

    // The phone surface dropped the bottom nav for a Petpooja-style left
    // drawer opened from the shared header (see ShellNavScope / AppPageHeader).
    expect(app, isNot(contains('bottomNavigationBar:')));
    expect(app, isNot(contains('_FloatingBottomNav')));
    expect(app, contains('drawer: _AppNavDrawer'));
    expect(app, contains('ShellNavScope('));
  });
}
