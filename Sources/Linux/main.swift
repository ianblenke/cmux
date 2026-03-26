// cmux Linux entry point
// REQ-XP-010: SPM builds on Linux
// REQ-XP-020: GTK4 application framework
// REQ-TC-001: Ghostty-based terminal emulation

import Foundation
import CGtk4
import CGhostty

// MARK: - Global State

/// Global ghostty app instance (initialized in activate)
var ghosttyApp: GhosttyApp?
var ghosttySurface: ghostty_surface_t?

// MARK: - GTK4 Application

func activateApp(_ app: OpaquePointer?, userData: gpointer?) {
    guard let app = app else { return }

    let appWidget = unsafeBitCast(app, to: UnsafeMutablePointer<GtkApplication>.self)

    // Initialize Ghostty
    ghosttyApp = GhosttyApp()
    if ghosttyApp == nil {
        print("[cmux] WARNING: Ghostty initialization failed, running in stub mode")
    }

    // Create main window
    guard let window = gtk_application_window_new(appWidget) else { return }
    let win = unsafeBitCast(OpaquePointer(window), to: UnsafeMutablePointer<GtkWindow>.self)
    gtk_window_set_title(win, "cmux")
    gtk_window_set_default_size(win, 900, 600)

    // Horizontal box: sidebar + content
    guard let hbox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0) else { return }
    gtk_window_set_child(win, hbox)

    let hboxPtr = unsafeBitCast(hbox, to: UnsafeMutablePointer<GtkBox>.self)

    // -- Sidebar --
    guard let sidebar = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4) else { return }
    gtk_widget_set_size_request(sidebar, 220, -1)
    let sidebarBox = unsafeBitCast(sidebar, to: UnsafeMutablePointer<GtkBox>.self)

    let sidebarTitle = gtk_label_new("Workspaces")
    gtk_box_append(sidebarBox, sidebarTitle)

    let ws1 = gtk_label_new("  1: ~/project")
    gtk_box_append(sidebarBox, ws1)

    gtk_box_append(hboxPtr, sidebar)

    // Separator
    let sep = gtk_separator_new(GTK_ORIENTATION_VERTICAL)
    gtk_box_append(hboxPtr, sep)

    // -- Content area --
    guard let content = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0) else { return }
    gtk_widget_set_hexpand(content, 1)
    gtk_widget_set_vexpand(content, 1)
    let contentBox = unsafeBitCast(content, to: UnsafeMutablePointer<GtkBox>.self)

    if ghosttyApp != nil {
        // Create a GtkGLArea for terminal rendering
        guard let glArea = gtk_gl_area_new() else {
            print("[cmux] Failed to create GtkGLArea")
            return
        }
        gtk_widget_set_hexpand(glArea, 1)
        gtk_widget_set_vexpand(glArea, 1)
        gtk_gl_area_set_auto_render(
            unsafeBitCast(glArea, to: UnsafeMutablePointer<GtkGLArea>.self), 1)

        // Connect GL render signal
        let renderCallback: @convention(c) (
            UnsafeMutablePointer<GtkGLArea>?, OpaquePointer?, gpointer?
        ) -> gboolean = { glArea, context, userData in
            if let surface = ghosttySurface {
                ghostty_surface_draw(surface)
            }
            return 1 // TRUE = we handled rendering
        }
        g_signal_connect_data(
            glArea,
            "render",
            unsafeBitCast(renderCallback, to: GCallback.self),
            nil, nil, GConnectFlags(rawValue: 0)
        )

        // Connect realize signal to create ghostty surface
        let realizeCallback: @convention(c) (
            UnsafeMutablePointer<GtkWidget>?, gpointer?
        ) -> Void = { widget, userData in
            guard let widget = widget, let ghosttyApp = ghosttyApp else { return }
            let glAreaPtr = unsafeBitCast(widget, to: UnsafeMutablePointer<GtkGLArea>.self)
            gtk_gl_area_make_current(glAreaPtr)

            ghosttySurface = ghosttyApp.createSurface(
                glArea: glAreaPtr,
                widget: widget
            )

            if let surface = ghosttySurface {
                // Set initial size
                let width = gtk_widget_get_width(widget)
                let height = gtk_widget_get_height(widget)
                if width > 0 && height > 0 {
                    ghostty_surface_set_size(surface, UInt32(width), UInt32(height))
                }
                ghostty_surface_set_focus(surface, true)
            }
        }
        g_signal_connect_data(
            glArea,
            "realize",
            unsafeBitCast(realizeCallback, to: GCallback.self),
            nil, nil, GConnectFlags(rawValue: 0)
        )

        // Connect resize signal
        let resizeCallback: @convention(c) (
            UnsafeMutablePointer<GtkGLArea>?, Int32, Int32, gpointer?
        ) -> Void = { glArea, width, height, userData in
            if let surface = ghosttySurface, width > 0, height > 0 {
                ghostty_surface_set_size(surface, UInt32(width), UInt32(height))
            }
        }
        g_signal_connect_data(
            glArea,
            "resize",
            unsafeBitCast(resizeCallback, to: GCallback.self),
            nil, nil, GConnectFlags(rawValue: 0)
        )

        gtk_box_append(contentBox, glArea)

        // Set up a tick callback for ghostty event processing
        let tickCallback: @convention(c) (gpointer?) -> gboolean = { _ in
            ghosttyApp?.tick()
            return 1 // G_SOURCE_CONTINUE
        }
        g_timeout_add(16, tickCallback, nil)  // ~60fps tick rate

        print("[cmux] Terminal surface setup complete")
    } else {
        // Stub mode — no ghostty
        let label = gtk_label_new(
            "cmux for Linux\n\n" +
            "Ghostty initialization failed.\n" +
            "Check that libghostty is built:\n" +
            "  cd ghostty && zig build -Dapp-runtime=none"
        )
        gtk_widget_set_halign(label, GTK_ALIGN_CENTER)
        gtk_widget_set_valign(label, GTK_ALIGN_CENTER)
        gtk_box_append(contentBox, label)
    }

    gtk_box_append(hboxPtr, content)

    // Keyboard event controller — TODO: wire up after surface creation is stable
    // GTK event controllers require careful type casting from Swift.
    // Key input will be routed through ghostty_surface_key() once the
    // surface rendering pipeline is working.

    // Show window
    gtk_window_present(win)
}

// MARK: - Main

guard let app = gtk_application_new("com.cmux.linux", G_APPLICATION_DEFAULT_FLAGS) else {
    fatalError("Failed to create GtkApplication")
}

let callback: @convention(c) (OpaquePointer?, gpointer?) -> Void = activateApp
g_signal_connect_data(
    app,
    "activate",
    unsafeBitCast(callback, to: GCallback.self),
    nil, nil, GConnectFlags(rawValue: 0)
)

let gapp = unsafeBitCast(app, to: UnsafeMutablePointer<GApplication>.self)
let status = g_application_run(gapp, CommandLine.argc, CommandLine.unsafeArgv)
g_object_unref(app)
exit(status)
