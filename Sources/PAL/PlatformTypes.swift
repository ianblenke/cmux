// Platform Abstraction Layer — Cross-Platform Type Aliases
// Part of: openspec/capabilities/cross-platform/spec.md
// REQ-XP-001: Platform abstraction layer exists
// REQ-XP-002: PAL protocol definitions

import Foundation

#if os(macOS)
import AppKit

public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
public typealias PlatformImage = NSImage
public typealias PlatformRect = NSRect
public typealias PlatformSize = NSSize
public typealias PlatformPoint = NSPoint

#elseif os(Linux)

/// Lightweight RGBA color for Linux (no AppKit dependency)
public struct CmuxColor: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let clear = CmuxColor(red: 0, green: 0, blue: 0, alpha: 0)
    public static let black = CmuxColor(red: 0, green: 0, blue: 0)
    public static let white = CmuxColor(red: 1, green: 1, blue: 1)
}

/// Lightweight font descriptor for Linux (no AppKit dependency)
public struct CmuxFont: Equatable, Sendable {
    public var name: String
    public var size: Double
    public var isBold: Bool
    public var isItalic: Bool

    public init(name: String, size: Double, isBold: Bool = false, isItalic: Bool = false) {
        self.name = name
        self.size = size
        self.isBold = isBold
        self.isItalic = isItalic
    }
}

/// Lightweight image wrapper for Linux (no AppKit dependency)
public struct CmuxImage: Sendable {
    public var data: Data
    public var width: Int
    public var height: Int

    public init(data: Data, width: Int, height: Int) {
        self.data = data
        self.width = width
        self.height = height
    }
}

public typealias PlatformColor = CmuxColor
public typealias PlatformFont = CmuxFont
public typealias PlatformImage = CmuxImage
public typealias PlatformRect = CGRect
public typealias PlatformSize = CGSize
public typealias PlatformPoint = CGPoint

#endif

/// Split direction for pane splitting
public enum SplitDirection: String, Sendable {
    case horizontal
    case vertical
}

/// Toolbar item descriptor (platform-agnostic)
public struct ToolbarItem: Sendable {
    public let identifier: String
    public let label: String
    public let iconName: String?
    public let action: @Sendable () -> Void

    public init(identifier: String, label: String, iconName: String? = nil, action: @escaping @Sendable () -> Void) {
        self.identifier = identifier
        self.label = label
        self.iconName = iconName
        self.action = action
    }
}

/// Update info descriptor (platform-agnostic)
public struct UpdateInfo: Sendable {
    public let version: String
    public let releaseNotesURL: URL?
    public let downloadURL: URL?

    public init(version: String, releaseNotesURL: URL? = nil, downloadURL: URL? = nil) {
        self.version = version
        self.releaseNotesURL = releaseNotesURL
        self.downloadURL = downloadURL
    }
}

/// Window configuration descriptor
public struct WindowConfig: Sendable {
    public var title: String
    public var width: Double
    public var height: Double
    public var sidebarVisible: Bool
    public var sidebarWidth: Double

    public init(title: String = "cmux", width: Double = 800, height: Double = 600,
                sidebarVisible: Bool = true, sidebarWidth: Double = 220) {
        self.title = title
        self.width = width
        self.height = height
        self.sidebarVisible = sidebarVisible
        self.sidebarWidth = sidebarWidth
    }
}

/// Browser configuration descriptor
public struct BrowserConfig: Sendable {
    public var url: URL?
    public var userAgent: String?

    public init(url: URL? = nil, userAgent: String? = nil) {
        self.url = url
        self.userAgent = userAgent
    }
}
