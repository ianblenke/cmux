// Platform Abstraction Layer — Split Pane Container
// REQ-XP-002: PAL protocol definitions

import Foundation

/// Abstracts a split pane container (Bonsplit / GtkPaned tree).
public protocol PlatformSplitContainer: AnyObject {
    /// Split the container at the given surface, creating a new surface in the given direction.
    func split(direction: SplitDirection, at surface: any PlatformSurface) -> (any PlatformSurface)?

    /// Remove a surface from the split tree.
    func removeSurface(_ surface: any PlatformSurface)

    /// Move a divider to a new position (0.0–1.0 fraction).
    func moveDivider(at index: Int, to fraction: CGFloat)

    /// All surfaces currently in this container.
    var surfaces: [any PlatformSurface] { get }

    /// The currently focused surface, if any.
    var focusedSurface: (any PlatformSurface)? { get }

    /// Move focus in the given direction.
    func moveFocus(direction: SplitDirection, forward: Bool)
}
