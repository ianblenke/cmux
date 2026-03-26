// Platform Abstraction Layer — Menu Bar
// REQ-XP-002: PAL protocol definitions

import Foundation

/// Menu item descriptor (platform-agnostic).
public struct MenuItem: Sendable {
    public let title: String
    public let shortcut: String?
    public let action: (@Sendable () -> Void)?
    public let submenu: [MenuItem]?
    public let isSeparator: Bool

    public init(title: String, shortcut: String? = nil, action: (@Sendable () -> Void)? = nil,
                submenu: [MenuItem]? = nil) {
        self.title = title
        self.shortcut = shortcut
        self.action = action
        self.submenu = submenu
        self.isSeparator = false
    }

    private init(separator: Bool) {
        self.title = ""
        self.shortcut = nil
        self.action = nil
        self.submenu = nil
        self.isSeparator = true
    }

    public static var separator: MenuItem {
        MenuItem(separator: true)
    }
}

/// Abstracts the application menu bar (NSMenu / GtkMenuBar).
public protocol PlatformMenuBar {
    /// Set the entire menu structure.
    func setMenus(_ menus: [MenuItem])

    /// Enable or disable a menu item by title.
    func setEnabled(_ enabled: Bool, forItemWithTitle title: String)
}
