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
    var glArea: UnsafeMutablePointer<GtkGLArea>?  // Each workspace has its own GL area
    var gitBranch: String?
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
    var glArea: UnsafeMutablePointer<GtkGLArea>?  // Legacy — used for splits only
    var window: UnsafeMutablePointer<GtkWindow>?
    var stack: OpaquePointer?  // GtkStack — one child per workspace

    var activeWorkspace: Workspace? {
        guard activeIndex >= 0, activeIndex < workspaces.count else { return nil }
        return workspaces[activeIndex]
    }

    var activeSurface: UnsafeMutableRawPointer? {
        return activeWorkspace?.surface
    }

    /// Create a new workspace with its OWN GtkGLArea and ghostty surface
    func createWorkspace(ghosttyApp: GhosttyApp,
                         glArea: UnsafeMutablePointer<GtkGLArea>? = nil,
                         widget: UnsafeMutablePointer<GtkWidget>? = nil,
                         command: String? = nil, workingDirectory: String? = nil,
                         title: String? = nil) -> Int {
        let id = workspaces.count + 1
        var ws = Workspace(id: id)
        if let title = title { ws.title = "\(id): \(title)" }

        // Create a NEW GtkGLArea for this workspace
        guard let newGlArea = gtk_gl_area_new() else { return 0 }
        gtk_widget_set_hexpand(newGlArea, 1)
        gtk_widget_set_vexpand(newGlArea, 1)
        gtk_widget_set_focusable(newGlArea, 1)
        gtk_widget_set_can_focus(newGlArea, 1)
        let newGlPtr = unsafeBitCast(newGlArea, to: UnsafeMutablePointer<GtkGLArea>.self)
        gtk_gl_area_set_auto_render(newGlPtr, 1)

        ws.contentWidget = newGlArea
        ws.glArea = newGlPtr

        // Store creation params for the realize callback
        let wsIndex = workspaces.count  // Index this workspace will have
        paneManager.setCwd(glArea: newGlPtr, cwd: workingDirectory ?? "")

        // Render callback for this workspace's GL area
        let renderCb: @convention(c) (UnsafeMutablePointer<GtkGLArea>?, OpaquePointer?, gpointer?) -> gboolean = { glArea, ctx, _ in
            if let surface = paneManager.surfaceForGLArea(glArea),
               let gApp = getGhosttyApp() {
                gApp.drawSurface(surface)
            }
            return 1
        }
        g_signal_connect_data(newGlArea, "render",
            unsafeBitCast(renderCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

        // Realize callback — create ghostty surface when GL is ready
        let realizeCb: @convention(c) (UnsafeMutablePointer<GtkWidget>?, gpointer?) -> Void = { widget, _ in
            guard let widget = widget, let gApp = getGhosttyApp() else { return }
            let glPtr = unsafeBitCast(widget, to: UnsafeMutablePointer<GtkGLArea>.self)
            gtk_gl_area_make_current(glPtr)

            let cwd = paneManager.getCwd(glArea: glPtr)
            if gApp.createSurface(glArea: glPtr, widget: widget, workingDirectory: cwd) {
                paneManager.registerSurface(glArea: glPtr, surface: gApp.surface!)
                // Find and update the workspace that owns this GL area
                for i in 0..<workspaceManager.workspaces.count {
                    if workspaceManager.workspaces[i].glArea == glPtr {
                        workspaceManager.workspaces[i].surface = gApp.surface
                        break
                    }
                }
                let w = gtk_widget_get_width(widget)
                let h = gtk_widget_get_height(widget)
                if w > 0 && h > 0 {
                    gApp.fn_surface_set_size?(gApp.surface!, UInt32(w), UInt32(h))
                }
                gApp.fn_surface_set_focus?(gApp.surface!, true)
                let scale = Double(gtk_widget_get_scale_factor(widget))
                gApp.fn_surface_set_content_scale?(gApp.surface!, scale, scale)
                _ = gtk_widget_grab_focus(widget)
                cmuxLog("[workspace] Surface realized for GL area")
            }
        }
        g_signal_connect_data(newGlArea, "realize",
            unsafeBitCast(realizeCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

        // Resize callback
        let resizeCb: @convention(c) (UnsafeMutablePointer<GtkGLArea>?, Int32, Int32, gpointer?) -> Void = { glArea, w, h, _ in
            if let surface = paneManager.surfaceForGLArea(glArea),
               let gApp = getGhosttyApp(), w > 0, h > 0 {
                gApp.fn_surface_set_size?(surface, UInt32(w), UInt32(h))
            }
        }
        g_signal_connect_data(newGlArea, "resize",
            unsafeBitCast(resizeCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

        // Add to GtkStack
        if let stack = stack {
            let stackName = "ws-\(id)"
            stackName.withCString { cName in
                gtk_stack_add_named(stack, newGlArea, cName)
            }
        }

        workspaces.append(ws)
        activeIndex = workspaces.count - 1

        // Show this workspace in the stack
        showActiveInStack()

        updateSidebar()
        cmuxLog("[workspace] Created workspace \(id), total=\(workspaces.count)")
        return id
    }

    /// Show the active workspace's GL area in the stack
    func showActiveInStack() {
        guard let stack = stack else { return }
        guard let ws = activeWorkspace else { return }
        // Show the workspace's widget in the stack
        if let contentWidget = ws.contentWidget {
            gtk_stack_set_visible_child(stack, contentWidget)
        }
        // Direct focus grab — simpler and less crash-prone
        if let contentWidget = ws.contentWidget {
            _ = gtk_widget_grab_focus(contentWidget)
        }
    }

    /// Switch to workspace at index
    func switchTo(index: Int) {
        guard index >= 0, index < workspaces.count else { return }
        guard index != activeIndex else { return }

        activeIndex = index
        clearUnread(index: index)

        // Switch visible child in GtkStack
        showActiveInStack()

        // Tell ghostty the new surface is focused (required for key input)
        if let newSurface = activeSurface {
            ghosttyApp?.fn_surface_set_focus?(newSurface, true)
        }

        // Queue GL render on the new active workspace
        if let ws = activeWorkspace, let glArea = ws.glArea {
            gtk_gl_area_queue_render(glArea)
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

    /// Update the active workspace's git branch
    func updateActiveGitBranch(_ branch: String) {
        guard activeIndex >= 0, activeIndex < workspaces.count else { return }
        workspaces[activeIndex].gitBranch = branch
        g_idle_add({ _ -> gboolean in
            workspaceManager.updateSidebar()
            return 0
        }, nil)
    }

    /// Detect git branch from CWD by reading .git/HEAD
    private func detectGitBranch(forCwd cwd: String) {
        guard activeIndex >= 0, activeIndex < workspaces.count else { return }
        let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
        let fullPath = cwd.hasPrefix("~") ? home + String(cwd.dropFirst(1)) : cwd
        let gitHeadPath = fullPath + "/.git/HEAD"
        if let headContent = try? String(contentsOfFile: gitHeadPath, encoding: .utf8),
           headContent.hasPrefix("ref: refs/heads/") {
            let branch = String(headContent.dropFirst("ref: refs/heads/".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            workspaces[activeIndex].gitBranch = branch
        } else {
            workspaces[activeIndex].gitBranch = nil
        }
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
            workspaces[activeIndex].cwd = displayTitle  // Update CWD from title path
            detectGitBranch(forCwd: displayTitle)
            pendingTitle = nil
            changed = true
        }

        if let cwd = pendingCwd {
            let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
            let display = cwd.hasPrefix(home) ? "~" + cwd.dropFirst(home.count) : cwd
            workspaces[activeIndex].cwd = String(display)
            workspaces[activeIndex].title = "\(workspaces[activeIndex].id): \(display)"
            detectGitBranch(forCwd: String(display))
            pendingCwd = nil
            changed = true
        }

        if changed {
            updateSidebar()
            updateWindowTitle()
            if let sidebar = sidebarWidget {
                gtk_widget_queue_draw(sidebar)
            }
        }
    }

    /// Split the active pane in the current workspace.
    /// Creates TWO fresh GtkGLAreas (avoids GL context loss from reparenting).
    func splitActivePane(orientation: PaneSplit.SplitOrientation) {
        // Split panes disabled — the embedded API's ghostty_surface_new crashes
        // when creating surfaces in GtkGLAreas nested inside GtkPaned within GtkStack.
        // The GL context isn't properly initialized in that configuration.
        // TODO: Fix by deferring surface creation or using a different split approach.
        cmuxLog("[split] Split panes temporarily disabled (GL context issue in nested containers)")
        return
        guard activeIndex >= 0, activeIndex < workspaces.count else { return }
        guard let gApp = getGhosttyApp() else { return }
        guard let stack = stack else { return }

        let ws = workspaces[activeIndex]

        // Get current CWD for inheritance
        let currentCwd = ws.cwd
        let home = ProcessInfo.processInfo.environment["HOME"] ?? "/home"
        let fullCwd: String? = currentCwd.hasPrefix("~")
            ? home + String(currentCwd.dropFirst(1)) : (currentCwd == "~" ? home : currentCwd)

        // Create two new panes inheriting the current CWD
        guard let pane1 = createTerminalPane(ghosttyApp: gApp, workingDirectory: fullCwd),
              let pane2 = createTerminalPane(ghosttyApp: gApp, workingDirectory: fullCwd) else {
            cmuxLog("[split] Failed to create panes")
            return
        }

        let split = PaneSplit(orientation: orientation, first: .leaf(pane1), second: .leaf(pane2))
        workspaces[activeIndex].rootPane = .split(split)

        // Remove old GL area from stack
        if let oldWidget = ws.contentWidget {
            gtk_stack_remove(stack, oldWidget)
            if let oldSurface = ws.surface {
                gApp.fn_surface_free?(oldSurface)
            }
        }

        // Build new widget tree (GtkPaned with two GL areas)
        if let newWidget = buildPaneWidget(.split(split)) {
            let stackName = "ws-\(ws.id)"
            stackName.withCString { cName in
                gtk_stack_add_named(stack, newWidget, cName)
            }
            workspaces[activeIndex].contentWidget = newWidget
            showActiveInStack()

            // The GL areas will realize asynchronously when shown.
            // The realize callback in PaneManager creates the ghostty surface
            // and registers it in paneManager.surfaceMap.
            // The workspace surface will be updated by the realize callback.
            cmuxLog("[split] Panes added to stack, waiting for realize...")
        }

        cmuxLog("[split] Split \(orientation == .horizontal ? "horizontal" : "vertical")")
    }

    /// Close the focused pane within a split, collapsing the split
    func closeFocusedPane() {
        guard activeIndex >= 0, activeIndex < workspaces.count else { return }
        guard workspaces[activeIndex].rootPane != nil else { return }
        guard let stack = stack else { return }
        guard let gApp = getGhosttyApp() else { return }

        let ws = workspaces[activeIndex]

        // Remove old split from stack
        if let oldWidget = ws.contentWidget {
            gtk_stack_remove(stack, oldWidget)
        }

        // Create a single new GL area
        let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
        let cwd = ws.cwd
        let fullCwd = cwd.hasPrefix("~") ? home + String(cwd.dropFirst(1)) : cwd

        guard let newPane = createTerminalPane(ghosttyApp: gApp, workingDirectory: fullCwd) else { return }
        if let widget = newPane.widget {
            let stackName = "ws-\(ws.id)"
            stackName.withCString { cName in
                gtk_stack_add_named(stack, widget, cName)
            }
            workspaces[activeIndex].contentWidget = widget
            workspaces[activeIndex].glArea = newPane.glArea
            workspaces[activeIndex].rootPane = nil
            workspaces[activeIndex].surface = newPane.surface
            showActiveInStack()
        }

        cmuxLog("[pane] Collapsed split to single pane")
    }

    /// The content area box widget (set by main.swift)
    var contentBoxWidget: UnsafeMutablePointer<GtkBox>?

    /// Close the active workspace
    func closeActive() {
        if workspaces.count <= 1 {
            cmuxLog("[workspace] Closing last workspace, exiting")
            LinuxSessionPersistence.clear()
            socketServer?.stop()
            exit(0)
        }
        let removed = workspaces.remove(at: activeIndex)
        cmuxLog("[workspace] Closed workspace \(removed.id)")

        // Remove from GtkStack
        if let stack = stack, let contentWidget = removed.contentWidget {
            gtk_stack_remove(stack, contentWidget)
        }

        // Free the surface
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
        showActiveInStack()
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

    var sidebarVisible = true
    var sidebarWidget: UnsafeMutablePointer<GtkWidget>?
    var separatorWidget: UnsafeMutablePointer<GtkWidget>?

    /// Toggle sidebar visibility
    func toggleSidebar() {
        sidebarVisible = !sidebarVisible
        if let sidebar = sidebarWidget {
            gtk_widget_set_visible(sidebar, sidebarVisible ? 1 : 0)
        }
        if let sep = separatorWidget {
            gtk_widget_set_visible(sep, sidebarVisible ? 1 : 0)
        }
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

        // Add header with styling
        let header = gtk_label_new("Workspaces")
        gtk_widget_set_halign(header, GTK_ALIGN_START)
        gtk_widget_set_margin_start(header, 8)
        gtk_widget_set_margin_top(header, 4)
        gtk_widget_set_margin_bottom(header, 4)
        // Style the header with CSS
        let headerCss = gtk_css_provider_new()!
        gtk_css_provider_load_from_string(headerCss, "label { font-weight: bold; font-size: 11px; opacity: 0.6; }")
        let headerCtx = gtk_widget_get_style_context(header)
        gtk_style_context_add_provider(headerCtx, OpaquePointer(headerCss), 800)
        gtk_box_append(box, header)

        // Add workspace entries
        for (i, ws) in workspaces.enumerated() {
            let prefix = i == activeIndex ? "▸ " : "  "
            // Show the workspace title with notification indicator
            let notifDot = ws.hasUnread ? " 🔵" : ""
            let displayText = ws.title
            let branchInfo = ws.gitBranch != nil ? "  \(ws.gitBranch!)" : ""
            let label = gtk_label_new("\(prefix)\(displayText)\(branchInfo)\(notifDot)")
            gtk_widget_set_halign(label, GTK_ALIGN_START)
            gtk_widget_set_margin_start(label, 8)
            gtk_widget_set_margin_top(label, 2)
            gtk_widget_set_margin_bottom(label, 2)

            // Style active workspace with highlight
            let css = gtk_css_provider_new()!
            if i == activeIndex {
                gtk_css_provider_load_from_string(css, "label { background: alpha(white, 0.1); border-radius: 4px; padding: 4px 8px; font-size: 12px; }")
            } else if ws.hasUnread {
                gtk_css_provider_load_from_string(css, "label { color: #6cb6ff; font-size: 12px; padding: 4px 8px; }")
            } else {
                gtk_css_provider_load_from_string(css, "label { opacity: 0.7; font-size: 12px; padding: 4px 8px; }")
            }
            let ctx = gtk_widget_get_style_context(label)
            gtk_style_context_add_provider(ctx, OpaquePointer(css), 800)


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
        // Focus the terminal after switching
        if let glArea = globalGLArea {
            let w = unsafeBitCast(glArea, to: UnsafeMutablePointer<GtkWidget>.self)
            _ = gtk_widget_grab_focus(w)
        }
    }
}
