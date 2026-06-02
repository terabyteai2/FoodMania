#include "flutter_window.h"

#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <vector>
#include <windows.h>
#include <winspool.h>

#include "flutter/generated_plugin_registrant.h"
#include "flutter/method_channel.h"
#include "flutter/standard_method_codec.h"

namespace {

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) return "";
  const int size = WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, nullptr,
                                       0, nullptr, nullptr);
  std::string result(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, result.data(), size,
                      nullptr, nullptr);
  result.resize(size - 1);
  return result;
}

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) return L"";
  const int size =
      MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, nullptr, 0);
  std::wstring result(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, result.data(), size);
  result.resize(size - 1);
  return result;
}

flutter::EncodableList ListPrinters() {
  DWORD bytes_needed = 0;
  DWORD printer_count = 0;
  EnumPrintersW(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS, nullptr, 4,
                nullptr, 0, &bytes_needed, &printer_count);
  if (bytes_needed == 0) return {};
  std::vector<BYTE> buffer(bytes_needed);
  if (!EnumPrintersW(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS, nullptr, 4,
                     buffer.data(), bytes_needed, &bytes_needed,
                     &printer_count)) {
    return {};
  }
  auto* printers = reinterpret_cast<PRINTER_INFO_4W*>(buffer.data());
  flutter::EncodableList result;
  for (DWORD index = 0; index < printer_count; index++) {
    if (printers[index].pPrinterName != nullptr) {
      result.emplace_back(WideToUtf8(printers[index].pPrinterName));
    }
  }
  return result;
}

bool PrintRawBytes(const std::string& printer_name,
                   const std::vector<uint8_t>& bytes) {
  HANDLE printer = nullptr;
  const std::wstring wide_name = Utf8ToWide(printer_name);
  if (!OpenPrinterW(const_cast<LPWSTR>(wide_name.c_str()), &printer, nullptr)) {
    return false;
  }
  DOC_INFO_1W document = {};
  document.pDocName = const_cast<LPWSTR>(L"Restaurant POS Receipt");
  document.pDatatype = const_cast<LPWSTR>(L"RAW");
  const bool document_started =
      StartDocPrinterW(printer, 1, reinterpret_cast<LPBYTE>(&document)) != 0;
  bool page_started = false;
  bool ok = document_started;
  if (ok) {
    page_started = StartPagePrinter(printer) != FALSE;
    ok = page_started;
  }
  DWORD written = 0;
  if (ok) {
    ok = WritePrinter(printer, const_cast<uint8_t*>(bytes.data()),
                      static_cast<DWORD>(bytes.size()), &written) != FALSE &&
         written == bytes.size();
  }
  if (page_started) EndPagePrinter(printer);
  if (document_started) EndDocPrinter(printer);
  ClosePrinter(printer);
  return ok;
}

void RegisterWindowsPrinterChannel(flutter::FlutterEngine* engine) {
  static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      channel;
  channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          engine->messenger(), "com.terabyteai.foodmania/windows_printer",
          &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [](const auto& call, auto result) {
        if (call.method_name() == "listPrinters") {
          result->Success(flutter::EncodableValue(ListPrinters()));
          return;
        }
        if (call.method_name() == "printBytes") {
          const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (args == nullptr) {
            result->Error("invalid_args", "Printer arguments are required.");
            return;
          }
          const auto name_it = args->find(flutter::EncodableValue("printerName"));
          const auto bytes_it = args->find(flutter::EncodableValue("bytes"));
          if (name_it == args->end() || bytes_it == args->end()) {
            result->Error("invalid_args", "Printer name and bytes are required.");
            return;
          }
          const auto* name = std::get_if<std::string>(&name_it->second);
          const auto* bytes = std::get_if<std::vector<uint8_t>>(&bytes_it->second);
          if (name == nullptr || bytes == nullptr) {
            result->Error("invalid_args", "Printer arguments are malformed.");
            return;
          }
          result->Success(flutter::EncodableValue(PrintRawBytes(*name, *bytes)));
          return;
        }
        result->NotImplemented();
      });
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  RegisterWindowsPrinterChannel(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
