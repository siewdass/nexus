import Cocoa
import FlutterMacOS

import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow, NSWindowDelegate {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
    self.delegate = self
  }

  override func makeKeyAndOrderFront(_ sender: Any?) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    super.makeKeyAndOrderFront(sender)
  }

  override func orderOut(_ sender: Any?) {
    NSApp.setActivationPolicy(.accessory)
    super.orderOut(sender)
  }
}
