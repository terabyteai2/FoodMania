import 'dart:typed_data';

import 'printer_vendor.dart';

/// Common surface every vendor-specific built-in printer adapter implements.
///
/// There is exactly one adapter instance bound to the device's detected
/// vendor at a time — callers never iterate or fall back across adapters.
/// See [printer_vendor_detector.dart] for the one-shot detection logic that
/// picks which adapter to use.
abstract class BuiltInPrinterAdapter {
  PrinterVendor get vendor;

  /// One-shot availability check used during vendor detection. Should be
  /// cheap and not throw — return `false` on any failure.
  Future<bool> isAvailable();

  /// Idempotent setup (binds/opens the underlying printer service). Safe to
  /// call multiple times.
  Future<void> init();

  /// Prints a rendered ticket image (PNG bytes, as produced by
  /// [TicketBitmapRenderer]) and feeds/cuts the paper. Returns `true` only
  /// when the vendor library reports the print call succeeded.
  Future<bool> printTicketBitmap(Uint8List pngBytes);

  /// Releases any held resources. Safe to call even if never initialized.
  Future<void> dispose();
}
