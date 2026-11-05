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
    logDebug("AppDelegate.init called")

    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleOpenDocsAppleEvent(_:withReplyEvent:)),
      forEventClass: AEEventClass(kCoreEventClass),
      andEventID: AEEventID(kAEOpenDocuments)
    )
  }

  private func logDebug(_ msg: String) {
    let line = "\(Date()) [macOS]: \(msg)\n"
    if let data = line.data(using: .utf8) {
      if let handle = FileHandle(forWritingAtPath: "/tmp/folio_debug.log") {
        handle.seekToEndOfFile()
        handle.write(data)
        handle.closeFile()
      } else {
        try? line.write(toFile: "/tmp/folio_debug.log", atomically: true, encoding: .utf8)
      }
    }
  }

  func setupChannel(flutterViewController: FlutterViewController) {
    logDebug("setupChannel called")
    let channel = FlutterMethodChannel(
      name: "folio/open_file",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    self.methodChannel = channel

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      self.logDebug("MethodChannel call: \(call.method)")
      if call.method == "getInitialFiles" {
        self.isDartReady = true
        let files = self.pendingFilePaths
        self.pendingFilePaths.removeAll()
        self.logDebug("Returning getInitialFiles: \(files)")
        result(files)
      } else if call.method == "shareFile" {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
          result(false)
          return
        }
        let url = URL(fileURLWithPath: path)
        DispatchQueue.main.async {
          if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first,
             let contentView = window.contentView {
            let picker = NSSharingServicePicker(items: [url])
            picker.show(relativeTo: CGRect(x: contentView.bounds.midX, y: contentView.bounds.midY, width: 0, height: 0),
                        of: contentView,
                        preferredEdge: .minY)
            result(true)
          } else {
            result(false)
          }
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func handleIncomingFiles(_ paths: [String]) {
    let validPdfs = paths.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    guard !validPdfs.isEmpty else { return }
    logDebug("handleIncomingFiles called with: \(validPdfs), isDartReady: \(isDartReady)")

    if isDartReady, let channel = self.methodChannel {
      logDebug("Dispatching onOpenFiles to Dart: \(validPdfs)")
      channel.invokeMethod("onOpenFiles", arguments: validPdfs)
    } else {
      logDebug("Dart not ready yet, queuing: \(validPdfs)")
      self.pendingFilePaths.append(contentsOf: validPdfs)
    }
  }

  @objc func handleOpenDocsAppleEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
    logDebug("handleOpenDocsAppleEvent received")
    guard let docList = event.paramDescriptor(forKeyword: keyDirectObject) else {
      logDebug("handleOpenDocsAppleEvent: no direct object")
      return
    }

    var paths: [String] = []
    if docList.numberOfItems > 0 {
      for i in 1...docList.numberOfItems {
        if let desc = docList.atIndex(i) {
          if let url = desc.fileURLValue {
            paths.append(url.path)
          } else if let str = desc.stringValue {
            if str.hasPrefix("file://"), let u = URL(string: str) {
              paths.append(u.path)
            } else {
              paths.append(str)
            }
          }
        }
      }
    } else {
      if let url = docList.fileURLValue {
        paths.append(url.path)
      } else if let str = docList.stringValue {
        if str.hasPrefix("file://"), let u = URL(string: str) {
          paths.append(u.path)
        } else {
          paths.append(str)
        }
      }
    }

    logDebug("handleOpenDocsAppleEvent extracted paths: \(paths)")
    handleIncomingFiles(paths)
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    logDebug("application:openFiles: \(filenames)")
    handleIncomingFiles(filenames)
    sender.reply(toOpenOrPrint: .success)
  }

  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    logDebug("application:openFile: \(filename)")
    handleIncomingFiles([filename])
    return true
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    let paths = urls.compactMap { $0.isFileURL ? $0.path : nil }
    logDebug("application:open urls: \(paths)")
    handleIncomingFiles(paths)
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    logDebug("applicationDidFinishLaunching called")

    // Check CLI arguments for PDF files
    for arg in ProcessInfo.processInfo.arguments.dropFirst() {
      if arg.lowercased().hasSuffix(".pdf") && FileManager.default.fileExists(atPath: arg) {
        logDebug("Found CLI PDF argument: \(arg)")
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
