import 'dart:io';

import 'package:flutter/foundation.dart';

bool routesToDesktopPos({
  required bool isWeb,
  required bool isWindows,
  required bool isLinux,
  required bool isMacOS,
}) =>
    !isWeb && (isWindows || isLinux || isMacOS);

bool get isNativeDesktop => routesToDesktopPos(
  isWeb: kIsWeb,
  isWindows: Platform.isWindows,
  isLinux: Platform.isLinux,
  isMacOS: Platform.isMacOS,
);

bool get isWindowsDesktop => !kIsWeb && Platform.isWindows;
