// Workspace Manager — manages multiple terminal surfaces for the Linux GTK4 app
// REQ-WS-001: Workspace identity
// REQ-WS-002: Workspace panel management

import Foundation
import CGtk4

/// A single workspace containing one or more terminal panes
struct Workspace {
    let id: Int
    var title: String
    var surface: UnsafeMutableRawPointer?  // primary surface (first pane)
    var cwd: String
    var hasUnread: Bool = false
    var lastNotification: String?
    var rootPane: PaneNode?
    var contentWidget: UnsafeMutablePointer<GtkWidget>?

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
    var window: UnsafeMutablePointer<GtkWindow>?

    var activeWorkspace: Workspace? {
        guard activeIndex >= 0, activeIndex < workspaces.count else { return nil }
        return workspaces[activeIndex]
    }

    var activeSurface: UnsafeMutableRawPointer? {
        return activeWorkspace?.surface
    }

    /// Create a new workspace with a terminal surface
    func createWorkspace(ghosttyApp: GhosttyApp, glArea: UnsafeMutablePointer<GtkGLArea>,
                         widget: UnsafeMutablePointer<GtkWidget>,
                         command: String? = nil, workingDirectory: String? = nil,
                         title: String? = nil) -> Int {
        let id = workspaces.count + 1
        var ws = Workspace(id: id)
        if let title = title { ws.title = "\(id): \(title)" }

        // Create ghostty surface for this workspace
        if ghosttyApp.createSurface(glArea: glArea, widget: widget,
                                     command: command, workingDirectory: workingDirectory) {
            ws.surface = ghosttyApp.surface
            ws.contentWidget = widget  // Track the GL area widget
            // Register in pane manager for surface lookup
            paneManager.registerSurface(glArea: glArea, surface: ghosttyApp.surface!)
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
        clearUnread(index: index)

        // Focus new surface
        if let newSurface = activeSurface {
            ghosttyApp?.setFocusOnSurface(newSurface, focused: true)
        }

        // Queue a render
        if let gl = glArea {
            gtk_gl_area_queue_render(gl)
        }

        updateSidebar()
        updateWindowTitle()
        cmuxLog("[workspace] Switched to workspace \(index + 1)")
    }

    /// Mark active workspace as having a notification (for non-focused workspaces)
    func notifyActive(title: String, body: String) {
        guard activeIndex >= 0, activeIndex < workspaces.count else { return }
        let msg = body.isEmpty ? title : "\(title): \(body)"
        workspaces[activeIndex].lastNotification = msg
        // Mark non-active workspaces as unread when they get notifications
        // (In practice, notifications come from the focused surface, so this
        //  would be useful when we track per-surface notifications)
        g_idle_add({ _ -> gboolean in
            workspaceManager.updateSidebar()
            return 0
        }, nil)
        cmuxLog("[notification] \(msg)")
    }

    /// Mark active workspace as having a bell
    func bellActive() {
        guard activeIndex >= 0, activeIndex < workspaces.count else { return }
        workspaces[activeIndex].hasUnread = true
        g_idle_add({ _ -> gboolean in
            workspaceManager.updateSidebar()
            return 0
        }, nil)
        cmuxLog("[bell] Workspace \(workspaces[activeIndex].id)")
    }

    /// Clear unread state when switching to a workspace
    func clearUnread(index: Int) {
        guard index >= 0, index < workspaces.count else { return }
        workspaces[index].hasUnread = false
        workspaces[index].lastNotification = nil
    }

    /// Pending title/cwd updates (set from any thread, applied on main thread)
    var pendingTitle: String?
    var pendingCwd: String?

    /// Update the active workspace's title (called from action callback thread)
    func updateActiveTitle(_ title: String) {
        pendingTitle = title
        g_idle_add({ _ -> gboolean in
            workspaceManager.applyPendingUpdates()
            return 0
        }, nil)
    }

    /// Update the active workspace's CWD (called from action callback thread)
    func updateActiveCwd(_ cwd: String) {
        pendingCwd = cwd
        g_idle_add({ _ -> gboolean in
            workspaceManager.applyPendingUpdates()
            return 0
        }, nil)
    }

    /// Apply pending title/cwd updates on the GTK main thread
    func applyPendingUpdates() {
        guard activeIndex >= 0, activeIndex < workspaces.count else { return }
        var changed = false

        if let title = pendingTitle {
            // Extract just the path portion from "user@host:path" format
            let displayTitle: String
            if let colonIdx = title.lastIndex(of: ":") {
                let path = String(title[title.index(after: colonIdx)...])
                let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
                displayTitle = path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
            } else {
                displayTitle = title
            }
            workspaces[activeIndex].title = "\(workspaces[activeIndex].id): \(displayTitle)"
            pendingTitle = nil
            changed = true
        }

        if let cwd = pendingCwd {
            let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
            let display = cwd.hasPrefix(home) ? "~" + cwd.dropFirst(home.count) : cwd
            workspaces[activeIndex].cwd = String(display)
            workspaces[activeIndex].title = "\(workspaces[activeIndex].id): \(display)"
            pendingCwd = nil
            changed = true
        }

        if changed {
            updateSidebar()
            updateWindowTitle()
        }
    }

    /// Split the active pane in the current workspace
    func splitActivePane(orientation: PaneSplit.SplitOrientation) {
        guard activeIndex >= 0, activeIndex < workspaces.count else { return }
        guard let gApp = ghosttyApp else { return }
        guard let contentBox = contentBoxWidget else { return }

        let ws = workspaces[activeIndex]

        // Create new pane
        guard let newPane = createTerminalPane(ghosttyApp: gApp) else {
            cmuxLog("[split] Failed to create new pane")
            return
        }

        if let currentRoot = ws.rootPane {
            // Already has a pane tree — wrap current root + new pane in a split
            let split = PaneSplit(orientation: orientation, first: currentRoot, second: .leaf(newPane))
            workspaces[activeIndex].rootPane = .split(split)
        } else if let currentWidget = ws.contentWidget {
            // First split — wrap the existing GL area in a pane leaf + new pane
            let existingLeaf = PaneLeaf(id: 0)
            existingLeaf.widget = currentWidget
            existingLeaf.glArea = unsafeBitCast(currentWidget, to: UnsafeMutablePointer<GtkGLArea>.self)
            existingLeaf.surface = ws.surface

            let split = PaneSplit(orientation: orientation, first: .leaf(existingLeaf), second: .leaf(newPane))
            workspaces[activeIndex].rootPane = .split(split)
        } else {
            cmuxLog("[split] No content to split")
            return
        }

        // Rebuild the widget tree
        if let oldWidget = ws.contentWidget {
            // Remove old widget from parent
            let parent = gtk_widget_get_parent(oldWidget)
            if let parent = parent {
                let parentBox = unsafeBitCast(parent, to: UnsafeMutablePointer<GtkBox>.self)
                gtk_box_remove(parentBox, oldWidget)
            }
        }

        // Build new widget tree from pane structure
        if let newWidget = buildPaneWidget(workspaces[activeIndex].rootPane!) {
            gtk_box_append(contentBox, newWidget)
            workspaces[activeIndex].contentWidget = newWidget
        }

        cmuxLog("[split] Split \(orientation == .horizontal ? "horizontal" : "vertical"), panes in workspace \(workspaces[activeIndex].id)")
    }

    /// The content area box widget (set by main.swift)
    var contentBoxWidget: UnsafeMutablePointer<GtkBox>?

    /// Close the active workspace
    func closeActive() {
        guard workspaces.count > 1 else {
            cmuxLog("[workspace] Can't close last workspace")
            return
        }
        let removed = workspaces.remove(at: activeIndex)
        cmuxLog("[workspace] Closed workspace \(removed.id)")

        // If we removed a surface, free it
        if let surface = removed.surface {
            ghosttyApp?.fn_surface_free?(surface)
        }

        // Adjust active index
        if activeIndex >= workspaces.count {
            activeIndex = workspaces.count - 1
        }

        // Focus the new active
        if let newSurface = activeSurface {
            ghosttyApp?.setFocusOnSurface(newSurface, focused: true)
        }
        if let gl = glArea {
            gtk_gl_area_queue_render(gl)
        }
        updateSidebar()
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

    /// Update the window title to show active workspace info
    func updateWindowTitle() {
        guard let win = window else { return }
        if let ws = activeWorkspace {
            gtk_window_set_title(win, "cmux — \(ws.title)")
        } else {
            gtk_window_set_title(win, "cmux")
        }
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
            // Show the workspace title with notification indicator
            let notifMark = ws.hasUnread ? " *" : ""
            let displayText = ws.title
            let label = gtk_label_new("\(prefix)\(displayText)\(notifMark)")
            gtk_widget_set_halign(label, GTK_ALIGN_START)
            // Ellipsize handled by truncating in Swift


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
