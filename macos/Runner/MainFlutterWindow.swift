import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.title = "Folio"

    RegisterGeneratedPlugins(registry: flutterViewController)

    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
      appDelegate.setupChannel(flutterViewController: flutterViewController)
    } else {
      AppDelegate.shared?.setupChannel(flutterViewController: flutterViewController)
    }

    super.awakeFromNib()
  }
}
