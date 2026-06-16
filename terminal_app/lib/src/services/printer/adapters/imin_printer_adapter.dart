import 'package:flutter/foundation.dart';
import 'package:imin_printer/imin_printer.dart';

import '../built_in_printer_adapter.dart';
import '../printer_vendor.dart';

/// Wraps the official `imin_printer` plugin (publisher imin.sg).
///
/// NOT verified on real iMin hardware (none available in this environment)
/// — implemented against the documented API surface only. Needs
/// confirmation on a real device before shipping:
///   - that `printSingleBitmap` accepts our rendered PNG bytes directly
///     (it takes `dynamic img`; iMin's own docs describe byte-array image
///     printing support but the exact accepted encoding isn't pinned down
///     here),
///   - that `getPrinterStatus()`'s `code`/`msg` map reliably distinguishes
///     "no iMin printer present" from "present but busy/error".
class IminPrinterAdapter implements BuiltInPrinterAdapter {
  final IminPrinter _printer = IminPrinter();
  bool _initialized = false;

  @override
  PrinterVendor get vendor => PrinterVendor.imin;

  @override
  Future<bool> isAvailable() async {
    try {
      final ok = await _printer.initPrinter();
      if (ok != true) return false;
      final status = await _printer.getPrinterStatus();
      _initialized = true;
      // TODO(verify-on-imin-hardware): confirm which `code` values mean
      // "ready" vs "no printer" once a real device is available — treating
      // any successful initPrinter() + non-throwing status call as
      // available for now.
      return status.isNotEmpty;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[QB-PRINTER] iMin isAvailable failed: $error');
      }
      return false;
    }
  }

  @override
  Future<void> init() async {
    if (_initialized) return;
    try {
      _initialized = await _printer.initPrinter() ?? false;
    } catch (error) {
      _initialized = false;
      if (kDebugMode) {
        debugPrint('[QB-PRINTER] iMin init failed: $error');
      }
    }
  }

  @override
  Future<bool> printTicketBitmap(Uint8List pngBytes) async {
    try {
      await init();
      if (!_initialized) return false;
      await _printer.printSingleBitmap(pngBytes);
      await _printer.printAndFeedPaper(2);
      await _printer.fullCut();
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[QB-PRINTER] iMin printTicketBitmap failed: $error');
      }
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
  }
}
