import Cocoa
import FlutterMacOS

private func rawPrintMac(printer: String, title: String, data: Data) -> (Bool, String?) {
  guard let handle = dlopen("/usr/lib/libcups.2.dylib", RTLD_NOW) else {
    return (false, "libcups tidak ditemukan")
  }
  defer { dlclose(handle) }

  typealias CupsAddOption = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>, Int32, UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> Int32
  typealias CupsFreeOptions = @convention(c) (Int32, UnsafeMutableRawPointer?) -> Void
  typealias CupsPrintFile = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>, UnsafePointer<CChar>, Int32, UnsafeMutableRawPointer?) -> Int32
  typealias CupsLastErrorString = @convention(c) () -> UnsafePointer<CChar>?

  let addOption = unsafeBitCast(dlsym(handle, "cupsAddOption"), to: CupsAddOption.self)
  let freeOptions = unsafeBitCast(dlsym(handle, "cupsFreeOptions"), to: CupsFreeOptions.self)
  let printFile = unsafeBitCast(dlsym(handle, "cupsPrintFile"), to: CupsPrintFile.self)
  let lastError = unsafeBitCast(dlsym(handle, "cupsLastErrorString"), to: CupsLastErrorString.self)

  let tempFile = NSTemporaryDirectory() + UUID().uuidString + ".bin"
  do {
    try data.write(to: URL(fileURLWithPath: tempFile))
  } catch {
    return (false, error.localizedDescription)
  }
  defer { try? FileManager.default.removeItem(atPath: tempFile) }

  var options: UnsafeMutableRawPointer? = nil
  let numOptions = addOption("raw", "", 0, &options)
  let jobId = printFile(printer, tempFile, title, numOptions, options)
  freeOptions(numOptions, options)

  if jobId > 0 {
    return (true, nil)
  } else {
    let err = lastError().flatMap { String(cString: $0) } ?? "Gagal mengirim data ke printer"
    return (false, err)
  }
}

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let deviceChannel = FlutterMethodChannel(
      name: "kopi_kita/device_settings",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    deviceChannel.setMethodCallHandler { call, result in
      if call.method == "rawPrint" {
        guard let args = call.arguments as? [String: Any],
              let printerName = args["printerName"] as? String,
              let docName = args["documentName"] as? String,
              let flutterData = args["data"] as? FlutterStandardTypedData else {
          result(FlutterError(code: "INVALID_ARGS", message: "Data print tidak lengkap/valid", details: nil))
          return
        }
        let (ok, err) = rawPrintMac(printer: printerName, title: docName, data: flutterData.data)
        if ok {
          result(nil)
        } else {
          result(FlutterError(code: "PRINT_FAILED", message: err ?? "Gagal mencetak", details: nil))
        }
      } else if call.method == "openPrinterSettings" {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.printfax") {
          NSWorkspace.shared.open(url)
        }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
