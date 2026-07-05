#ifndef RUNNER_BT_PRINTER_H_
#define RUNNER_BT_PRINTER_H_

#include <flutter/flutter_engine.h>

namespace bt_printer {

// Registers the "com.terabyteai.foodmania/bt_printer" MethodChannel, a native
// WinRT RFCOMM (Bluetooth-Classic / SPP) transport for thermal printers. See
// bt_printer.cpp for the on-Windows verification notes.
void RegisterBtPrinterChannel(flutter::FlutterEngine* engine);

}  // namespace bt_printer

#endif  // RUNNER_BT_PRINTER_H_
