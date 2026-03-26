// cmux Linux entry point
// REQ-XP-010: SPM builds on Linux
// REQ-XP-020: GTK4 application framework
// REQ-TC-001: Ghostty-based terminal emulation

import Foundation
import CGtk4

// MARK: - Global State

var ghosttyApp: GhosttyApp?

// MARK: - GTK4 Application

func activateApp(_ appPtr: OpaquePointer?, userData: gpointer?) {
    guard let appPtr = appPtr else { return }
    let appWidget = unsafeBitCast(appPtr, to: UnsafeMutablePointer<GtkApplication>.self)

    // Initialize Ghostty
    cmuxLog("[cmux] Initializing ghostty...")
    ghosttyApp = GhosttyApp()
    cmuxLog("[cmux] Ghostty: \(ghosttyApp != nil ? "ready" : "FAILED")")

    // Window
    guard let window = gtk_application_window_new(appWidget) else { return }
    let win = unsafeBitCast(OpaquePointer(window), to: UnsafeMutablePointer<GtkWindow>.self)
    gtk_window_set_title(win, "cmux")
    gtk_window_set_default_size(win, 900, 600)

    guard let hbox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0) else { return }
    gtk_window_set_child(win, hbox)
    let hboxPtr = unsafeBitCast(hbox, to: UnsafeMutablePointer<GtkBox>.self)

    // Sidebar
    guard let sidebar = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4) else { return }
    gtk_widget_set_size_request(sidebar, 220, -1)
    let sidebarBox = unsafeBitCast(sidebar, to: UnsafeMutablePointer<GtkBox>.self)
    gtk_box_append(sidebarBox, gtk_label_new("Workspaces"))
    gtk_box_append(sidebarBox, gtk_label_new("  1: ~/project"))
    gtk_box_append(hboxPtr, sidebar)
    gtk_box_append(hboxPtr, gtk_separator_new(GTK_ORIENTATION_VERTICAL))

    // Content
    guard let content = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0) else { return }
    gtk_widget_set_hexpand(content, 1)
    gtk_widget_set_vexpand(content, 1)
    let contentBox = unsafeBitCast(content, to: UnsafeMutablePointer<GtkBox>.self)

    if let gApp = ghosttyApp {
        // GtkGLArea for terminal rendering
        guard let glArea = gtk_gl_area_new() else { return }
        gtk_widget_set_hexpand(glArea, 1)
        gtk_widget_set_vexpand(glArea, 1)
        let glAreaPtr = unsafeBitCast(glArea, to: UnsafeMutablePointer<GtkGLArea>.self)
        gtk_gl_area_set_auto_render(glAreaPtr, 1)

        // Render callback
        let renderCb: @convention(c) (UnsafeMutablePointer<GtkGLArea>?, OpaquePointer?, gpointer?) -> gboolean = { glArea, ctx, _ in
            // Draw the ghostty surface — GL context is current here
            ghosttyApp?.draw()
            return 1
        }
        g_signal_connect_data(glArea, "render",
            unsafeBitCast(renderCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

        // Realize callback — create surface when GL is ready
        let realizeCb: @convention(c) (UnsafeMutablePointer<GtkWidget>?, gpointer?) -> Void = { widget, _ in
            guard let widget = widget, let gApp = ghosttyApp else { return }
            let glPtr = unsafeBitCast(widget, to: UnsafeMutablePointer<GtkGLArea>.self)
            gtk_gl_area_make_current(glPtr)

            // Make GL context current BEFORE creating surface —
            // the OpenGL renderer needs it during initialization
            gtk_gl_area_make_current(glPtr)
            cmuxLog("[cmux] GL context current, creating surface...")
            let ok = gApp.createSurface(glArea: glPtr, widget: widget)
            if ok {
                let w = gtk_widget_get_width(widget)
                let h = gtk_widget_get_height(widget)
                if w > 0 && h > 0 {
                    gApp.setSize(UInt32(w), UInt32(h))
                }
                gApp.setFocus(true)
                let scale = Double(gtk_widget_get_scale_factor(widget))
                gApp.setContentScale(scale, scale)
                cmuxLog("[cmux] Surface ready: \(w)x\(h) @\(scale)x")
            }
        }
        g_signal_connect_data(glArea, "realize",
            unsafeBitCast(realizeCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

        // Resize callback
        let resizeCb: @convention(c) (UnsafeMutablePointer<GtkGLArea>?, Int32, Int32, gpointer?) -> Void = { _, w, h, _ in
            if w > 0 && h > 0 { ghosttyApp?.setSize(UInt32(w), UInt32(h)) }
        }
        g_signal_connect_data(glArea, "resize",
            unsafeBitCast(resizeCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

        gtk_box_append(contentBox, glArea)

        // Tick timer — process ghostty events on main thread
        g_timeout_add(16, { _ -> gboolean in ghosttyApp?.tick(); return 1 }, nil)
    } else {
        let label = gtk_label_new("cmux — Ghostty failed to load\nRunning in stub mode")
        gtk_widget_set_halign(label, GTK_ALIGN_CENTER)
        gtk_widget_set_valign(label, GTK_ALIGN_CENTER)
        gtk_box_append(contentBox, label)
    }

    gtk_box_append(hboxPtr, content)
    gtk_window_present(win)
    cmuxLog("[cmux] Window presented")
}

// MARK: - Main

// Log to file since stderr gets lost with GTK
let logFile = fopen("/tmp/cmux-linux.log", "w")
func cmuxLog(_ msg: String) {
    if let f = logFile {
        fputs("\(msg)\n", f)
        fflush(f)
    }
}

// Force GDK to use desktop OpenGL (not GLES/Vulkan) — same as Ghostty GTK apprt.
setenv("GDK_DISABLE", "gles-api,vulkan", 1)
cmuxLog("cmux starting...")

guard let app = gtk_application_new("com.cmux.linux", G_APPLICATION_NON_UNIQUE) else {
    fatalError("Failed to create GtkApplication")
}
let callback: @convention(c) (OpaquePointer?, gpointer?) -> Void = activateApp
g_signal_connect_data(app, "activate",
    unsafeBitCast(callback, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

let gapp = unsafeBitCast(app, to: UnsafeMutablePointer<GApplication>.self)
let status = g_application_run(gapp, CommandLine.argc, CommandLine.unsafeArgv)
g_object_unref(app)
exit(status)
