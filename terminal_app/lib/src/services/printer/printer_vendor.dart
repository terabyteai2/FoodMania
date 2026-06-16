/// Identifies which built-in-printer vendor library backs the device's
/// thermal printer, if any. This is a device identity, not a connection
/// transport — there is deliberately no USB/Bluetooth/Windows axis here.
enum PrinterVendor { none, sunmi, imin, pax }

extension PrinterVendorLabel on PrinterVendor {
  /// Human-readable vendor name for settings UI ("Detected printer: Sunmi").
  String get label {
    switch (this) {
      case PrinterVendor.sunmi:
        return 'Sunmi';
      case PrinterVendor.imin:
        return 'iMin';
      case PrinterVendor.pax:
        return 'PAX';
      case PrinterVendor.none:
        return 'None';
    }
  }
}
