// Platform Abstraction Layer — Update Checker
// REQ-XP-002: PAL protocol definitions

import Foundation

/// Abstracts the application update mechanism (Sparkle / GitHub releases / no-op).
public protocol PlatformUpdateChecker: AnyObject {
    /// Check for available updates.
    func checkForUpdates()

    /// Whether auto-update is supported on this platform/installation method.
    var isSupported: Bool { get }

    /// Callback when an update is available.
    var onUpdateAvailable: ((UpdateInfo) -> Void)? { get set }
}
