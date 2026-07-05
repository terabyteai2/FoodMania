// Bluetooth-Classic (SPP / RFCOMM) thermal-printer transport for Windows,
// exposed to Dart as the "com.terabyteai.foodmania/bt_printer" MethodChannel
// (mirrors the USB `windows_printer` channel in flutter_window.cpp).
//
// ─────────────────────────────────────────────────────────────────────────────
// ⚠ VERIFY ON WINDOWS. This file is written on a Linux host with no MSVC /
// Windows SDK, so it is UNCOMPILED. It uses the canonical C++/WinRT RFCOMM SPP
// client pattern and should build against the Windows 10/11 SDK, but expect to:
//   1. Confirm the target printer is Bluetooth **Classic/SPP** (not BLE — BLE
//      needs a GATT path instead).
//   2. Re-check threading: the Flutter runner main.cpp initializes COM as STA,
//      and these calls block via `.get()` on the platform thread. If you hit a
//      deadlock, move ListPairedSpp/PrintBytesBt onto a worker thread (with its
//      own MTA apartment) and marshal the MethodResult back via the engine's
//      task runner.
//   3. Ensure the app manifest declares the `bluetooth` device capability if
//      required by your Windows version.
// The Dart side (lib/desktop/printing/bt_printer_channel.dart) + Settings UI are
// compiled and analyzer-clean; this native half is the piece needing a device.
// ─────────────────────────────────────────────────────────────────────────────

#include "bt_printer.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Devices.Enumeration.h>
#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Devices.Bluetooth.Rfcomm.h>
#include <winrt/Windows.Networking.Sockets.h>
#include <winrt/Windows.Storage.Streams.h>

namespace {

using winrt::Windows::Devices::Bluetooth::Rfcomm::RfcommDeviceService;
using winrt::Windows::Devices::Bluetooth::Rfcomm::RfcommServiceId;
using winrt::Windows::Devices::Enumeration::DeviceInformation;
using winrt::Windows::Devices::Enumeration::DeviceInformationCollection;
using winrt::Windows::Networking::Sockets::SocketProtectionLevel;
using winrt::Windows::Networking::Sockets::StreamSocket;
using winrt::Windows::Storage::Streams::DataWriter;

std::string HStringToUtf8(const winrt::hstring& value) {
  return winrt::to_string(value);
}

// Enumerate paired devices that advertise the Serial Port (SPP) RFCOMM service.
flutter::EncodableList ListPairedSpp() {
  flutter::EncodableList out;
  try {
    const auto selector =
        RfcommDeviceService::GetDeviceSelector(RfcommServiceId::SerialPort());
    const DeviceInformationCollection devices =
        DeviceInformation::FindAllAsync(selector).get();
    for (auto const& device : devices) {
      flutter::EncodableMap entry;
      entry[flutter::EncodableValue("name")] =
          flutter::EncodableValue(HStringToUtf8(device.Name()));
      entry[flutter::EncodableValue("address")] =
          flutter::EncodableValue(HStringToUtf8(device.Id()));
      out.push_back(flutter::EncodableValue(std::move(entry)));
    }
  } catch (...) {
    // Bluetooth off / no radio / access denied → report no devices.
  }
  return out;
}

// Open an RFCOMM socket to the SPP service on [device_id] and stream [bytes].
bool PrintBytesBt(const std::string& device_id,
                  const std::vector<uint8_t>& bytes) {
  try {
    const winrt::hstring id = winrt::to_hstring(device_id);
    const RfcommDeviceService service = RfcommDeviceService::FromIdAsync(id).get();
    if (!service) return false;

    StreamSocket socket;
    socket.ConnectAsync(service.ConnectionHostName(),
                        service.ConnectionServiceName(),
                        SocketProtectionLevel::
                            BluetoothEncryptionAllowNullAuthentication)
        .get();

    DataWriter writer(socket.OutputStream());
    writer.WriteBytes(winrt::array_view<const uint8_t>(
        bytes.data(), bytes.data() + bytes.size()));
    writer.StoreAsync().get();
    writer.FlushAsync().get();
    writer.DetachStream();
    socket.Close();
    return true;
  } catch (...) {
    return false;
  }
}

}  // namespace

namespace bt_printer {

void RegisterBtPrinterChannel(flutter::FlutterEngine* engine) {
  static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      channel;
  channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(), "com.terabyteai.foodmania/bt_printer",
      &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([](const auto& call, auto result) {
    if (call.method_name() == "listPaired") {
      result->Success(flutter::EncodableValue(ListPairedSpp()));
      return;
    }
    if (call.method_name() == "printBytes") {
      const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
      if (args == nullptr) {
        result->Error("invalid_args", "Bluetooth arguments are required.");
        return;
      }
      const auto address_it = args->find(flutter::EncodableValue("address"));
      const auto bytes_it = args->find(flutter::EncodableValue("bytes"));
      if (address_it == args->end() || bytes_it == args->end()) {
        result->Error("invalid_args", "address and bytes are required.");
        return;
      }
      const auto* address = std::get_if<std::string>(&address_it->second);
      const auto* bytes =
          std::get_if<std::vector<uint8_t>>(&bytes_it->second);
      if (address == nullptr || bytes == nullptr) {
        result->Error("invalid_args", "Bluetooth arguments are malformed.");
        return;
      }
      result->Success(flutter::EncodableValue(PrintBytesBt(*address, *bytes)));
      return;
    }
    result->NotImplemented();
  });
}

}  // namespace bt_printer
