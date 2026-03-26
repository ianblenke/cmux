// Session Persistence Models — Platform-agnostic snapshot types
// Extracted from Sources/SessionPersistence.swift
// REQ-SPE-001: Session snapshot schema versioning
// REQ-XP-001: Core logic has no platform imports

import Foundation

// MARK: - Schema

public enum CoreSessionSnapshotSchema {
    public static let currentVersion = 1
}

// MARK: - Persistence Policy

public enum CoreSessionPersistencePolicy {
    public static let defaultSidebarWidth: Double = 200
    public static let minimumSidebarWidth: Double = 180
    public static let maximumSidebarWidth: Double = 600
    public static let minimumWindowWidth: Double = 300
    public static let minimumWindowHeight: Double = 200
    public static let autosaveInterval: TimeInterval = 8.0
    public static let maxWindowsPerSnapshot: Int = 12
    public static let maxWorkspacesPerWindow: Int = 128
    public static let maxPanelsPerWorkspace: Int = 512
    public static let maxScrollbackLinesPerTerminal: Int = 4000
    public static let maxScrollbackCharactersPerTerminal: Int = 400_000

    public static func sanitizedSidebarWidth(_ candidate: Double?) -> Double {
        let fallback = defaultSidebarWidth
        guard let candidate, candidate.isFinite else { return fallback }
        return min(max(candidate, minimumSidebarWidth), maximumSidebarWidth)
    }

    public static func truncatedScrollback(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        if text.count <= maxScrollbackCharactersPerTerminal {
            return text
        }
        let initialStart = text.index(text.endIndex, offsetBy: -maxScrollbackCharactersPerTerminal)
        let safeStart = ansiSafeTruncationStart(in: text, initialStart: initialStart)
        return String(text[safeStart...])
    }

    private static func ansiSafeTruncationStart(in text: String, initialStart: String.Index) -> String.Index {
        guard initialStart > text.startIndex else { return initialStart }
        let escape = "\u{001B}"

        guard let lastEscape = text[..<initialStart].lastIndex(of: Character(escape)) else {
            return initialStart
        }
        let csiMarker = text.index(after: lastEscape)
        guard csiMarker < text.endIndex, text[csiMarker] == "[" else {
            return initialStart
        }

        if csiFinalByteIndex(in: text, from: csiMarker, upperBound: initialStart) != nil {
            return initialStart
        }

        guard let final = csiFinalByteIndex(in: text, from: csiMarker, upperBound: text.endIndex) else {
            return initialStart
        }
        let next = text.index(after: final)
        return next < text.endIndex ? next : text.endIndex
    }

    private static func csiFinalByteIndex(
        in text: String,
        from csiMarker: String.Index,
        upperBound: String.Index
    ) -> String.Index? {
        var index = text.index(after: csiMarker)
        while index < upperBound {
            guard let scalar = text[index].unicodeScalars.first?.value else {
                index = text.index(after: index)
                continue
            }
            if scalar >= 0x40, scalar <= 0x7E {
                return index
            }
            index = text.index(after: index)
        }
        return nil
    }
}

// MARK: - Restore Policy

public enum CoreSessionRestorePolicy {
    public static func isRunningUnderAutomatedTests(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        if environment["CMUX_UI_TEST_MODE"] == "1" { return true }
        if environment.keys.contains(where: { $0.hasPrefix("CMUX_UI_TEST_") }) { return true }
        if environment["XCTestConfigurationFilePath"] != nil { return true }
        if environment["XCTestBundlePath"] != nil { return true }
        if environment["XCTestSessionIdentifier"] != nil { return true }
        if environment["XCInjectBundle"] != nil { return true }
        if environment["XCInjectBundleInto"] != nil { return true }
        if environment["DYLD_INSERT_LIBRARIES"]?.contains("libXCTest") == true { return true }
        return false
    }

    public static func shouldAttemptRestore(
        arguments: [String] = CommandLine.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        if environment["CMUX_DISABLE_SESSION_RESTORE"] == "1" { return false }
        if isRunningUnderAutomatedTests(environment: environment) { return false }
        let extraArgs = arguments.dropFirst().filter { !$0.hasPrefix("-psn_") }
        return extraArgs.isEmpty
    }
}

// MARK: - Snapshot Data Models

public struct CoreSessionRectSnapshot: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct CoreSessionDisplaySnapshot: Codable, Sendable {
    public var displayID: UInt32?
    public var frame: CoreSessionRectSnapshot?
    public var visibleFrame: CoreSessionRectSnapshot?

    public init(displayID: UInt32? = nil, frame: CoreSessionRectSnapshot? = nil, visibleFrame: CoreSessionRectSnapshot? = nil) {
        self.displayID = displayID
        self.frame = frame
        self.visibleFrame = visibleFrame
    }
}

public struct CoreSessionSidebarSnapshot: Codable, Sendable {
    public var isVisible: Bool
    public var selection: CoreSidebarSelection
    public var width: Double?

    public init(isVisible: Bool, selection: CoreSidebarSelection, width: Double? = nil) {
        self.isVisible = isVisible
        self.selection = selection
        self.width = width
    }
}

public struct CoreSessionTerminalPanelSnapshot: Codable, Sendable {
    public var workingDirectory: String?
    public var scrollback: String?

    public init(workingDirectory: String? = nil, scrollback: String? = nil) {
        self.workingDirectory = workingDirectory
        self.scrollback = scrollback
    }
}

public struct CoreSessionBrowserPanelSnapshot: Codable, Sendable {
    public var urlString: String?
    public var profileID: UUID?
    public var shouldRenderWebView: Bool
    public var pageZoom: Double
    public var developerToolsVisible: Bool
    public var backHistoryURLStrings: [String]?
    public var forwardHistoryURLStrings: [String]?

    public init(urlString: String? = nil, profileID: UUID? = nil, shouldRenderWebView: Bool = true,
                pageZoom: Double = 1.0, developerToolsVisible: Bool = false,
                backHistoryURLStrings: [String]? = nil, forwardHistoryURLStrings: [String]? = nil) {
        self.urlString = urlString
        self.profileID = profileID
        self.shouldRenderWebView = shouldRenderWebView
        self.pageZoom = pageZoom
        self.developerToolsVisible = developerToolsVisible
        self.backHistoryURLStrings = backHistoryURLStrings
        self.forwardHistoryURLStrings = forwardHistoryURLStrings
    }
}

public struct CoreSessionPanelSnapshot: Codable, Sendable {
    public var id: UUID
    public var type: CorePanelType
    public var title: String?
    public var customTitle: String?
    public var directory: String?
    public var isPinned: Bool
    public var isManuallyUnread: Bool
    public var terminal: CoreSessionTerminalPanelSnapshot?
    public var browser: CoreSessionBrowserPanelSnapshot?

    public init(id: UUID, type: CorePanelType, title: String? = nil, customTitle: String? = nil,
                directory: String? = nil, isPinned: Bool = false, isManuallyUnread: Bool = false,
                terminal: CoreSessionTerminalPanelSnapshot? = nil, browser: CoreSessionBrowserPanelSnapshot? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.customTitle = customTitle
        self.directory = directory
        self.isPinned = isPinned
        self.isManuallyUnread = isManuallyUnread
        self.terminal = terminal
        self.browser = browser
    }
}

public struct CoreSessionPaneLayoutSnapshot: Codable, Sendable {
    public var panelIds: [UUID]
    public var selectedPanelId: UUID?

    public init(panelIds: [UUID], selectedPanelId: UUID? = nil) {
        self.panelIds = panelIds
        self.selectedPanelId = selectedPanelId
    }
}

public struct CoreSessionSplitLayoutSnapshot: Codable, Sendable {
    public var orientation: CoreSplitOrientation
    public var dividerPosition: Double
    public var first: CoreSessionWorkspaceLayoutSnapshot
    public var second: CoreSessionWorkspaceLayoutSnapshot

    public init(orientation: CoreSplitOrientation, dividerPosition: Double,
                first: CoreSessionWorkspaceLayoutSnapshot, second: CoreSessionWorkspaceLayoutSnapshot) {
        self.orientation = orientation
        self.dividerPosition = dividerPosition
        self.first = first
        self.second = second
    }
}

public indirect enum CoreSessionWorkspaceLayoutSnapshot: Codable, Sendable {
    case pane(CoreSessionPaneLayoutSnapshot)
    case split(CoreSessionSplitLayoutSnapshot)

    private enum CodingKeys: String, CodingKey {
        case type, pane, split
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "pane": self = .pane(try container.decode(CoreSessionPaneLayoutSnapshot.self, forKey: .pane))
        case "split": self = .split(try container.decode(CoreSessionSplitLayoutSnapshot.self, forKey: .split))
        default: throw DecodingError.dataCorruptedError(forKey: .type, in: container,
                                                         debugDescription: "Unsupported layout type: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pane(let p):
            try container.encode("pane", forKey: .type)
            try container.encode(p, forKey: .pane)
        case .split(let s):
            try container.encode("split", forKey: .type)
            try container.encode(s, forKey: .split)
        }
    }
}

public struct CoreSessionWorkspaceSnapshot: Codable, Sendable {
    public var processTitle: String
    public var customTitle: String?
    public var customColor: String?
    public var isPinned: Bool
    public var currentDirectory: String
    public var focusedPanelId: UUID?
    public var layout: CoreSessionWorkspaceLayoutSnapshot
    public var panels: [CoreSessionPanelSnapshot]

    public init(processTitle: String, customTitle: String? = nil, customColor: String? = nil,
                isPinned: Bool = false, currentDirectory: String, focusedPanelId: UUID? = nil,
                layout: CoreSessionWorkspaceLayoutSnapshot, panels: [CoreSessionPanelSnapshot]) {
        self.processTitle = processTitle
        self.customTitle = customTitle
        self.customColor = customColor
        self.isPinned = isPinned
        self.currentDirectory = currentDirectory
        self.focusedPanelId = focusedPanelId
        self.layout = layout
        self.panels = panels
    }
}

public struct CoreSessionWindowSnapshot: Codable, Sendable {
    public var frame: CoreSessionRectSnapshot?
    public var display: CoreSessionDisplaySnapshot?
    public var selectedWorkspaceIndex: Int?
    public var workspaces: [CoreSessionWorkspaceSnapshot]
    public var sidebar: CoreSessionSidebarSnapshot

    public init(frame: CoreSessionRectSnapshot? = nil, display: CoreSessionDisplaySnapshot? = nil,
                selectedWorkspaceIndex: Int? = nil, workspaces: [CoreSessionWorkspaceSnapshot],
                sidebar: CoreSessionSidebarSnapshot) {
        self.frame = frame
        self.display = display
        self.selectedWorkspaceIndex = selectedWorkspaceIndex
        self.workspaces = workspaces
        self.sidebar = sidebar
    }
}

public struct CoreAppSessionSnapshot: Codable, Sendable {
    public var version: Int
    public var createdAt: TimeInterval
    public var windows: [CoreSessionWindowSnapshot]

    public init(version: Int = CoreSessionSnapshotSchema.currentVersion,
                createdAt: TimeInterval = Date().timeIntervalSince1970,
                windows: [CoreSessionWindowSnapshot]) {
        self.version = version
        self.createdAt = createdAt
        self.windows = windows
    }
}

// MARK: - Persistence Store

public enum CoreSessionPersistenceStore {
    public static func load(fileURL: URL) -> CoreAppSessionSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        guard let snapshot = try? decoder.decode(CoreAppSessionSnapshot.self, from: data) else { return nil }
        guard snapshot.version == CoreSessionSnapshotSchema.currentVersion else { return nil }
        guard !snapshot.windows.isEmpty else { return nil }
        return snapshot
    }

    @discardableResult
    public static func save(_ snapshot: CoreAppSessionSnapshot, fileURL: URL) -> Bool {
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            let data = try encodedSnapshotData(snapshot)
            if let existingData = try? Data(contentsOf: fileURL), existingData == data {
                return true
            }
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private static func encodedSnapshotData(_ snapshot: CoreAppSessionSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(snapshot)
    }

    public static func removeSnapshot(fileURL: URL) {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
