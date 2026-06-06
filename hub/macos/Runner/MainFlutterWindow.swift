import Cocoa
import FlutterMacOS

extension Notification.Name {
  static let nexusWindowHidden = Notification.Name("nexusWindowHidden")
}

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    setContentSize(NSSize(width: 540, height: 400))

    let flutterViewController = FlutterViewController()
    let windowFrame = NSRect(origin: frame.origin, size: NSSize(width: 540, height: 400))
    setFrame(windowFrame, display: false)
    self.contentViewController = flutterViewController
    setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  override func performClose(_ sender: Any?) {
    orderOut(nil)
    NSApp.setActivationPolicy(.accessory)
    NotificationCenter.default.post(name: .nexusWindowHidden, object: self)
  }

  override func close() {
    orderOut(nil)
    NSApp.setActivationPolicy(.accessory)
    NotificationCenter.default.post(name: .nexusWindowHidden, object: self)
  }
}
