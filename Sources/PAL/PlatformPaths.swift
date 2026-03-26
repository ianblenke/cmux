// Platform Abstraction Layer — Cross-Platform Path Conventions
// REQ-XP-001: Platform abstraction layer exists

import Foundation

/// Cross-platform path resolution following platform conventions.
/// macOS: ~/Library/Application Support/cmux
/// Linux: XDG Base Directory Specification
public enum PlatformPaths {
    public static var configDir: URL {
        #if os(macOS)
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/cmux")
        #elseif os(Linux)
        if let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] {
            return URL(fileURLWithPath: xdg).appendingPathComponent("cmux")
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/cmux")
        #else
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cmux")
        #endif
    }

    public static var dataDir: URL {
        #if os(macOS)
        return configDir
        #elseif os(Linux)
        if let xdg = ProcessInfo.processInfo.environment["XDG_DATA_HOME"] {
            return URL(fileURLWithPath: xdg).appendingPathComponent("cmux")
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/cmux")
        #else
        return configDir
        #endif
    }

    public static var runtimeDir: URL? {
        #if os(Linux)
        if let xdg = ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"] {
            return URL(fileURLWithPath: xdg).appendingPathComponent("cmux")
        }
        return nil
        #else
        return nil
        #endif
    }

    public static var socketPath: String {
        #if os(Linux)
        if let runtimeDir = runtimeDir {
            return runtimeDir.appendingPathComponent("cmux.sock").path
        }
        #endif
        return "/tmp/cmux-\(ProcessInfo.processInfo.processIdentifier).sock"
    }

    public static var ghosttyConfigDir: URL {
        #if os(macOS)
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/ghostty")
        #elseif os(Linux)
        if let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] {
            return URL(fileURLWithPath: xdg).appendingPathComponent("ghostty")
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/ghostty")
        #else
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/ghostty")
        #endif
    }
}
