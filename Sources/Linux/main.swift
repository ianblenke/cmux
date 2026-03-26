// cmux Linux entry point
// REQ-XP-010: SPM builds on Linux
// REQ-XP-020: GTK4 application framework

import Foundation
import CGtk4

// MARK: - Global State

var ghosttyApp: GhosttyApp?

// MARK: - GTK4 Application

func activateApp(_ app: OpaquePointer?, userData: gpointer?) {
    guard let app = app else { return }
    let appWidget = unsafeBitCast(app, to: UnsafeMutablePointer<GtkApplication>.self)

    // Initialize Ghostty via dlopen
    fputs("[cmux] Initializing ghostty...\n", stderr)
    ghosttyApp = GhosttyApp()
    let ghosttyStatus = ghosttyApp != nil ? "ready (init + config OK)" : "FAILED"
    fputs("[cmux] Ghostty: \(ghosttyStatus)\n", stderr)

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
    gtk_box_append(sidebarBox, gtk_label_new("Workspaces"))
    gtk_box_append(sidebarBox, gtk_label_new("  1: ~/project"))
    gtk_box_append(hboxPtr, sidebar)

    gtk_box_append(hboxPtr, gtk_separator_new(GTK_ORIENTATION_VERTICAL))

    // -- Content area --
    guard let content = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0) else { return }
    gtk_widget_set_hexpand(content, 1)
    gtk_widget_set_vexpand(content, 1)
    let contentBox = unsafeBitCast(content, to: UnsafeMutablePointer<GtkBox>.self)

    let statusText = ghosttyApp != nil
        ? "cmux for Linux\n\nGhostty: initialized\nConfig: loaded\n\nTerminal surface: pending app creation"
        : "cmux for Linux\n\nGhostty: failed to load\nRunning in stub mode"

    let label = gtk_label_new(statusText)
    gtk_widget_set_halign(label, GTK_ALIGN_CENTER)
    gtk_widget_set_valign(label, GTK_ALIGN_CENTER)
    gtk_box_append(contentBox, label)

    gtk_box_append(hboxPtr, content)
    gtk_window_present(win)
    fputs("[cmux] Window presented\n", stderr)
}

// MARK: - Main

guard let app = gtk_application_new("com.cmux.linux", G_APPLICATION_DEFAULT_FLAGS) else {
    fatalError("Failed to create GtkApplication")
}

let callback: @convention(c) (OpaquePointer?, gpointer?) -> Void = activateApp
g_signal_connect_data(app, "activate",
    unsafeBitCast(callback, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

let gapp = unsafeBitCast(app, to: UnsafeMutablePointer<GApplication>.self)
let status = g_application_run(gapp, CommandLine.argc, CommandLine.unsafeArgv)
g_object_unref(app)
exit(status)
