import Cocoa
import FlutterMacOS
import bitsdojo_window_macos
import desktop_multi_window

class MainFlutterWindow: BitsdojoWindow {
  override func bitsdojo_window_configure() -> UInt {
    return BDW_CUSTOM_FRAME | BDW_HIDE_ON_STARTUP
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Ensure plugins are registered for each newly created sub-window so
    // plugins like window_manager and bitsdojo_window are available in
    // child Flutter engines.
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
    }

    super.awakeFromNib()
  }
}
