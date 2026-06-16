import 'package:flutter/foundation.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

import '../built_in_printer_adapter.dart';
import '../printer_vendor.dart';

/// Wraps `sunmi_printer_plus`'s instance-based `SunmiPrinterPlus` facade
/// (NOT the deprecated static `SunmiPrinter` class — as of v4.1.1 most of
/// its static methods, including `bindingPrinter()`/`initPrinter()`, are
/// stubs that always return null; `SunmiPrinterPlus.rebindPrinter()` is the
/// real, current bind/availability check).
///
/// This binds to the same `woyou.aidlservice.jiuiv5` AIDL service our
/// previous hand-rolled Kotlin code talked to directly. Because many
/// generic/clone Android POS terminals sold in this market implement that
/// same AIDL service for app compatibility (not just Sunmi-branded
/// hardware), this adapter's detection doubles as covering those clones —
/// no manufacturer-string matching needed.
class SunmiPrinterAdapter implements BuiltInPrinterAdapter {
  final SunmiPrinterPlus _printer = SunmiPrinterPlus();
  bool _bound = false;

  @override
  PrinterVendor get vendor => PrinterVendor.sunmi;

  @override
  Future<bool> isAvailable() async {
    try {
      _bound = await _printer.rebindPrinter();
      return _bound;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[QB-PRINTER] Sunmi isAvailable failed: $error');
      }
      return false;
    }
  }

  @override
  Future<void> init() async {
    if (_bound) return;
    try {
      _bound = await _printer.rebindPrinter();
    } catch (error) {
      _bound = false;
      if (kDebugMode) {
        debugPrint('[QB-PRINTER] Sunmi init failed: $error');
      }
    }
  }

  @override
  Future<bool> printTicketBitmap(Uint8List pngBytes) async {
    try {
      await init();
      if (!_bound) return false;
      final printed = await _printer.printImage(
        pngBytes,
        align: SunmiPrintAlign.CENTER,
      );
      if (printed == null) return false;
      await _printer.lineWrap(times: 2);
      await _printer.cutPaper();
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[QB-PRINTER] Sunmi printTicketBitmap failed: $error');
      }
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    _bound = false;
  }
}
