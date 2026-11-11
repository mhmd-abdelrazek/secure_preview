import Flutter
import UIKit
import TargetConditionals

public class SecurePreviewPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "secure_preview", binaryMessenger: registrar.messenger())
    let instance = SecurePreviewPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "setScreenshotProtection" {
      // iOS has no public API to prevent screenshots. The Flutter widget still
      // masks sensitive content when the app resigns active.
      result(false)
      return
    }
    guard call.method == "checkSecurity" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let isSimulator = TARGET_OS_SIMULATOR != 0
    let isJailbroken = Self.jailbreakIndicatorsFound()
    let screen = UIScreen.main
    let captured = screen.isCaptured
    let externalDisplay = UIScreen.screens.count > 1
    result([
      "rooted": isJailbroken,
      "emulator": isSimulator,
      "developerOptions": false,
      "usbDebugging": false,
      "screenMirroring": captured || externalDisplay,
      "screenRecording": captured,
      "externalDisplay": externalDisplay
    ])
  }

  private static func jailbreakIndicatorsFound() -> Bool {
    #if targetEnvironment(simulator)
    return false
    #else
    let paths = ["/Applications/Cydia.app", "/Library/MobileSubstrate/MobileSubstrate.dylib",
                 "/bin/bash", "/usr/sbin/sshd", "/etc/apt"]
    return paths.contains { FileManager.default.fileExists(atPath: $0) }
    #endif
  }
}
