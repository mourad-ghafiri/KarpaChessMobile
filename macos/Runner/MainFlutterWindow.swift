import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// The smallest content the window may be dragged to: the app's
  /// expanded tablet class (840dp and up), with room for a two-pane board.
  private static let minimumContent = NSSize(width: 900, height: 640)

  /// The size a first launch opens at. The nib's 800x600 sat below the
  /// minimum above, so a first launch opened in the medium class — the
  /// portrait-tablet compositions, on a landscape desktop. This is the wide
  /// class (1200dp and up), where the browse screens split and the board
  /// screens go two-pane.
  private static let preferredContent = NSSize(width: 1280, height: 860)

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    self.contentMinSize = Self.minimumContent
    // Fit the screen it opens on: 90% of the visible frame at most, never
    // under the minimum.
    let visible = (self.screen ?? NSScreen.main)?.visibleFrame.size
      ?? Self.preferredContent
    self.setContentSize(NSSize(
      width: max(Self.minimumContent.width,
                 min(Self.preferredContent.width, visible.width * 0.9)),
      height: max(Self.minimumContent.height,
                  min(Self.preferredContent.height, visible.height * 0.9))
    ))
    self.center()
    // From the second launch on, the window opens where and as large as the
    // reader left it — a frame saved under this name replaces the default.
    self.setFrameAutosaveName("KarpaChessMainWindow")
    self.title = "KarpaChess"

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
