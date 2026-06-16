import 'dart:io';

import 'package:flutter/foundation.dart';

import 'adapters/imin_printer_adapter.dart';
import 'adapters/pax_printer_adapter.dart';
import 'adapters/sunmi_printer_adapter.dart';
import 'built_in_printer_adapter.dart';
import 'printer_vendor.dart';

/// Detects which built-in printer vendor is present on this device, once.
///
/// This is a single probe pass, not a runtime fallback chain: each
/// adapter's [BuiltInPrinterAdapter.isAvailable] is tried in turn (Sunmi ->
/// iMin -> PAX, just as iteration order for this one pass) and the first
/// one that reports available wins. The result should be cached by the
/// caller ([PrinterService]) for the process lifetime and only re-probed
/// via an explicit user action (e.g. "Re-scan printer" in settings).
class PrinterVendorDetector {
  PrinterVendorDetector({Duration? timeout})
    : _timeout = timeout ?? const Duration(seconds: 3);

  final Duration _timeout;

  late final List<BuiltInPrinterAdapter> _adapters = [
    SunmiPrinterAdapter(),
    IminPrinterAdapter(),
    PaxPrinterAdapter(),
  ];

  Map<PrinterVendor, BuiltInPrinterAdapter> get adaptersByVendor => {
    for (final adapter in _adapters) adapter.vendor: adapter,
  };

  Future<PrinterVendor> detect() async {
    if (!Platform.isAndroid) return PrinterVendor.none;
    for (final adapter in _adapters) {
      try {
        final available = await adapter.isAvailable().timeout(_timeout);
        if (available) return adapter.vendor;
      } catch (error) {
        if (kDebugMode) {
          debugPrint(
            '[QB-PRINTER] vendor probe failed for ${adapter.vendor.label}: $error',
          );
        }
      }
    }
    return PrinterVendor.none;
  }
}
