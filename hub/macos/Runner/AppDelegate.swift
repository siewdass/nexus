import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var trayChannel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    NSApp.setActivationPolicy(.regular)
    if let window = sender.windows.first {
      window.makeKeyAndOrderFront(nil)
    }
    trayChannel?.invokeMethod("onWindowShown", arguments: nil)
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as? FlutterViewController
    if let messenger = controller?.engine.binaryMessenger {
      let channel = FlutterMethodChannel(
        name: "nexus_hub/tray",
        binaryMessenger: messenger
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "showWindow":
          NSApp.setActivationPolicy(.regular)
          self.mainFlutterWindow?.makeKeyAndOrderFront(nil)
          NSApp.activate(ignoringOtherApps: true)
          result(true)
        case "hideWindow":
          self.mainFlutterWindow?.orderOut(nil)
          NSApp.setActivationPolicy(.accessory)
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      trayChannel = channel

      NotificationCenter.default.addObserver(
        forName: .nexusWindowHidden,
        object: mainFlutterWindow,
        queue: .main
      ) { [weak self] _ in
        self?.trayChannel?.invokeMethod("onWindowHidden", arguments: nil)
      }
    }
    super.applicationDidFinishLaunching(notification)
  }
}
