// Session Persistence for Linux — save/restore workspace layout
// REQ-SPE-001: Session snapshot schema versioning
// REQ-SPE-002: Full app state capture

import Foundation

/// Lightweight session snapshot for Linux (subset of Core models)
struct LinuxSessionSnapshot: Codable {
    var version: Int = 1
    var workspaces: [LinuxWorkspaceSnapshot]
    var activeIndex: Int
}

struct LinuxWorkspaceSnapshot: Codable {
    var title: String
    var cwd: String
}

/// Save/restore session state
enum LinuxSessionPersistence {

    static var sessionFilePath: URL {
        let dir: URL
        if let xdg = ProcessInfo.processInfo.environment["XDG_DATA_HOME"] {
            dir = URL(fileURLWithPath: xdg).appendingPathComponent("cmux")
        } else {
            dir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/share/cmux")
        }
        return dir.appendingPathComponent("session.json")
    }

    /// Save current workspace layout
    static func save() {
        let workspaces = workspaceManager.workspaces.map { ws in
            LinuxWorkspaceSnapshot(title: ws.title, cwd: ws.cwd)
        }
        let snapshot = LinuxSessionSnapshot(
            workspaces: workspaces,
            activeIndex: workspaceManager.activeIndex
        )

        let fileURL = sessionFilePath
        let dir = fileURL.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            cmuxLog("[session] Saved \(workspaces.count) workspaces to \(fileURL.path)")
        } catch {
            cmuxLog("[session] Save failed: \(error)")
        }
    }

    /// Load saved session, returns workspace CWDs to restore
    static func load() -> LinuxSessionSnapshot? {
        let fileURL = sessionFilePath
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let snapshot = try? JSONDecoder().decode(LinuxSessionSnapshot.self, from: data) else { return nil }
        guard snapshot.version == 1 else { return nil }
        guard !snapshot.workspaces.isEmpty else { return nil }
        cmuxLog("[session] Loaded \(snapshot.workspaces.count) workspaces from \(fileURL.path)")
        return snapshot
    }

    /// Delete saved session
    static func clear() {
        try? FileManager.default.removeItem(at: sessionFilePath)
    }
}
