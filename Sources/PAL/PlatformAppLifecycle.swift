// Platform Abstraction Layer — Application Lifecycle
// REQ-XP-002: PAL protocol definitions

import Foundation

/// Abstracts the platform's application lifecycle (NSApplication / GtkApplication).
public protocol PlatformAppLifecycle: AnyObject {
    /// Enter the platform's main event loop. Does not return under normal operation.
    func run()

    /// Request application termination.
    func quit()

    /// Whether the application is currently the active/focused app.
    var isActive: Bool { get }

    /// Register the app as a handler for a URL scheme (e.g., "cmux://").
    func registerURLScheme(_ scheme: String)

    /// The application's bundle/display version string.
    var version: String { get }

    /// The application's build number.
    var buildNumber: String { get }
}
