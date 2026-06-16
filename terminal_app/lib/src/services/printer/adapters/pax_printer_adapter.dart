import 'package:flutter/foundation.dart';
import 'package:flutter_pax_printer_utility/flutter_pax_printer_utility.dart';

import '../built_in_printer_adapter.dart';
import '../printer_vendor.dart';

/// Wraps the community `flutter_pax_printer_utility` plugin (wraps PAX's
/// NeptuneLiteApi SDK) — no official PAX Flutter plugin exists.
///
/// NOT verified on real PAX hardware (none available in this environment)
/// — implemented against the documented API surface only. Needs
/// confirmation on a real device before shipping:
///   - that `printBitmap(Uint8List)` accepts our rendered PNG bytes
///     directly rather than requiring raw decoded pixel data,
///   - the plugin's README asks for `minifyEnabled=false` /
///     `shrinkResources=false` for release builds, which conflicts with
///     this app's `isMinifyEnabled = true` release config (see
///     android/app/proguard-rules.pro) — try targeted `-keep class
///     com.pax.** { *; }` rules first; only disable minification if a
///     release build crashes on PAX hardware.
class PaxPrinterAdapter implements BuiltInPrinterAdapter {
  bool _initialized = false;

  @override
  PrinterVendor get vendor => PrinterVendor.pax;

  @override
  Future<bool> isAvailable() async {
    try {
      final ok = await FlutterPaxPrinterUtility.init;
      _initialized = ok ?? false;
      return _initialized;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[QB-PRINTER] PAX isAvailable failed: $error');
      }
      return false;
    }
  }

  @override
  Future<void> init() async {
    if (_initialized) return;
    try {
      _initialized = await FlutterPaxPrinterUtility.init ?? false;
    } catch (error) {
      _initialized = false;
      if (kDebugMode) {
        debugPrint('[QB-PRINTER] PAX init failed: $error');
      }
    }
  }

  @override
  Future<bool> printTicketBitmap(Uint8List pngBytes) async {
    try {
      await init();
      if (!_initialized) return false;
      final printed = await FlutterPaxPrinterUtility.printBitmap(pngBytes);
      if (printed != true) return false;
      // mode 1 == full cut on most PAX firmware; verify against the real
      // device once available.
      await FlutterPaxPrinterUtility.cutPaper(1);
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[QB-PRINTER] PAX printTicketBitmap failed: $error');
      }
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
  }
}
