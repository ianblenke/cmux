// Platform Abstraction Layer — Terminal Surface
// REQ-XP-002: PAL protocol definitions

import Foundation

/// Abstracts a terminal rendering surface (GhosttySurfaceView / GtkGLArea + libghostty).
public protocol PlatformSurface: AnyObject {
    /// The native view/widget for embedding in the platform's view hierarchy.
    var nativeView: AnyObject { get }

    /// Request keyboard focus for this surface.
    func focus()

    /// Resize the surface to the given dimensions.
    func resize(to size: PlatformSize)

    /// Send raw input data to the terminal PTY.
    func sendInput(_ data: Data)

    /// Unique identifier for this surface.
    var surfaceId: String { get }

    /// The current title reported by the terminal (e.g., from OSC 0/2).
    var currentTitle: String { get }

    /// The current working directory of the foreground process, if detectable.
    var currentWorkingDirectory: URL? { get }

    // MARK: - Callbacks

    var onTitleChange: ((String) -> Void)? { get set }
    var onBell: (() -> Void)? { get set }
    var onClose: (() -> Void)? { get set }
    var onNotification: ((String, String) -> Void)? { get set }
}

/// Factory for creating terminal surfaces.
public protocol PlatformSurfaceFactory {
    func createSurface(workingDirectory: URL?) -> any PlatformSurface
}
