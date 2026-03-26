// Platform Abstraction Layer — Drag and Drop
// REQ-XP-002: PAL protocol definitions

import Foundation

/// Drag data types that can be registered.
public enum DragDataType: String, Sendable {
    case text = "public.text"
    case url = "public.url"
    case fileURL = "public.file-url"
    case tabTransfer = "com.splittabbar.tabtransfer"
    case sidebarReorder = "com.cmux.sidebar-tab-reorder"
}

/// Abstracts drag-and-drop operations (NSDragging / GtkDragSource+GtkDropTarget).
public protocol PlatformDragDrop {
    /// Register the given data types as accepted drag targets.
    func registerDragTypes(_ types: [DragDataType])

    /// Initiate a drag operation with the given data.
    func performDrag(data: Data, type: DragDataType)
}
