import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var methodChannel: FlutterMethodChannel?
  private var pendingFilePaths: [String] = []
  private var isDartReady = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FolioOpenFilePlugin") {
      setupChannel(messenger: registrar.messenger())
    }
  }

  private func setupChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "folio/open_file", binaryMessenger: messenger)
    self.methodChannel = channel

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      if call.method == "getInitialFiles" {
        self.isDartReady = true
        let files = self.pendingFilePaths
        self.pendingFilePaths.removeAll()
        result(files)
      } else if call.method == "shareFile" {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
          result(false)
          return
        }
        let url = URL(fileURLWithPath: path)
        DispatchQueue.main.async {
          let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow })
          guard let rootVC = keyWindow?.rootViewController else {
            result(false)
            return
          }
          let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
          if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
          }
          rootVC.present(activityVC, animated: true) {
            result(true)
          }
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func handleIncomingFile(path: String) {
    if isDartReady, let channel = methodChannel {
      channel.invokeMethod("onOpenFiles", arguments: [path])
    } else {
      pendingFilePaths.append(path)
    }
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    handleIncomingFile(path: url.path)
    return true
  }
}
