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

    init(id: Int) {
        self.id = id
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
func createTerminalPane(ghosttyApp: GhosttyApp) -> PaneLeaf? {
    let pane = PaneLeaf(id: nextPaneId)
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

    // Render callback — draws this pane's surface
    let renderCb: @convention(c) (UnsafeMutablePointer<GtkGLArea>?, OpaquePointer?, gpointer?) -> gboolean = { glArea, ctx, userData in
        if let activeSurface = paneManager.surfaceForGLArea(glArea) {
            getGhosttyApp()?.drawSurface(activeSurface)
        }
        return 1
    }
    g_signal_connect_data(glArea, "render",
        unsafeBitCast(renderCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

    // Realize callback — create ghostty surface when GL is ready
    let realizeCb: @convention(c) (UnsafeMutablePointer<GtkWidget>?, gpointer?) -> Void = { widget, _ in
        guard let widget = widget, getGhosttyApp() != nil else { return }
        let gApp = getGhosttyApp()!
        let glPtr = unsafeBitCast(widget, to: UnsafeMutablePointer<GtkGLArea>.self)
        gtk_gl_area_make_current(glPtr)

        if gApp.createSurface(glArea: glPtr, widget: widget) {
            paneManager.registerSurface(glArea: glPtr, surface: gApp.surface!)
            let w = gtk_widget_get_width(widget)
            let h = gtk_widget_get_height(widget)
            if w > 0 && h > 0 {
                gApp.setSize(UInt32(w), UInt32(h))
            }
            gApp.setFocus(true)
            let scale = Double(gtk_widget_get_scale_factor(widget))
            gApp.setContentScale(scale, scale)
            _ = gtk_widget_grab_focus(widget)
            cmuxLog("[pane] Surface created for pane, size \(w)x\(h)")
        }
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

    func registerSurface(glArea: UnsafeMutablePointer<GtkGLArea>, surface: UnsafeMutableRawPointer) {
        surfaceMap[UnsafeMutableRawPointer(glArea)] = surface
    }

    func surfaceForGLArea(_ glArea: UnsafeMutablePointer<GtkGLArea>?) -> UnsafeMutableRawPointer? {
        guard let glArea = glArea else { return nil }
        return surfaceMap[UnsafeMutableRawPointer(glArea)]
    }

    func removeSurface(glArea: UnsafeMutablePointer<GtkGLArea>) {
        surfaceMap.removeValue(forKey: UnsafeMutableRawPointer(glArea))
    }
}

var paneManager = PaneGlobalManager()

/// Safe accessor for ghosttyApp from C callbacks
func getGhosttyApp() -> GhosttyApp? {
    return ghosttyApp
}
