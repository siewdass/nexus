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
    self.alphaValue = 0
  }

  override func makeKeyAndOrderFront(_ sender: Any?) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    self.alphaValue = 1
    super.makeKeyAndOrderFront(sender)
  }

  override func orderOut(_ sender: Any?) {
    NSApp.setActivationPolicy(.accessory)
    self.alphaValue = 0
    super.orderOut(sender)
  }
}
