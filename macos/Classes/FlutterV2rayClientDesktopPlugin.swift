import Cocoa
import FlutterMacOS

public class FlutterV2rayClientDesktopPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_v2ray_client_desktop", binaryMessenger: registrar.messenger)
    let instance = FlutterV2rayClientDesktopPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func getResourcePath() -> String? {
      let bundle = Bundle(for: FlutterV2rayClientDesktopPlugin.self)
      
      // Check the architecture of the device
      #if arch(x86_64)
          // 64-bit Mac
          if let resourcePath = bundle.path(forResource: "x64", ofType: nil, inDirectory: "Resources") {
              return resourcePath
          }
      #elseif arch(arm64)
          // ARM64 Mac
          if let resourcePath = bundle.path(forResource: "arm64", ofType: nil, inDirectory: "Resources") {
              return resourcePath
          }
      #endif
      return nil
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "geResPath":
      if let resourcePath = getResourcePath() {
        result(resourcePath)
      } else {
        result(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
