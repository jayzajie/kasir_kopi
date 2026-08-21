#include "flutter_window.h"

#include <optional>
#include <shellapi.h>

#include "flutter/generated_plugin_registrant.h"
#include "raw_printer.h"

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
  settings_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "kopi_kita/device_settings",
          &flutter::StandardMethodCodec::GetInstance());
  settings_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "rawPrint") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!args) {
            result->Error("INVALID_ARGS", "Data print tidak valid");
            return;
          }
          const auto printer_it = args->find(flutter::EncodableValue("printerName"));
          const auto document_it = args->find(flutter::EncodableValue("documentName"));
          const auto data_it = args->find(flutter::EncodableValue("data"));
          if (printer_it == args->end() || document_it == args->end() ||
              data_it == args->end()) {
            result->Error("INVALID_ARGS", "Data print tidak lengkap");
            return;
          }
          const auto* printer = std::get_if<std::string>(&printer_it->second);
          const auto* document = std::get_if<std::string>(&document_it->second);
          const auto* data = std::get_if<std::vector<uint8_t>>(&data_it->second);
          if (!printer || !document || !data) {
            result->Error("INVALID_ARGS", "Tipe data print tidak valid");
            return;
          }
          std::string error;
          if (RawPrint(*printer, *document, *data, &error)) {
            result->Success();
          } else {
            result->Error("PRINT_FAILED", error);
          }
          return;
        }
        if (call.method_name() != "openPrinterSettings") {
          result->NotImplemented();
          return;
        }
        const auto* connection =
            std::get_if<std::string>(call.arguments());
        const wchar_t* page = connection && *connection == "bluetooth"
                                  ? L"ms-settings:bluetooth"
                                  : L"ms-settings:printers";
        auto opened = reinterpret_cast<INT_PTR>(
            ShellExecute(GetHandle(), L"open", page, nullptr, nullptr,
                         SW_SHOWNORMAL));
        if (opened > 32) {
          result->Success();
        } else {
          result->Error("UNAVAILABLE", "Pengaturan printer tidak tersedia");
        }
      });
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
    settings_channel_.reset();
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
