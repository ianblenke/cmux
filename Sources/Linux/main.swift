// cmux Linux entry point
// REQ-XP-010: SPM builds on Linux
// REQ-XP-020: GTK4 application framework

import Foundation
import CGtk4

// MARK: - GTK4 Application

/// Minimal GTK4 application entry point for cmux on Linux.
/// Launches a single window with a sidebar and placeholder terminal area.

func activateApp(_ app: OpaquePointer?, userData: gpointer?) {
    guard let app = app else { return }

    let appWidget = unsafeBitCast(app, to: UnsafeMutablePointer<GtkApplication>.self)

    // Create main window
    guard let window = gtk_application_window_new(appWidget) else { return }
    let win = OpaquePointer(window)
    gtk_window_set_title(unsafeBitCast(win, to: UnsafeMutablePointer<GtkWindow>.self), "cmux")
    gtk_window_set_default_size(unsafeBitCast(win, to: UnsafeMutablePointer<GtkWindow>.self), 900, 600)

    // Horizontal box: sidebar + content
    guard let hbox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0) else { return }

    gtk_window_set_child(unsafeBitCast(win, to: UnsafeMutablePointer<GtkWindow>.self), hbox)

    // Sidebar placeholder
    guard let sidebar = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4) else { return }
    gtk_widget_set_size_request(sidebar, 220, -1)

    let sidebarTitle = gtk_label_new("Workspaces")
    gtk_box_append(unsafeBitCast(sidebar, to: UnsafeMutablePointer<GtkBox>.self), sidebarTitle)

    let ws1 = gtk_label_new("  1: ~/project")
    gtk_box_append(unsafeBitCast(sidebar, to: UnsafeMutablePointer<GtkBox>.self), ws1)

    gtk_box_append(unsafeBitCast(hbox, to: UnsafeMutablePointer<GtkBox>.self), sidebar)

    // Separator
    let sep = gtk_separator_new(GTK_ORIENTATION_VERTICAL)
    gtk_box_append(unsafeBitCast(hbox, to: UnsafeMutablePointer<GtkBox>.self), sep)

    // Content area (placeholder for terminal)
    guard let content = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0) else { return }
    gtk_widget_set_hexpand(content, 1)
    gtk_widget_set_vexpand(content, 1)

    let label = gtk_label_new("cmux for Linux\n\nPlatform Abstraction Layer: ready\nlibghostty: built\nGTK4: connected\n\nTerminal surface integration next.")
    gtk_widget_set_halign(label, GTK_ALIGN_CENTER)
    gtk_widget_set_valign(label, GTK_ALIGN_CENTER)
    gtk_box_append(unsafeBitCast(content, to: UnsafeMutablePointer<GtkBox>.self), label)

    gtk_box_append(unsafeBitCast(hbox, to: UnsafeMutablePointer<GtkBox>.self), content)

    // Show window
    gtk_window_present(unsafeBitCast(win, to: UnsafeMutablePointer<GtkWindow>.self))
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
