import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  static weak var shared: AppDelegate?
  private var methodChannel: FlutterMethodChannel?
  private var pendingFilePaths: [String] = []
  private var isDartReady = false

  override init() {
    super.init()
    AppDelegate.shared = self
  }

  func setupChannel(flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "folio/open_file",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    self.methodChannel = channel

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      if call.method == "getInitialFiles" {
        self.isDartReady = true
        let files = self.pendingFilePaths
        self.pendingFilePaths.removeAll()
        result(files)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func handleIncomingFiles(_ paths: [String]) {
    let validPdfs = paths.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    guard !validPdfs.isEmpty else { return }

    if isDartReady, let channel = self.methodChannel {
      channel.invokeMethod("onOpenFiles", arguments: validPdfs)
    } else {
      self.pendingFilePaths.append(contentsOf: validPdfs)
    }
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    handleIncomingFiles(filenames)
    sender.reply(toOpenOrPrint: .success)
  }

  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    handleIncomingFiles([filename])
    return true
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    let paths = urls.compactMap { $0.isFileURL ? $0.path : nil }
    handleIncomingFiles(paths)
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    // Check CLI arguments for PDF files
    for arg in ProcessInfo.processInfo.arguments.dropFirst() {
      if arg.lowercased().hasSuffix(".pdf") && FileManager.default.fileExists(atPath: arg) {
        handleIncomingFiles([arg])
      }
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
