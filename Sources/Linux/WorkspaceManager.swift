// Workspace Manager — manages multiple terminal surfaces for the Linux GTK4 app
// REQ-WS-001: Workspace identity
// REQ-WS-002: Workspace panel management

import Foundation
import CGtk4

/// A single workspace containing a ghostty terminal surface
struct Workspace {
    let id: Int
    var title: String
    var surface: UnsafeMutableRawPointer?  // ghostty_surface_t
    var cwd: String

    init(id: Int, title: String? = nil, cwd: String = "~") {
        self.id = id
        self.title = title ?? "\(id): \(cwd)"
        self.cwd = cwd
    }
}

/// Manages workspace lifecycle and switching
final class WorkspaceManager {
    var workspaces: [Workspace] = []
    var activeIndex: Int = 0

    // GTK widgets (set by main.swift)
    var sidebarBox: UnsafeMutablePointer<GtkBox>?
    var glArea: UnsafeMutablePointer<GtkGLArea>?

    var activeWorkspace: Workspace? {
        guard activeIndex >= 0, activeIndex < workspaces.count else { return nil }
        return workspaces[activeIndex]
    }

    var activeSurface: UnsafeMutableRawPointer? {
        return activeWorkspace?.surface
    }

    /// Create a new workspace with a terminal surface
    func createWorkspace(ghosttyApp: GhosttyApp, glArea: UnsafeMutablePointer<GtkGLArea>,
                         widget: UnsafeMutablePointer<GtkWidget>) -> Int {
        let id = workspaces.count + 1
        var ws = Workspace(id: id)

        // Create ghostty surface for this workspace
        if ghosttyApp.createSurface(glArea: glArea, widget: widget) {
            ws.surface = ghosttyApp.surface
            // Reset the global surface reference — we manage it ourselves
        }

        workspaces.append(ws)
        activeIndex = workspaces.count - 1

        updateSidebar()
        cmuxLog("[workspace] Created workspace \(id), total=\(workspaces.count)")
        return id
    }

    /// Switch to workspace at index
    func switchTo(index: Int) {
        guard index >= 0, index < workspaces.count else { return }
        guard index != activeIndex else { return }

        // Unfocus current surface
        if let currentSurface = activeSurface {
            ghosttyApp?.setFocusOnSurface(currentSurface, focused: false)
        }

        activeIndex = index

        // Focus new surface
        if let newSurface = activeSurface {
            ghosttyApp?.setFocusOnSurface(newSurface, focused: true)
        }

        // Queue a render
        if let gl = glArea {
            gtk_gl_area_queue_render(gl)
        }

        updateSidebar()
        cmuxLog("[workspace] Switched to workspace \(index + 1)")
    }

    /// Switch to next workspace
    func next() {
        let nextIdx = (activeIndex + 1) % max(workspaces.count, 1)
        switchTo(index: nextIdx)
    }

    /// Switch to previous workspace
    func previous() {
        let prevIdx = activeIndex > 0 ? activeIndex - 1 : max(workspaces.count - 1, 0)
        switchTo(index: prevIdx)
    }

    /// Update the sidebar GTK widget to reflect current workspaces
    func updateSidebar() {
        guard let box = sidebarBox else { return }

        // Remove all children
        var child = gtk_widget_get_first_child(unsafeBitCast(box, to: UnsafeMutablePointer<GtkWidget>.self))
        while let c = child {
            let next = gtk_widget_get_next_sibling(c)
            gtk_box_remove(box, c)
            child = next
        }

        // Add header
        let header = gtk_label_new("Workspaces")
        gtk_widget_set_halign(header, GTK_ALIGN_START)
        gtk_box_append(box, header)

        // Add workspace entries
        for (i, ws) in workspaces.enumerated() {
            let prefix = i == activeIndex ? "▸ " : "  "
            let label = gtk_label_new("\(prefix)\(ws.id): \(ws.cwd)")
            gtk_widget_set_halign(label, GTK_ALIGN_START)

            // Make clickable
            let clickGesture = gtk_gesture_click_new()!
            let idx = Int32(i)
            // Store index as widget name for the click handler
            gtk_widget_set_name(label, "ws-\(i)")
            g_signal_connect_data(
                UnsafeMutableRawPointer(clickGesture), "pressed",
                unsafeBitCast(workspaceSidebarClickCb, to: GCallback.self),
                nil, nil, GConnectFlags(rawValue: 0))
            let addCtrl: @convention(c) (UnsafeMutablePointer<GtkWidget>?, OpaquePointer?) -> Void = gtk_widget_add_controller
            addCtrl(label, unsafeBitCast(clickGesture, to: OpaquePointer.self))

            gtk_box_append(box, label)
        }
    }
}

// Global workspace manager
var workspaceManager = WorkspaceManager()

// Sidebar click callback — extract workspace index from widget name
private let workspaceSidebarClickCb: @convention(c) (
    OpaquePointer?, Int32, Double, Double, gpointer?
) -> Void = { gesture, _, _, _, _ in
    guard let gesture = gesture else { return }
    let widget = gtk_event_controller_get_widget(unsafeBitCast(gesture, to: OpaquePointer.self))
    guard let widget = widget else { return }
    let name = gtk_widget_get_name(widget)
    guard let name = name else { return }
    let nameStr = String(cString: name)
    if nameStr.hasPrefix("ws-"), let idx = Int(nameStr.dropFirst(3)) {
        workspaceManager.switchTo(index: idx)
    }
}
