import 'package:flutter/services.dart';

/// A paired Bluetooth device reported by the native WinRT RFCOMM channel.
class BtDevice {
  const BtDevice({required this.name, required this.address});
  final String name;

  /// Opaque device id used to reconnect (a WinRT DeviceInformation Id).
  final String address;
}

/// Dart wrapper over the native `bt_printer` MethodChannel (Windows runner,
/// WinRT RFCOMM / Bluetooth-Classic SPP). Mirrors the `windows_printer` USB
/// channel: enumerate paired devices, then stream raw ESC/POS bytes.
///
/// Bluetooth on Windows for Classic/SPP thermal printers has no maintained
/// Flutter pub package, so the transport is a small native channel we own.
class BtPrinter {
  BtPrinter._();

  static const MethodChannel _channel =
      MethodChannel('com.terabyteai.foodmania/bt_printer');

  /// Paired Bluetooth serial (SPP) devices. Returns empty on platforms where
  /// the channel isn't implemented.
  static Future<List<BtDevice>> listPaired() async {
    try {
      final result =
          await _channel.invokeMethod<List<dynamic>>('listPaired') ?? const [];
      return result.map((entry) {
        final map = Map<Object?, Object?>.from(entry as Map);
        return BtDevice(
          name: (map['name'] as String?)?.trim() ?? 'Bluetooth printer',
          address: (map['address'] as String?) ?? '',
        );
      }).toList();
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  /// Opens an RFCOMM socket to [address] and writes [bytes]. Returns false on
  /// any failure (unpaired / out of range / not an SPP printer).
  static Future<bool> printBytes(String address, List<int> bytes) async {
    try {
      final ok = await _channel.invokeMethod<bool>('printBytes', {
        'address': address,
        'bytes': Uint8List.fromList(bytes),
      });
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

/// Minimal ESC/POS payload to validate a Bluetooth connection end-to-end
/// (init → centered title → text → feed → cut). Full rich tickets go through
/// the reused PrinterService raster pipeline once BT connectivity is confirmed.
List<int> escPosTestTicket(String outletName) {
  final bytes = <int>[];
  bytes.addAll([0x1B, 0x40]); // ESC @  — initialize
  bytes.addAll([0x1B, 0x61, 0x01]); // ESC a 1 — center
  bytes.addAll([0x1B, 0x21, 0x30]); // ESC ! — double height/width
  bytes.addAll('QuickBytes\n'.codeUnits);
  bytes.addAll([0x1B, 0x21, 0x00]); // normal
  bytes.addAll('$outletName\n'.codeUnits);
  bytes.addAll('Bluetooth test print\n'.codeUnits);
  bytes.addAll('----------------\n'.codeUnits);
  bytes.addAll([0x1B, 0x64, 0x04]); // ESC d 4 — feed 4 lines
  bytes.addAll([0x1D, 0x56, 0x00]); // GS V 0 — full cut
  return bytes;
}
