// Core Types — Platform-agnostic type definitions
// These types are the shared vocabulary between Core and platform backends.
// REQ-XP-001: Platform abstraction layer exists

import Foundation

/// Type of panel content — shared between persistence, model, and UI layers.
public enum CorePanelType: String, Codable, Sendable {
    case terminal
    case browser
    case markdown
}

/// Split orientation for pane splitting.
public enum CoreSplitOrientation: String, Codable, Sendable {
    case horizontal
    case vertical
}

/// Sidebar page selection.
public enum CoreSidebarSelection: String, Codable, Sendable {
    case tabs
    case notifications
}

/// Workspace placement policy for new workspaces.
public enum CoreWorkspacePlacement: String, CaseIterable, Codable, Sendable {
    case top
    case afterCurrent
    case end
}

/// Socket control access mode.
public enum CoreSocketControlMode: String, CaseIterable, Codable, Sendable {
    case off
    case cmuxOnly
    case automation
    case password
    case allowAll

    public var socketFilePermissions: UInt16 {
        switch self {
        case .allowAll: return 0o666
        case .off, .cmuxOnly, .automation, .password: return 0o600
        }
    }

    public var requiresPasswordAuth: Bool {
        self == .password
    }
}
