#ifndef RUNNER_RAW_PRINTER_H_
#define RUNNER_RAW_PRINTER_H_

#include <cstdint>
#include <string>
#include <vector>

// Sends ESC/POS bytes without Windows rendering them as a document.
bool RawPrint(const std::string& printer_name,
              const std::string& document_name,
              const std::vector<uint8_t>& data,
              std::string* error);

#endif  // RUNNER_RAW_PRINTER_H_
