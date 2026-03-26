// Platform Abstraction Layer — Appearance / Theme
// REQ-XP-002: PAL protocol definitions

import Foundation

/// Abstracts system appearance detection (NSApplication.effectiveAppearance / GTK settings).
public protocol PlatformAppearance {
    /// Whether the system is currently in dark mode.
    var isDarkMode: Bool { get }

    /// The system accent color, if available.
    var accentColor: PlatformColor? { get }

    /// Register a callback for appearance changes.
    func onAppearanceChange(_ callback: @escaping (Bool) -> Void)
}
