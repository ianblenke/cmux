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
    var ptyMasterFd: Int32 = -1  // PTY master fd for direct writes
    var needsSurfaceRecreate: Bool = false  // Set when hidden during a resize

    // Split state — when split, the GtkStack is hidden and a GtkPaned
    // with two fresh GtkGLAreas is shown directly in the content box.
    // The original workspace surface/glArea stay in the hidden GtkStack.
    var splitPanedWidget: UnsafeMutablePointer<GtkWidget>?
    var splitFirstGlArea: UnsafeMutablePointer<GtkGLArea>?
    var splitFirstSurface: UnsafeMutableRawPointer?
    var splitSecondGlArea: UnsafeMutablePointer<GtkGLArea>?
    var splitSecondSurface: UnsafeMutableRawPointer?
    var isSplit: Bool { splitPanedWidget != nil }

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

    var activeWorkspace: Workspace? {
        guard activeIndex >= 0, activeIndex < workspaces.count else { return nil }
        return workspaces[activeIndex]
    }

    /// Which surface in a split has keyboard focus (nil = primary surface)
    var splitFocusedSecond: Bool = false

    /// True during split open/close to suppress mouse events to freed surfaces
    var splitTransitionInProgress: Bool = false

    var activeSurface: UnsafeMutableRawPointer? {
        if let ws = activeWorkspace, ws.isSplit {
            return splitFocusedSecond ? ws.splitSecondSurface : ws.splitFirstSurface
        }
        return activeWorkspace?.surface
    }

    /// PTY master fd for the active workspace
    var activePtyFd: Int32 {
        return activeWorkspace?.ptyMasterFd ?? -1
    }

    /// Rescan PTY master fds for workspaces that don't have one assigned.
    /// The PTY is opened asynchronously by ghostty's IO thread after surface creation.
    func rescanPtyFds() {
        // First, verify existing assignments are still valid
        for i in 0..<workspaces.count {
            if workspaces[i].ptyMasterFd >= 0 {
                // Check if the fd is still open and pointing to ptmx
                var target = [CChar](repeating: 0, count: 256)
                let len = readlink("/proc/self/fd/\(workspaces[i].ptyMasterFd)", &target, 255)
                if len <= 0 || !String(cString: target).contains("ptmx") {
                    cmuxLog("[workspace] PTY fd=\(workspaces[i].ptyMasterFd) is stale for workspace \(workspaces[i].id)")
                    workspaces[i].ptyMasterFd = -1
                }
            }
        }

        let allPtmx = WorkspaceManager.findPtmxFds()
        let assignedFds = Set(workspaces.compactMap { $0.ptyMasterFd > 0 ? $0.ptyMasterFd : nil })
        let unassigned = allPtmx.subtracting(assignedFds).sorted()

        // Assign unassigned fds to workspaces missing them (in order)
        var unassignedIdx = 0
        for i in 0..<workspaces.count {
            if workspaces[i].ptyMasterFd < 0 && workspaces[i].surface != nil {
                if unassignedIdx < unassigned.count {
                    workspaces[i].ptyMasterFd = unassigned[unassignedIdx]
                    cmuxLog("[workspace] Late-assigned PTY master fd=\(unassigned[unassignedIdx]) for workspace \(workspaces[i].id)")
                    unassignedIdx += 1
                }
            }
        }
    }

    /// Find all open ptmx file descriptors in /proc/self/fd
    static func findPtmxFds() -> Set<Int32> {
        var fds = Set<Int32>()
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: "/proc/self/fd") else {
            cmuxLog("[ptmx] Failed to list /proc/self/fd")
            return fds
        }
        for entry in entries {
            guard let fdNum = Int32(entry) else { continue }
            var target = [CChar](repeating: 0, count: 256)
            let len = readlink("/proc/self/fd/\(entry)", &target, 255)
            if len > 0 {
                let path = String(cString: target)
                if path.contains("ptmx") {
                    fds.insert(fdNum)
                }
            }
        }
        return fds
    }

    /// Create a new workspace with its own GtkGLArea and ghostty surface
    func createWorkspace(ghosttyApp: GhosttyApp,
                         glArea: UnsafeMutablePointer<GtkGLArea>? = nil,
                         widget: UnsafeMutablePointer<GtkWidget>? = nil,
                         command: String? = nil, workingDirectory: String? = nil,
                         title: String? = nil) -> Int {
        let id = workspaces.count + 1
        var ws = Workspace(id: id)
        if let title = title { ws.title = "\(id): \(title)" }

        guard let newGlArea = gtk_gl_area_new() else { return 0 }
        gtk_widget_set_hexpand(newGlArea, 1)
        gtk_widget_set_vexpand(newGlArea, 1)
        gtk_widget_set_focusable(newGlArea, 1)
        gtk_widget_set_can_focus(newGlArea, 1)
        let newGlPtr = unsafeBitCast(newGlArea, to: UnsafeMutablePointer<GtkGLArea>.self)
        gtk_gl_area_set_auto_render(newGlPtr, 0)

        ws.contentWidget = newGlArea
        ws.glArea = newGlPtr

        paneManager.setCwd(glArea: newGlPtr, cwd: workingDirectory ?? "")

        // Render callback
        let renderCb: @convention(c) (UnsafeMutablePointer<GtkGLArea>?, OpaquePointer?, gpointer?) -> gboolean = { glArea, ctx, _ in
            guard let activeWs = workspaceManager.activeWorkspace,
                  activeWs.glArea == glArea else { return 1 }
            if let surface = activeWs.surface, let gApp = getGhosttyApp() {
                gApp.drawSurface(surface)
            }
            return 1
        }
        g_signal_connect_data(newGlArea, "render",
            unsafeBitCast(renderCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

        // Realize callback — skip surface creation if reparenting (surface already exists)
        let realizeCb: @convention(c) (UnsafeMutablePointer<GtkWidget>?, gpointer?) -> Void = { widget, _ in
            guard let widget = widget, let gApp = getGhosttyApp() else { return }
            let glPtr = unsafeBitCast(widget, to: UnsafeMutablePointer<GtkGLArea>.self)

            // Skip if this GL area already has a surface (reparent during split)
            for ws in workspaceManager.workspaces {
                if ws.glArea == glPtr && ws.surface != nil {
                    cmuxLog("[workspace] Realize: reparent detected, skipping surface creation")
                    return
                }
            }

            gtk_gl_area_make_current(glPtr)
            let usedFds = Set(workspaceManager.workspaces.compactMap { $0.ptyMasterFd > 0 ? $0.ptyMasterFd : nil })
            let cwd = paneManager.getCwd(glArea: glPtr)
            if gApp.createSurface(glArea: glPtr, widget: widget, workingDirectory: cwd) {
                paneManager.registerSurface(glArea: glPtr, surface: gApp.surface!)
                let allPtmx = WorkspaceManager.findPtmxFds()
                let ptyFd = allPtmx.subtracting(usedFds).max() ?? -1
                for i in 0..<workspaceManager.workspaces.count {
                    if workspaceManager.workspaces[i].glArea == glPtr {
                        workspaceManager.workspaces[i].surface = gApp.surface
                        workspaceManager.workspaces[i].ptyMasterFd = ptyFd
                        break
                    }
                }
                let w = gtk_widget_get_width(widget)
                let h = gtk_widget_get_height(widget)
                if w > 0 && h > 0 { gApp.fn_surface_set_size?(gApp.surface!, UInt32(w), UInt32(h)) }
                gApp.fn_surface_set_focus?(gApp.surface!, true)
                let scale = Double(gtk_widget_get_scale_factor(widget))
                gApp.fn_surface_set_content_scale?(gApp.surface!, scale, scale)
                _ = gtk_widget_grab_focus(widget)
                cmuxLog("[workspace] Surface realized for GL area")
            }
        }
        g_signal_connect_data(newGlArea, "realize",
            unsafeBitCast(realizeCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

        // Resize callback — apply size to ghostty immediately
        let resizeCb: @convention(c) (UnsafeMutablePointer<GtkGLArea>?, Int32, Int32, gpointer?) -> Void = { glArea, w, h, _ in
            guard let glArea = glArea, w > 0, h > 0 else { return }
            cmuxLog("[resize] Signal fired: \(w)x\(h) glArea=\(glArea)")
            guard let surface = workspaceManager.activeSurface,
                  let gApp = getGhosttyApp() else {
                cmuxLog("[resize] SKIP: no active surface")
                return
            }
            let widget = unsafeBitCast(glArea, to: UnsafeMutablePointer<GtkWidget>.self)
            let scale = Double(gtk_widget_get_scale_factor(widget))
            gApp.fn_surface_set_content_scale?(surface, scale, scale)
            gApp.fn_surface_set_size?(surface, UInt32(w), UInt32(h))
            workspaceManager.lastResizeW = w
            workspaceManager.lastResizeH = h
            g_timeout_add(50, { _ -> gboolean in
                if let ws = workspaceManager.activeWorkspace,
                   let surface = ws.surface,
                   let glArea = ws.glArea,
                   let gApp = getGhosttyApp() {
                    gApp.fn_surface_refresh?(surface)
                    gtk_gl_area_queue_render(glArea)
                }
                return 0
            }, nil)
        }
        g_signal_connect_data(newGlArea, "resize",
            unsafeBitCast(resizeCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

        ws.contentWidget = newGlArea

        if let st = stack {
            let name = "ws-\(id)"
            name.withCString { cName in
                gtk_stack_add_named(st, newGlArea, cName)
            }
        }

        workspaces.append(ws)
        activeIndex = workspaces.count - 1
        showActiveInStack()

        updateSidebar()
        cmuxLog("[workspace] Created workspace \(id), total=\(workspaces.count)")
        return id
    }

    /// GtkStack — only the visible child gets size-allocated.
    /// Hidden children keep their old GL state intact.
    var stack: OpaquePointer?  // GtkStack*
    // notebook is now stack — use stack directly
    /// Last resize dimensions
    var lastResizeW: Int32 = 0
    var lastResizeH: Int32 = 0
    var hiddenDetached: Bool = false
    var pendingRendererReinit: Bool = false
    var contentContainer: UnsafeMutablePointer<GtkBox>?
    var currentDisplayedWidget: UnsafeMutablePointer<GtkWidget>?

    func showActiveInStack() {
        guard let st = stack else { return }

        // Disable auto-render on all, enable only active
        for w in workspaces {
            if let gl = w.glArea { gtk_gl_area_set_auto_render(gl, 0) }
        }

        // Switch visible child in GtkStack
        if let ws = activeWorkspace, let widget = ws.contentWidget {
            let name = "ws-\(ws.id)"
            name.withCString { cName in
                gtk_stack_set_visible_child_name(st, cName)
            }
        }

        if let gl = activeWorkspace?.glArea {
            gtk_gl_area_set_auto_render(gl, 1)
        }

        // Focus and resize the newly visible workspace
        if let ws = activeWorkspace, let glArea = ws.glArea {
            let glWidget = unsafeBitCast(glArea, to: UnsafeMutablePointer<GtkWidget>.self)
            if let surface = ws.surface, let gApp = getGhosttyApp() {
                gApp.fn_surface_set_focus?(surface, true)
                // Apply stored resize if window was resized while hidden
                if lastResizeW > 0 && lastResizeH > 0 {
                    gtk_gl_area_make_current(glArea)
                    gApp.fn_surface_set_size?(surface, UInt32(lastResizeW), UInt32(lastResizeH))
                    let scale = Double(gtk_widget_get_scale_factor(glWidget))
                    gApp.fn_surface_set_content_scale?(surface, scale, scale)
                }
                gApp.fn_surface_refresh?(surface)
                gtk_gl_area_queue_render(glArea)
            }
            _ = gtk_widget_grab_focus(glWidget)
        }
    }

    // Surface recreation and PTY fd management methods below

    /// Recreate the ghostty surface for a workspace whose GL state was corrupted by resize.
    /// This destroys the old surface and creates a new one on the same GL area,
    /// preserving the workspace's CWD. The old shell session is lost.
    func recreateSurface(at index: Int, ghosttyApp gApp: GhosttyApp) {
        guard index >= 0, index < workspaces.count else { return }
        let ws = workspaces[index]
        guard let glArea = ws.glArea else { return }

        // Free the old surface (ghostty closes the PTY master fd internally)
        if let oldSurface = ws.surface {
            gApp.fn_surface_free?(oldSurface)
            workspaces[index].ptyMasterFd = -1
            workspaces[index].surface = nil
            cmuxLog("[workspace] Freed old surface for workspace \(ws.id)")
        }

        // Get the CWD from the workspace
        let cwd = ws.cwd.hasPrefix("~")
            ? (ProcessInfo.processInfo.environment["HOME"] ?? "") + String(ws.cwd.dropFirst(1))
            : ws.cwd

        // Snapshot existing PTY fds
        let usedFds = Set(workspaces.enumerated().compactMap { (i, w) in
            i != index && w.ptyMasterFd > 0 ? w.ptyMasterFd : nil
        })

        // Create new surface on the same GL area
        let glWidget = unsafeBitCast(glArea, to: UnsafeMutablePointer<GtkWidget>.self)
        gtk_gl_area_make_current(glArea)
        if gApp.createSurface(glArea: glArea, widget: glWidget, workingDirectory: cwd.isEmpty ? nil : cwd) {
            paneManager.registerSurface(glArea: glArea, surface: gApp.surface!)
            workspaces[index].surface = gApp.surface

            // PTY fd will be assigned lazily by rescanPtyFds when pty_write is called
            // (the PTY opens asynchronously in ghostty's IO thread)
            workspaces[index].ptyMasterFd = -1

            // Apply current window size
            let w = gtk_widget_get_width(glWidget)
            let h = gtk_widget_get_height(glWidget)
            if w > 0 && h > 0 {
                gApp.fn_surface_set_size?(gApp.surface!, UInt32(w), UInt32(h))
            }
            let scale = Double(gtk_widget_get_scale_factor(glWidget))
            gApp.fn_surface_set_content_scale?(gApp.surface!, scale, scale)
            gApp.fn_surface_set_focus?(gApp.surface!, true)
            gApp.fn_surface_refresh?(gApp.surface!)

            cmuxLog("[workspace] Surface recreated for workspace \(ws.id), ptyFd=\(workspaces[index].ptyMasterFd)")
        } else {
            cmuxLog("[workspace] FAILED to recreate surface for workspace \(ws.id)")
        }

        workspaces[index].needsSurfaceRecreate = false
    }

    /// Switch to workspace at index
    func switchTo(index: Int) {
        guard index >= 0, index < workspaces.count else { return }
        guard index != activeIndex else { return }

        let oldWs = workspaces[activeIndex]
        let newWs = workspaces[index]

        // Hide old split paned if the old workspace was split
        if let oldPaned = oldWs.splitPanedWidget {
            gtk_widget_set_visible(oldPaned, 0)
        }

        activeIndex = index
        clearUnread(index: index)

        if let st = stack {
            let stackWidget = unsafeBitCast(st, to: UnsafeMutablePointer<GtkWidget>.self)

            if newWs.isSplit {
                // Target is split — hide stack, show its paned
                gtk_widget_set_visible(stackWidget, 0)
                if let newPaned = newWs.splitPanedWidget {
                    gtk_widget_set_visible(newPaned, 1)
                }
            } else {
                // Target is not split — show stack, switch to its page
                gtk_widget_set_visible(stackWidget, 1)
                showActiveInStack()
            }
        }

        // Unfocus ALL surfaces, then focus the new one
        for ws in workspaces {
            if let s = ws.surface { ghosttyApp?.fn_surface_set_focus?(s, false) }
            if let s = ws.splitFirstSurface { ghosttyApp?.fn_surface_set_focus?(s, false) }
            if let s = ws.splitSecondSurface { ghosttyApp?.fn_surface_set_focus?(s, false) }
        }
        if let newSurface = activeSurface {
            ghosttyApp?.fn_surface_set_focus?(newSurface, true)
        }

        // Queue GL render
        if let ws = activeWorkspace, let glArea = ws.glArea {
            gtk_gl_area_queue_render(glArea)
        }
        if let gl1 = activeWorkspace?.splitFirstGlArea {
            gtk_gl_area_queue_render(gl1)
        }
        if let gl2 = activeWorkspace?.splitSecondGlArea {
            gtk_gl_area_queue_render(gl2)
        }

        updateSidebar()
        updateWindowTitle()
        cmuxLog("[workspace] Switched to workspace \(index + 1)\(newWs.isSplit ? " (split)" : "")")
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

    /// Split the active workspace into two panes. The GtkStack is hidden and
    /// replaced by a GtkPaned containing two GtkGLAreas as direct children
    /// of the content box. Each GtkGLArea gets its own GL context — no sharing.
    /// GtkGLArea render signals work correctly in GtkPaned when not nested
    /// inside GtkStack (proven by ghostty's own GTK apprt).
    func splitActivePane(orientation: PaneSplit.SplitOrientation) {
        guard activeIndex >= 0, activeIndex < workspaces.count else { return }
        guard let gApp = getGhosttyApp() else { return }
        guard let contentBox = contentBoxWidget else { return }
        guard let st = stack else { return }
        let ws = workspaces[activeIndex]

        if ws.isSplit {
            cmuxLog("[split] Already split")
            return
        }
        guard ws.contentWidget != nil else { return }

        let currentCwd = ws.cwd
        let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
        let fullCwd: String? = currentCwd.hasPrefix("~")
            ? home + String(currentCwd.dropFirst(1)) : (currentCwd == "~" ? home : currentCwd)

        // Create ONE new GtkGLArea for the second pane. The existing GtkGLArea
        // is reparented from the GtkStack into a GtkPaned. The realize callback
        // skips surface creation for reparented GL areas (surface already exists).
        // After reparent, reinit_renderer rebuilds the GL state for the new context.

        // Helper: create a split pane GtkGLArea with render/realize/resize callbacks
        func createSplitGLArea(paneIndex: Int) -> (UnsafeMutablePointer<GtkWidget>, UnsafeMutablePointer<GtkGLArea>)? {
            guard let glArea = gtk_gl_area_new() else { return nil }
            gtk_widget_set_hexpand(glArea, 1)
            gtk_widget_set_vexpand(glArea, 1)
            gtk_widget_set_focusable(glArea, 1)
            gtk_widget_set_can_focus(glArea, 1)
            let glPtr = unsafeBitCast(glArea, to: UnsafeMutablePointer<GtkGLArea>.self)
            gtk_gl_area_set_auto_render(glPtr, 1)
            paneManager.setCwd(glArea: glPtr, cwd: fullCwd ?? "")

            let renderCb: @convention(c) (UnsafeMutablePointer<GtkGLArea>?, OpaquePointer?, gpointer?) -> gboolean = { glArea, ctx, _ in
                if let surface = paneManager.surfaceForGLArea(glArea), let gApp = getGhosttyApp() {
                    gApp.drawSurface(surface)
                }
                return 1
            }
            g_signal_connect_data(glArea, "render",
                unsafeBitCast(renderCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

            let realizeCb: @convention(c) (UnsafeMutablePointer<GtkWidget>?, gpointer?) -> Void = { widget, _ in
                guard let widget = widget, let gApp = getGhosttyApp() else { return }
                let glPtr = unsafeBitCast(widget, to: UnsafeMutablePointer<GtkGLArea>.self)
                gtk_gl_area_make_current(glPtr)
                let cwd = paneManager.getCwd(glArea: glPtr)
                if gApp.createSurface(glArea: glPtr, widget: widget, workingDirectory: cwd) {
                    let surface = gApp.surface!
                    paneManager.registerSurface(glArea: glPtr, surface: surface)
                    // Set surface on the workspace
                    for i in 0..<workspaceManager.workspaces.count {
                        if workspaceManager.workspaces[i].splitSecondGlArea == glPtr {
                            workspaceManager.workspaces[i].splitSecondSurface = surface
                        } else if workspaceManager.workspaces[i].splitFirstGlArea == glPtr {
                            workspaceManager.workspaces[i].splitFirstSurface = surface
                        }
                    }
                    let w = gtk_widget_get_width(widget)
                    let h = gtk_widget_get_height(widget)
                    if w > 0 && h > 0 {
                        gApp.fn_surface_set_size?(surface, UInt32(w), UInt32(h))
                    }
                    let scale = Double(gtk_widget_get_scale_factor(widget))
                    gApp.fn_surface_set_content_scale?(surface, scale, scale)
                    cmuxLog("[split] Pane surface realized, size \(w)x\(h)")
                }
            }
            g_signal_connect_data(glArea, "realize",
                unsafeBitCast(realizeCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

            let resizeCb: @convention(c) (UnsafeMutablePointer<GtkGLArea>?, Int32, Int32, gpointer?) -> Void = { glArea, w, h, _ in
                guard let glArea = glArea, w > 0, h > 0 else { return }
                if let surface = paneManager.surfaceForGLArea(glArea), let gApp = getGhosttyApp() {
                    let widget = unsafeBitCast(glArea, to: UnsafeMutablePointer<GtkWidget>.self)
                    let scale = Double(gtk_widget_get_scale_factor(widget))
                    gApp.fn_surface_set_content_scale?(surface, scale, scale)
                    gApp.fn_surface_set_size?(surface, UInt32(w), UInt32(h))
                    gApp.fn_surface_refresh?(surface)
                    gtk_gl_area_queue_render(glArea)
                }
            }
            g_signal_connect_data(glArea, "resize",
                unsafeBitCast(resizeCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

            return (glArea, glPtr)
        }

        // Create only the second pane (existing terminal is reparented)
        guard let (glArea2, glPtr2) = createSplitGLArea(paneIndex: 1) else {
            cmuxLog("[split] Failed to create second pane")
            return
        }

        // Reparent existing GtkGLArea from GtkStack into GtkPaned.
        // The realize callback will fire — it skips surface creation
        // when ws.surface already exists, and we reinit the renderer after.
        guard let existingWidget = ws.contentWidget, let existingGlArea = ws.glArea else { return }
        g_object_ref(UnsafeMutableRawPointer(existingWidget))
        gtk_stack_remove(st, existingWidget)

        // Build GtkPaned
        let gtkOrientation: GtkOrientation = orientation == .horizontal
            ? GTK_ORIENTATION_HORIZONTAL : GTK_ORIENTATION_VERTICAL
        guard let paned = gtk_paned_new(gtkOrientation) else {
            let name = "ws-\(ws.id)"
            name.withCString { cName in gtk_stack_add_named(st, existingWidget, cName) }
            g_object_unref(UnsafeMutableRawPointer(existingWidget))
            return
        }
        let panedPtr = OpaquePointer(paned)
        gtk_widget_set_hexpand(paned, 1)
        gtk_widget_set_vexpand(paned, 1)

        gtk_paned_set_start_child(panedPtr, existingWidget)
        gtk_paned_set_resize_start_child(panedPtr, 1)
        g_object_unref(UnsafeMutableRawPointer(existingWidget))
        gtk_paned_set_end_child(panedPtr, glArea2)
        gtk_paned_set_resize_end_child(panedPtr, 1)
        gtk_paned_set_shrink_end_child(panedPtr, 0)
        gtk_paned_set_shrink_start_child(panedPtr, 0)

        // Set workspace fields BEFORE adding paned to content box
        workspaces[activeIndex].splitPanedWidget = paned
        workspaces[activeIndex].splitFirstGlArea = existingGlArea
        workspaces[activeIndex].splitFirstSurface = ws.surface
        workspaces[activeIndex].splitSecondGlArea = glPtr2

        // Hide GtkStack, show GtkPaned in content box
        let stackWidget = unsafeBitCast(st, to: UnsafeMutablePointer<GtkWidget>.self)
        gtk_widget_set_visible(stackWidget, 0)
        let contentBoxPtr = unsafeBitCast(contentBox, to: UnsafeMutablePointer<GtkBox>.self)
        gtk_box_append(contentBoxPtr, paned)

        // Reinitialize the existing surface's renderer for the new GL context
        // (reparenting destroys the old context and creates a new one)
        if let surface = ws.surface {
            gtk_gl_area_make_current(existingGlArea)
            _ = gApp.fn_surface_reinit_renderer?(surface)
            let widget = unsafeBitCast(existingGlArea, to: UnsafeMutablePointer<GtkWidget>.self)
            let w = gtk_widget_get_width(widget)
            let h = gtk_widget_get_height(widget)
            if w > 0 && h > 0 {
                let scale = Double(gtk_widget_get_scale_factor(widget))
                gApp.fn_surface_set_content_scale?(surface, scale, scale)
                gApp.fn_surface_set_size?(surface, UInt32(w), UInt32(h))
            }
            gApp.fn_surface_refresh?(surface)
        }

        // Set divider to 50%
        let totalSize: Int32 = orientation == .horizontal
            ? gtk_widget_get_width(unsafeBitCast(contentBox, to: UnsafeMutablePointer<GtkWidget>.self))
            : gtk_widget_get_height(unsafeBitCast(contentBox, to: UnsafeMutablePointer<GtkWidget>.self))
        if totalSize > 0 { gtk_paned_set_position(panedPtr, totalSize / 2) }

        cmuxLog("[split] Visual split — existing terminal preserved + new pane")
    }

    /// Close the split. Reparents the first pane's GtkGLArea back to the GtkStack
    /// and destroys the second pane. The first pane's terminal session is preserved.
    func closeSplit() {
        guard activeIndex >= 0, activeIndex < workspaces.count else { return }
        let ws = workspaces[activeIndex]
        guard ws.isSplit, let splitPaned = ws.splitPanedWidget else { return }
        guard let contentBox = contentBoxWidget, let st = stack else { return }
        guard let gApp = getGhosttyApp() else { return }
        guard let firstGlArea = ws.splitFirstGlArea else { return }

        splitTransitionInProgress = true

        // Save refs before clearing state
        let secondSurface = ws.splitSecondSurface ?? ws.splitSecondGlArea.flatMap({ paneManager.surfaceForGLArea($0) })
        let secondGlArea = ws.splitSecondGlArea

        // Clear split state FIRST so activeSurface can't return freed pointers
        workspaces[activeIndex].surface = ws.splitFirstSurface
        workspaces[activeIndex].splitPanedWidget = nil
        workspaces[activeIndex].splitFirstGlArea = nil
        workspaces[activeIndex].splitFirstSurface = nil
        workspaces[activeIndex].splitSecondGlArea = nil
        workspaces[activeIndex].splitSecondSurface = nil
        splitFocusedSecond = false

        // Now free the second surface
        if let s2 = secondSurface { gApp.fn_surface_free?(s2) }
        if let gl2 = secondGlArea { paneManager.removeSurface(glArea: gl2) }

        // Ref the first pane's widget before unparenting from GtkPaned
        let firstWidget = unsafeBitCast(firstGlArea, to: UnsafeMutablePointer<GtkWidget>.self)
        g_object_ref(UnsafeMutableRawPointer(firstWidget))
        let panedPtr = OpaquePointer(splitPaned)
        gtk_paned_set_start_child(panedPtr, nil)
        gtk_paned_set_end_child(panedPtr, nil)

        // Remove the GtkPaned from content box
        let contentBoxPtr = unsafeBitCast(contentBox, to: UnsafeMutablePointer<GtkBox>.self)
        gtk_box_remove(contentBoxPtr, splitPaned)

        // Add the first pane's GtkGLArea back to the GtkStack
        let name = "ws-\(ws.id)"
        name.withCString { cName in gtk_stack_add_named(st, firstWidget, cName) }
        g_object_unref(UnsafeMutableRawPointer(firstWidget))

        // Update workspace widget refs (split state already cleared above)
        workspaces[activeIndex].contentWidget = firstWidget
        workspaces[activeIndex].glArea = firstGlArea

        // Show the GtkStack and reinit renderer for the reparented GL area
        let stackWidget = unsafeBitCast(st, to: UnsafeMutablePointer<GtkWidget>.self)
        gtk_widget_set_visible(stackWidget, 1)
        globalGLArea = firstGlArea
        showActiveInStack()

        // Deferred reinit after GTK finishes the reparent layout
        g_timeout_add(100, { _ -> gboolean in
            workspaceManager.splitTransitionInProgress = false
            guard let ws = workspaceManager.activeWorkspace,
                  let surface = ws.surface,
                  let glArea = ws.glArea,
                  let gApp = getGhosttyApp() else { return 0 }
            let widget = unsafeBitCast(glArea, to: UnsafeMutablePointer<GtkWidget>.self)
            gtk_gl_area_make_current(glArea)
            _ = gApp.fn_surface_reinit_renderer?(surface)
            let w = gtk_widget_get_width(widget)
            let h = gtk_widget_get_height(widget)
            if w > 0 && h > 0 {
                let scale = Double(gtk_widget_get_scale_factor(widget))
                gApp.fn_surface_set_content_scale?(surface, scale, scale)
                gApp.fn_surface_set_size?(surface, UInt32(w), UInt32(h))
            }
            gApp.fn_surface_set_focus?(surface, true)
            gApp.fn_surface_refresh?(surface)
            gtk_gl_area_queue_render(glArea)
            _ = gtk_widget_grab_focus(widget)
            // Second focus attempt after another frame
            g_timeout_add(100, { _ -> gboolean in
                if let ws = workspaceManager.activeWorkspace,
                   let surface = ws.surface,
                   let glArea = ws.glArea,
                   let gApp = getGhosttyApp() {
                    gApp.fn_surface_set_focus?(surface, true)
                    let w = unsafeBitCast(glArea, to: UnsafeMutablePointer<GtkWidget>.self)
                    _ = gtk_widget_grab_focus(w)
                }
                return 0
            }, nil)
            return 0
        }, nil)

        cmuxLog("[split] Closed split, first pane preserved")
    }

    /// Close the focused pane within a split, collapsing the split
    func closeFocusedPane() {
        guard activeIndex >= 0, activeIndex < workspaces.count else { return }
        guard workspaces[activeIndex].rootPane != nil else { return }
        guard let container = contentContainer else { return }
        guard let gApp = getGhosttyApp() else { return }

        let ws = workspaces[activeIndex]

        // Remove old split from stack
        if let oldWidget = ws.contentWidget {
            gtk_box_remove(container, oldWidget)
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

        if let st = stack, let widget = removed.contentWidget {
            gtk_stack_remove(st, widget)
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

/// Pending resize — applied after resize stops for 200ms
var pendingResizeW: Int32 = 0
var pendingResizeH: Int32 = 0
var lastResizeTime: UInt64 = 0

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
