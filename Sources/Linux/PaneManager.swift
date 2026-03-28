// Pane Manager — manages split panes within a workspace
// REQ-SP-001: Split pane creation
// REQ-SP-002: Split orientation

import Foundation
import CGtk4

/// A pane is either a terminal leaf or a split node
indirect enum PaneNode {
    case leaf(PaneLeaf)
    case split(PaneSplit)
}

/// A terminal pane with its own GtkGLArea and ghostty surface
class PaneLeaf {
    let id: Int
    var surface: UnsafeMutableRawPointer?  // ghostty_surface_t
    var glArea: UnsafeMutablePointer<GtkGLArea>?
    var widget: UnsafeMutablePointer<GtkWidget>?  // The GL area as widget
    var initialWorkingDirectory: String?

    init(id: Int, workingDirectory: String? = nil) {
        self.id = id
        self.initialWorkingDirectory = workingDirectory
    }
}

/// A split containing two child panes
class PaneSplit {
    var orientation: SplitOrientation
    var first: PaneNode
    var second: PaneNode
    var paned: OpaquePointer?  // GtkPaned*

    enum SplitOrientation {
        case horizontal  // side by side
        case vertical    // top and bottom
    }

    init(orientation: SplitOrientation, first: PaneNode, second: PaneNode) {
        self.orientation = orientation
        self.first = first
        self.second = second
    }
}

/// Global pane ID counter
private var nextPaneId = 1

/// Create a new terminal pane with GtkGLArea and ghostty surface
func createTerminalPane(ghosttyApp: GhosttyApp, workingDirectory: String? = nil) -> PaneLeaf? {
    let pane = PaneLeaf(id: nextPaneId, workingDirectory: workingDirectory)
    nextPaneId += 1

    // Create GtkGLArea
    guard let glArea = gtk_gl_area_new() else { return nil }
    gtk_widget_set_hexpand(glArea, 1)
    gtk_widget_set_vexpand(glArea, 1)
    gtk_widget_set_focusable(glArea, 1)
    gtk_widget_set_can_focus(glArea, 1)

    let glAreaPtr = unsafeBitCast(glArea, to: UnsafeMutablePointer<GtkGLArea>.self)
    gtk_gl_area_set_auto_render(glAreaPtr, 1)

    pane.glArea = glAreaPtr
    pane.widget = glArea
    // Store CWD for the realize callback
    if let wd = workingDirectory {
        paneManager.setCwd(glArea: glAreaPtr, cwd: wd)
    }

    // Render callback — draws this pane's surface
    let renderCb: @convention(c) (UnsafeMutablePointer<GtkGLArea>?, OpaquePointer?, gpointer?) -> gboolean = { glArea, ctx, userData in
        if let activeSurface = paneManager.surfaceForGLArea(glArea) {
            getGhosttyApp()?.drawSurface(activeSurface)
        }
        return 1
    }
    g_signal_connect_data(glArea, "render",
        unsafeBitCast(renderCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

    // Realize callback — defer surface creation to idle so the GL context
    // is fully initialized, even when nested inside containers within GtkStack.
    let realizeCb: @convention(c) (UnsafeMutablePointer<GtkWidget>?, gpointer?) -> Void = { widget, _ in
        guard let widget = widget else { return }
        g_object_ref(UnsafeMutableRawPointer(widget))
        g_idle_add({ userData -> gboolean in
            guard let userData = userData else { return 0 }
            let widget = userData.assumingMemoryBound(to: GtkWidget.self)
            defer { g_object_unref(userData) }

            guard let gApp = getGhosttyApp() else { return 0 }
            let glPtr = unsafeBitCast(widget, to: UnsafeMutablePointer<GtkGLArea>.self)

            gtk_gl_area_make_current(glPtr)
            if let err = gtk_gl_area_get_error(glPtr) {
                cmuxLog("[pane] GL error during realize: \(String(cString: err.pointee.message))")
                return 0
            }

            let cwd = paneManager.getCwd(glArea: glPtr)
            if gApp.createSurface(glArea: glPtr, widget: widget, workingDirectory: cwd) {
                let surface = gApp.surface!
                paneManager.registerSurface(glArea: glPtr, surface: surface)
                let w = gtk_widget_get_width(widget)
                let h = gtk_widget_get_height(widget)
                let scale = Double(gtk_widget_get_scale_factor(widget))
                gApp.fn_surface_set_content_scale?(surface, scale, scale)
                if w > 0 && h > 0 {
                    gApp.fn_surface_set_size?(surface, UInt32(w), UInt32(h))
                }
                gApp.fn_surface_set_focus?(surface, true)
                _ = gtk_widget_grab_focus(widget)
                gApp.fn_surface_refresh?(surface)
                gtk_gl_area_queue_render(glPtr)
                cmuxLog("[pane] Surface created for pane, size \(w)x\(h)")

                // If size is 0, schedule a delayed size application —
                // the widget hasn't been size-allocated yet.
                if w == 0 || h == 0 {
                    let glRaw = UnsafeMutableRawPointer(glPtr)
                    g_object_ref(glRaw)
                    g_timeout_add(100, { userData -> gboolean in
                        guard let userData = userData else { return 0 }
                        let gl = userData.assumingMemoryBound(to: GtkGLArea.self)
                        defer { g_object_unref(userData) }
                        let w2 = unsafeBitCast(gl, to: UnsafeMutablePointer<GtkWidget>.self)
                        let pw = gtk_widget_get_width(w2)
                        let ph = gtk_widget_get_height(w2)
                        if pw > 0 && ph > 0, let surface = paneManager.surfaceForGLArea(gl),
                           let gApp = getGhosttyApp() {
                            let scale = Double(gtk_widget_get_scale_factor(w2))
                            gApp.fn_surface_set_content_scale?(surface, scale, scale)
                            gApp.fn_surface_set_size?(surface, UInt32(pw), UInt32(ph))
                            gApp.fn_surface_refresh?(surface)
                            gtk_gl_area_queue_render(gl)
                            cmuxLog("[pane] Deferred size applied: \(pw)x\(ph)")
                        }
                        return 0
                    }, glRaw)
                }
            } else {
                cmuxLog("[pane] FAILED to create surface during deferred realize")
            }
            return 0
        }, UnsafeMutableRawPointer(widget))
    }
    g_signal_connect_data(glArea, "realize",
        unsafeBitCast(realizeCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

    // Resize callback
    let resizeCb: @convention(c) (UnsafeMutablePointer<GtkGLArea>?, Int32, Int32, gpointer?) -> Void = { glArea, w, h, _ in
        if let surface = paneManager.surfaceForGLArea(glArea), w > 0, h > 0 {
            getGhosttyApp()?.fn_surface_set_size?(surface, UInt32(w), UInt32(h))
            if let glArea = glArea {
                let widget = unsafeBitCast(glArea, to: UnsafeMutablePointer<GtkWidget>.self)
                let scale = Double(gtk_widget_get_scale_factor(widget))
                getGhosttyApp()?.fn_surface_set_content_scale?(surface, scale, scale)
            }
        }
    }
    g_signal_connect_data(glArea, "resize",
        unsafeBitCast(resizeCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

    // Ensure the widget is visible (needed for realize to fire in containers)
    gtk_widget_set_visible(glArea, 1)

    return pane
}

/// Build GTK widget tree from a pane node
func buildPaneWidget(_ node: PaneNode) -> UnsafeMutablePointer<GtkWidget>? {
    switch node {
    case .leaf(let leaf):
        return leaf.widget
    case .split(let split):
        let orientation: GtkOrientation = split.orientation == .horizontal
            ? GTK_ORIENTATION_HORIZONTAL
            : GTK_ORIENTATION_VERTICAL
        guard let paned = gtk_paned_new(orientation) else { return nil }
        split.paned = OpaquePointer(paned)

        if let first = buildPaneWidget(split.first) {
            gtk_paned_set_start_child(OpaquePointer(paned), first)
            gtk_paned_set_resize_start_child(OpaquePointer(paned), 1)
        }
        if let second = buildPaneWidget(split.second) {
            gtk_paned_set_end_child(OpaquePointer(paned), second)
            gtk_paned_set_resize_end_child(OpaquePointer(paned), 1)
        }
        return paned
    }
}

/// Manages the GL area → surface mapping
class PaneGlobalManager {
    /// Map from GtkGLArea pointer to ghostty surface pointer
    private var surfaceMap: [UnsafeMutableRawPointer: UnsafeMutableRawPointer] = [:]
    /// Map from GtkGLArea pointer to initial working directory
    var cwdMap: [UnsafeMutableRawPointer: String] = [:]

    func registerSurface(glArea: UnsafeMutablePointer<GtkGLArea>, surface: UnsafeMutableRawPointer) {
        surfaceMap[UnsafeMutableRawPointer(glArea)] = surface
    }

    func surfaceForGLArea(_ glArea: UnsafeMutablePointer<GtkGLArea>?) -> UnsafeMutableRawPointer? {
        guard let glArea = glArea else { return nil }
        return surfaceMap[UnsafeMutableRawPointer(glArea)]
    }

    func removeSurface(glArea: UnsafeMutablePointer<GtkGLArea>) {
        surfaceMap.removeValue(forKey: UnsafeMutableRawPointer(glArea))
        cwdMap.removeValue(forKey: UnsafeMutableRawPointer(glArea))
    }

    func setCwd(glArea: UnsafeMutablePointer<GtkGLArea>, cwd: String) {
        cwdMap[UnsafeMutableRawPointer(glArea)] = cwd
    }

    func getCwd(glArea: UnsafeMutablePointer<GtkGLArea>?) -> String? {
        guard let glArea = glArea else { return nil }
        return cwdMap[UnsafeMutableRawPointer(glArea)]
    }

    /// Find the focused GL area by checking GTK focus state
    func focusedGLArea() -> UnsafeMutablePointer<GtkGLArea>? {
        for key in surfaceMap.keys {
            let widget = unsafeBitCast(key, to: UnsafeMutablePointer<GtkWidget>.self)
            if gtk_widget_has_focus(widget) != 0 {
                return unsafeBitCast(key, to: UnsafeMutablePointer<GtkGLArea>.self)
            }
        }
        return nil
    }

    /// Get all registered GL areas
    var allGLAreas: [UnsafeMutableRawPointer] {
        Array(surfaceMap.keys)
    }
}

var paneManager = PaneGlobalManager()

/// Safe accessor for ghosttyApp from C callbacks
func getGhosttyApp() -> GhosttyApp? {
    return ghosttyApp
}
