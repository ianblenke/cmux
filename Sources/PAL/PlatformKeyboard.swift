// Platform Abstraction Layer — Keyboard
// REQ-XP-002: PAL protocol definitions

import Foundation

/// Modifier key flags (platform-agnostic).
public struct PlatformModifiers: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }

    public static let shift   = PlatformModifiers(rawValue: 1 << 0)
    public static let control = PlatformModifiers(rawValue: 1 << 1)
    public static let alt     = PlatformModifiers(rawValue: 1 << 2)  // Option on macOS
    public static let super_  = PlatformModifiers(rawValue: 1 << 3)  // Cmd on macOS, Super on Linux
}

/// A platform-agnostic key event.
public struct PlatformKeyEvent: Sendable {
    public let keyCode: UInt16
    public let characters: String?
    public let modifiers: PlatformModifiers
    public let isKeyDown: Bool

    public init(keyCode: UInt16, characters: String?, modifiers: PlatformModifiers, isKeyDown: Bool) {
        self.keyCode = keyCode
        self.characters = characters
        self.modifiers = modifiers
        self.isKeyDown = isKeyDown
    }
}

/// Abstracts keyboard layout resolution (Carbon TIS / xkbcommon).
public protocol PlatformKeyboard {
    /// Resolve the character produced by a key code with the given modifiers.
    func resolveCharacter(keyCode: UInt16, modifiers: PlatformModifiers) -> String?

    /// The current modifier key state.
    var currentModifiers: PlatformModifiers { get }

    /// The name of the current keyboard layout.
    var currentLayoutName: String { get }
}
