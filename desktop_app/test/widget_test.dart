// Smoke test for the desktop theme layer. The full DesktopApp needs SQLite FFI
// + network, so it is exercised on Windows (see plan Verification), not here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickbytes_desktop/desktop/theme/desk_theme.dart';

void main() {
  test('desk theme builds with the blue brand primary', () {
    final theme = deskThemeData();
    expect(theme, isA<ThemeData>());
    expect(PosColors.primary, const Color(0xFF2F4FE0));
  });
}
