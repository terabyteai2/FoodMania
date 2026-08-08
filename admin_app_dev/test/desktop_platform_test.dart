import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/core/platform/desktop_platform.dart';

void main() {
  test('native desktop platforms route to the fresh POS shell', () {
    expect(
      routesToDesktopPos(
        isWeb: false,
        isWindows: true,
        isLinux: false,
        isMacOS: false,
      ),
      isTrue,
    );
    expect(
      routesToDesktopPos(
        isWeb: false,
        isWindows: false,
        isLinux: true,
        isMacOS: false,
      ),
      isTrue,
    );
    expect(
      routesToDesktopPos(
        isWeb: false,
        isWindows: false,
        isLinux: false,
        isMacOS: true,
      ),
      isTrue,
    );
  });

  test('mobile and web stay on the existing app shell', () {
    expect(
      routesToDesktopPos(
        isWeb: false,
        isWindows: false,
        isLinux: false,
        isMacOS: false,
      ),
      isFalse,
    );
    expect(
      routesToDesktopPos(
        isWeb: true,
        isWindows: true,
        isLinux: false,
        isMacOS: false,
      ),
      isFalse,
    );
  });
}
