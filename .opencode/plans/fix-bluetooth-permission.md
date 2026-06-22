# Fix: Bluetooth Permission Required Error

**File:** `admin_app/lib/src/services/printer_service.dart`

## Problem

`_ensureBluetoothReady()` relies on `PrintBluetoothThermal.isPermissionBluetoothGranted` (plugin's broken check) then requests via `permission_handler`. If the user denies once, Android auto-denies subsequent requests without showing the dialog. Plugins `isPermissionBluetoothGranted` returns false, `permission_handler.request()` returns denied silently → "Bluetooth permission is required." with no path forward.

## Fix

Replace the permission block in `_ensureBluetoothReady()` (lines 2427-2464) with a dedicated `_requestBluetoothPermission()` method that uses `permission_handler` directly and handles all three states:

### New method: `_requestBluetoothPermission()`

```dart
Future<void> _requestBluetoothPermission({String? attemptId}) async {
  final id = attemptId ?? _nextPrinterAttempt('request-bt-permission');
  void log(String message) {
    if (kDebugMode) debugPrint('[QB-PRINTER-DIAG] $id $message');
  }

  var connectStatus = await Permission.bluetoothConnect.status;
  var scanStatus = await Permission.bluetoothScan.status;

  log('initial: connect=$connectStatus scan=$scanStatus');

  if (connectStatus.isGranted && scanStatus.isGranted) return;

  // Permanently denied → redirect to system settings
  if (connectStatus.isPermanentlyDenied || scanStatus.isPermanentlyDenied) {
    log('permanently denied — redirecting to settings');
    await openAppSettings();
    throw PrinterException(
      'Bluetooth permission was permanently denied. '
      'Please enable it in Settings > Nearby devices.',
    );
  }

  // Denied but not permanent → show system dialog
  log('requesting…');
  final statuses = await [
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
  ].request();

  connectStatus = statuses[Permission.bluetoothConnect] ?? connectStatus;
  scanStatus = statuses[Permission.bluetoothScan] ?? scanStatus;
  log('result: connect=$connectStatus scan=$scanStatus');

  if (!connectStatus.isGranted || !scanStatus.isGranted) {
    throw PrinterException('Bluetooth permission is required.');
  }
}
```

### Modified: `_ensureBluetoothReady()`

Replace the current Android permission block (lines 2427-2464):

```dart
if (Platform.isAndroid) {
  await _requestBluetoothPermission(attemptId: attemptId);
}
```

That's it. The Bluetooth-enabled check stays unchanged below.

## What changes

| Before | After |
|--------|-------|
| Relies on plugin's `isPermissionBluetoothGranted` (only checks `BLUETOOTH_CONNECT`, cached per-call) | Uses `permission_handler` directly for both `BLUETOOTH_CONNECT` + `BLUETOOTH_SCAN` |
| `.request()` returns denied silently on repeat attempts | Checks `isPermanentlyDenied` → redirects to system settings with clear message |
| No feedback loop for user | `openAppSettings()` gives user a clear path to fix it |
| 38 lines of inline logic | 32 lines in a focused method |

## No other files touched

No AndroidManifest, build.gradle, or plugin changes needed.
