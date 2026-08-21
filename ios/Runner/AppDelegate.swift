import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let controller = window?.rootViewController as! FlutterViewController
    FlutterMethodChannel(
      name: "kopi_kita/device_settings",
      binaryMessenger: controller.binaryMessenger
    ).setMethodCallHandler { call, result in
      guard call.method == "openPrinterSettings" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let url = URL(string: UIApplication.openSettingsURLString) else {
        result(FlutterError(code: "UNAVAILABLE", message: "Settings tidak tersedia", details: nil))
        return
      }
      UIApplication.shared.open(url)
      result(nil)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
