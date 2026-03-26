// cmux Linux entry point
// REQ-XP-010: SPM builds on Linux
// REQ-XP-020: GTK4 application framework

import Foundation
import CGtk4

// MARK: - GTK4 Application

func activateApp(_ app: OpaquePointer?, userData: gpointer?) {
    guard let app = app else { return }

    let appWidget = unsafeBitCast(app, to: UnsafeMutablePointer<GtkApplication>.self)

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

    // Terminal placeholder — libghostty integration pending
    // The embedded API's Zig globals crash on Linux (objc runtime dep).
    // Next step: make embedded.zig's objc import conditional for Linux.
    let label = gtk_label_new(
        "cmux for Linux\n\n" +
        "PAL: ready\n" +
        "Core: ready\n" +
        "GTK4: connected\n" +
        "libghostty: built (linking disabled)\n\n" +
        "Terminal rendering blocked on:\n" +
        "  embedded.zig objc import must be\n" +
        "  conditional for Linux platform"
    )
    gtk_widget_set_halign(label, GTK_ALIGN_CENTER)
    gtk_widget_set_valign(label, GTK_ALIGN_CENTER)
    gtk_box_append(contentBox, label)

    gtk_box_append(hboxPtr, content)

    // Show window
    gtk_window_present(win)
    print("[cmux] Window presented")
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
