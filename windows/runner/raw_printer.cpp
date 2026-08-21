#include "raw_printer.h"

#include <windows.h>
#include <winspool.h>

namespace {
std::wstring Wide(const std::string& value) {
  if (value.empty()) return {};
  const int size = MultiByteToWideChar(CP_UTF8, 0, value.data(),
                                       static_cast<int>(value.size()), nullptr, 0);
  std::wstring result(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.data(), static_cast<int>(value.size()),
                      result.data(), size);
  return result;
}

std::string LastErrorText(const char* action) {
  return std::string(action) + " gagal (Windows error " +
         std::to_string(GetLastError()) + ")";
}
}  // namespace

bool RawPrint(const std::string& printer_name,
              const std::string& document_name,
              const std::vector<uint8_t>& data,
              std::string* error) {
  if (printer_name.empty() || data.empty()) {
    *error = "Nama printer atau data struk kosong";
    return false;
  }

  const auto printer = Wide(printer_name);
  HANDLE handle = nullptr;
  if (!OpenPrinterW(const_cast<LPWSTR>(printer.c_str()), &handle, nullptr)) {
    *error = LastErrorText("OpenPrinter");
    return false;
  }

  const auto document = Wide(document_name);
  DOC_INFO_1W info{};
  info.pDocName = const_cast<LPWSTR>(document.c_str());
  info.pDatatype = const_cast<LPWSTR>(L"RAW");
  if (!StartDocPrinterW(handle, 1, reinterpret_cast<LPBYTE>(&info))) {
    *error = LastErrorText("StartDocPrinter");
    ClosePrinter(handle);
    return false;
  }

  bool success = false;
  if (StartPagePrinter(handle)) {
    DWORD written = 0;
    success = WritePrinter(handle, const_cast<uint8_t*>(data.data()),
                           static_cast<DWORD>(data.size()), &written) &&
              written == data.size();
    if (!success) *error = LastErrorText("WritePrinter");
    EndPagePrinter(handle);
  } else {
    *error = LastErrorText("StartPagePrinter");
  }
  EndDocPrinter(handle);
  ClosePrinter(handle);
  return success;
}
