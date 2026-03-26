// Platform Abstraction Layer — Window Management
// REQ-XP-002: PAL protocol definitions

import Foundation

/// Abstracts a platform window (NSWindow / GtkApplicationWindow).
public protocol PlatformWindow: AnyObject {
    var title: String { get set }
    var frame: PlatformRect { get set }
    var isFullScreen: Bool { get set }

    func makeKeyAndVisible()
    func close()

    /// Add a split container as the main content area.
    func addSplitContainer(_ container: any PlatformSplitContainer)

    /// Show or hide the sidebar with the given width.
    func setSidebar(visible: Bool, width: CGFloat)

    /// Configure the window toolbar with the given items.
    func setToolbar(_ items: [ToolbarItem])

    /// The window's unique identifier.
    var windowId: String { get }
}

/// Factory for creating platform windows.
public protocol PlatformWindowFactory {
    func createWindow(config: WindowConfig) -> any PlatformWindow
}
