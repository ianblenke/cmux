// GTK4 helper functions for Swift
// Swift cannot use GObject cast macros (GTK_WINDOW, GTK_BOX, etc.)
// Use OpaquePointer for GTK types that aren't fully exposed to Swift.

import CGtk4

// MARK: - Pointer Helpers

/// Cast a GtkWidget pointer to a GtkWindow pointer (unchecked).
@inline(__always)
func asWindow(_ ptr: UnsafeMutablePointer<GtkWidget>?) -> OpaquePointer? {
    guard let ptr = ptr else { return nil }
    return OpaquePointer(ptr)
}

/// Cast a GtkWidget pointer to a GtkBox pointer (unchecked).
@inline(__always)
func asBox(_ ptr: UnsafeMutablePointer<GtkWidget>?) -> OpaquePointer? {
    guard let ptr = ptr else { return nil }
    return OpaquePointer(ptr)
}

/// Cast a GtkApplication pointer to a GApplication pointer.
@inline(__always)
func asGApplication(_ ptr: UnsafeMutablePointer<GtkApplication>?) -> OpaquePointer? {
    guard let ptr = ptr else { return nil }
    return OpaquePointer(ptr)
}
