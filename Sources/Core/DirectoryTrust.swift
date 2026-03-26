// Directory Trust — Platform-agnostic directory trust management
// Extracted from Sources/CmuxDirectoryTrust.swift
// REQ-CF-019: Directory trust for config command execution

import Foundation

/// Manages trusted directories for cmux.json command execution.
/// When a directory (or its git repo root) is trusted, `confirm: true` commands
/// from that directory's cmux.json skip the confirmation dialog.
public enum CoreDirectoryTrust {
    private static let trustedDirectoriesKey = "cmuxTrustedDirectories"

    public static func isTrusted(
        _ directory: URL,
        defaults: UserDefaults = .standard
    ) -> Bool {
        let stored = defaults.stringArray(forKey: trustedDirectoriesKey) ?? []
        let canonicalPath = directory.standardizedFileURL.path
        if stored.contains(canonicalPath) { return true }

        // Check if git repo root is trusted
        if let repoRoot = gitRepoRoot(for: directory) {
            let repoPath = repoRoot.standardizedFileURL.path
            return stored.contains(repoPath)
        }
        return false
    }

    public static func trust(
        _ directory: URL,
        defaults: UserDefaults = .standard
    ) {
        var stored = defaults.stringArray(forKey: trustedDirectoriesKey) ?? []
        let canonicalPath = directory.standardizedFileURL.path
        if !stored.contains(canonicalPath) {
            stored.append(canonicalPath)
            defaults.set(stored, forKey: trustedDirectoriesKey)
        }
    }

    public static func untrust(
        _ directory: URL,
        defaults: UserDefaults = .standard
    ) {
        var stored = defaults.stringArray(forKey: trustedDirectoriesKey) ?? []
        let canonicalPath = directory.standardizedFileURL.path
        stored.removeAll { $0 == canonicalPath }
        defaults.set(stored, forKey: trustedDirectoriesKey)
    }

    private static func gitRepoRoot(for directory: URL) -> URL? {
        var current = directory.standardizedFileURL
        while current.path != "/" {
            let gitDir = current.appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: gitDir.path) {
                return current
            }
            current = current.deletingLastPathComponent()
        }
        return nil
    }
}
