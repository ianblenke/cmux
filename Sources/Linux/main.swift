// cmux Linux entry point
// REQ-XP-010: SPM builds on Linux
// REQ-XP-020: GTK4 application framework
// REQ-TC-001: Ghostty-based terminal emulation

import Foundation
import CGtk4
import CGhosttyHelpers

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
    workspaceManager.sidebarBox = sidebarBox
    workspaceManager.sidebarWidget = sidebar
    workspaceManager.window = win
    gtk_box_append(sidebarBox, gtk_label_new("Workspaces"))
    gtk_box_append(hboxPtr, sidebar)
    let sep = gtk_separator_new(GTK_ORIENTATION_VERTICAL)
    workspaceManager.separatorWidget = sep
    gtk_box_append(hboxPtr, sep)

    // Content
    guard let content = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0) else { return }
    gtk_widget_set_hexpand(content, 1)
    gtk_widget_set_vexpand(content, 1)
    let contentBox = unsafeBitCast(content, to: UnsafeMutablePointer<GtkBox>.self)

    workspaceManager.contentBoxWidget = contentBox

    if let gApp = ghosttyApp {
        // GtkGLArea for terminal rendering
        guard let glArea = gtk_gl_area_new() else { return }
        gtk_widget_set_hexpand(glArea, 1)
        gtk_widget_set_vexpand(glArea, 1)
        gtk_widget_set_focusable(glArea, 1)  // Allow GL area to receive keyboard focus
        gtk_widget_set_can_focus(glArea, 1)
        let glAreaPtr = unsafeBitCast(glArea, to: UnsafeMutablePointer<GtkGLArea>.self)
        gtk_gl_area_set_auto_render(glAreaPtr, 1)

        // Render callback — draw the ACTIVE workspace's surface
        let renderCb: @convention(c) (UnsafeMutablePointer<GtkGLArea>?, OpaquePointer?, gpointer?) -> gboolean = { glArea, ctx, _ in
            if let surface = workspaceManager.activeSurface, let gApp = ghosttyApp {
                gApp.drawSurface(surface)
            }
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
            cmuxLog("[cmux] GL context current, creating initial workspace...")
            workspaceManager.glArea = glPtr
            let wsId = workspaceManager.createWorkspace(
                ghosttyApp: gApp, glArea: glPtr, widget: widget,
                command: initialCommand, workingDirectory: initialDirectory,
                title: initialTitle)
            if wsId > 0 {
                let w = gtk_widget_get_width(widget)
                let h = gtk_widget_get_height(widget)
                if w > 0 && h > 0 {
                    gApp.setSize(UInt32(w), UInt32(h))
                }
                gApp.setFocus(true)
                let scale = Double(gtk_widget_get_scale_factor(widget))
                gApp.setContentScale(scale, scale)
                _ = gtk_widget_grab_focus(widget)
                cmuxLog("[cmux] Workspace \(wsId) ready: \(w)x\(h) @\(scale)x")

                // Restore additional workspaces from saved session
                if let saved = LinuxSessionPersistence.load(), saved.workspaces.count > 1 {
                    for i in 1..<saved.workspaces.count {
                        let ws = saved.workspaces[i]
                        let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
                        let fullCwd = ws.cwd.hasPrefix("~")
                            ? home + ws.cwd.dropFirst(1) : ws.cwd
                        _ = workspaceManager.createWorkspace(
                            ghosttyApp: gApp, glArea: glPtr, widget: widget,
                            workingDirectory: fullCwd)
                    }
                    // Switch to the previously active workspace
                    if saved.activeIndex < workspaceManager.workspaces.count {
                        workspaceManager.switchTo(index: saved.activeIndex)
                    }
                    cmuxLog("[cmux] Restored \(saved.workspaces.count) workspaces")
                }
            }
        }
        g_signal_connect_data(glArea, "realize",
            unsafeBitCast(realizeCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

        // Resize callback
        let resizeCb: @convention(c) (UnsafeMutablePointer<GtkGLArea>?, Int32, Int32, gpointer?) -> Void = { glArea, w, h, _ in
            if let gApp = ghosttyApp, w > 0, h > 0 {
                gApp.setSize(UInt32(w), UInt32(h))
                // Update content scale on resize too
                if let glArea = glArea {
                    let widget = unsafeBitCast(glArea, to: UnsafeMutablePointer<GtkWidget>.self)
                    let scale = Double(gtk_widget_get_scale_factor(widget))
                    gApp.setContentScale(scale, scale)
                }
                cmuxLog("[cmux] Resized: \(w)x\(h)")
            }
        }
        g_signal_connect_data(glArea, "resize",
            unsafeBitCast(resizeCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

        gtk_box_append(contentBox, glArea)

        // Tick timer — process ghostty events on main thread
        g_timeout_add(16, { _ -> gboolean in ghosttyApp?.tick(); return 1 }, nil)

        // Autosave session every 30 seconds
        g_timeout_add(30000, { _ -> gboolean in
            LinuxSessionPersistence.save()
            return 1
        }, nil)
    } else {
        let label = gtk_label_new("cmux — Ghostty failed to load\nRunning in stub mode")
        gtk_widget_set_halign(label, GTK_ALIGN_CENTER)
        gtk_widget_set_valign(label, GTK_ALIGN_CENTER)
        gtk_box_append(contentBox, label)
    }

    gtk_box_append(hboxPtr, content)

    // Keyboard input — route to ghostty surface
    if ghosttyApp != nil {
        let keyController = gtk_event_controller_key_new()!

        // Key press
        let keyPressCb: @convention(c) (
            OpaquePointer?, UInt32, UInt32, UInt32, gpointer?
        ) -> gboolean = { _, keyval, hwKeycode, state, _ in
            guard let gApp = ghosttyApp else { return 0 }

            // Map GDK modifier state to ghostty mods
            var mods: Int32 = 0
            if state & UInt32(GDK_SHIFT_MASK.rawValue) != 0 { mods |= 1 }    // GHOSTTY_MODS_SHIFT
            if state & UInt32(GDK_CONTROL_MASK.rawValue) != 0 { mods |= 2 }   // GHOSTTY_MODS_CTRL
            if state & UInt32(GDK_ALT_MASK.rawValue) != 0 { mods |= 4 }       // GHOSTTY_MODS_ALT
            if state & UInt32(GDK_SUPER_MASK.rawValue) != 0 { mods |= 8 }     // GHOSTTY_MODS_SUPER

            // Handle cmux keybindings before sending to ghostty
            let isCtrl = mods & 2 != 0
            let isSuper = mods & 8 != 0
            let isMeta = isCtrl || isSuper  // Use Ctrl or Super for cmux bindings

            let isShift = mods & 1 != 0

            let isAlt = mods & 4 != 0

            // === Ctrl+Shift combos (terminal-safe: Ctrl+Shift doesn't conflict with shell) ===
            if isCtrl && isShift {
                // Ctrl+Shift+C: copy selection
                if keyval == UInt32(GDK_KEY_c) || keyval == UInt32(GDK_KEY_C) {
                    _ = gApp.copySelection()
                    return 1
                }
                // Ctrl+Shift+V: paste
                if keyval == UInt32(GDK_KEY_v) || keyval == UInt32(GDK_KEY_V) {
                    if let surface = workspaceManager.activeSurface {
                        cmux_ghostty_paste_from_clipboard(surface)
                    }
                    return 1
                }
                // Ctrl+Shift+D: split vertical
                if keyval == UInt32(GDK_KEY_d) || keyval == UInt32(GDK_KEY_D) {
                    workspaceManager.splitActivePane(orientation: .vertical)
                    return 1
                }
                // Ctrl+Shift+T: new workspace (alternative to Super+T)
                if keyval == UInt32(GDK_KEY_t) || keyval == UInt32(GDK_KEY_T) {
                    if let gl = workspaceManager.glArea {
                        let w = unsafeBitCast(gl, to: UnsafeMutablePointer<GtkWidget>.self)
                        gtk_gl_area_make_current(gl)
                        _ = workspaceManager.createWorkspace(
                            ghosttyApp: gApp, glArea: gl, widget: w)
                    }
                    return 1
                }
                // Ctrl+Shift+W: close workspace
                if keyval == UInt32(GDK_KEY_w) || keyval == UInt32(GDK_KEY_W) {
                    workspaceManager.closeActive()
                    return 1
                }
            }

            // === Super (Cmd) combos — cmux-specific, never conflicts with shell ===
            if isSuper {
                // Super+D: split horizontal
                if keyval == UInt32(GDK_KEY_d) || keyval == UInt32(GDK_KEY_D) {
                    let orientation: PaneSplit.SplitOrientation = isShift ? .vertical : .horizontal
                    workspaceManager.splitActivePane(orientation: orientation)
                    return 1
                }
                // Super+T: new workspace
                if keyval == UInt32(GDK_KEY_t) || keyval == UInt32(GDK_KEY_T) {
                    if let gl = workspaceManager.glArea {
                        let w = unsafeBitCast(gl, to: UnsafeMutablePointer<GtkWidget>.self)
                        gtk_gl_area_make_current(gl)
                        _ = workspaceManager.createWorkspace(
                            ghosttyApp: gApp, glArea: gl, widget: w)
                    }
                    return 1
                }
                // Super+1-9: switch workspace
                if keyval >= UInt32(GDK_KEY_1) && keyval <= UInt32(GDK_KEY_9) {
                    let idx = Int(keyval - UInt32(GDK_KEY_1))
                    workspaceManager.switchTo(index: idx)
                    return 1
                }
                // Super+]: next workspace
                if keyval == UInt32(GDK_KEY_bracketright) {
                    workspaceManager.next()
                    return 1
                }
                // Super+[: previous workspace
                if keyval == UInt32(GDK_KEY_bracketleft) {
                    workspaceManager.previous()
                    return 1
                }
                // Super+W: close workspace
                if keyval == UInt32(GDK_KEY_w) || keyval == UInt32(GDK_KEY_W) {
                    workspaceManager.closeActive()
                    return 1
                }
                // Super+B: toggle sidebar
                if keyval == UInt32(GDK_KEY_b) || keyval == UInt32(GDK_KEY_B) {
                    workspaceManager.toggleSidebar()
                    return 1
                }
            }

            // === Font size: Ctrl+Plus/Minus/0 ===
            if isCtrl {
                if keyval == UInt32(GDK_KEY_plus) || keyval == UInt32(GDK_KEY_equal) {
                    gApp.bindingAction("increase_font_size:1")
                    return 1
                }
                if keyval == UInt32(GDK_KEY_minus) || keyval == UInt32(GDK_KEY_underscore) {
                    gApp.bindingAction("decrease_font_size:1")
                    return 1
                }
                if keyval == UInt32(GDK_KEY_0) {
                    gApp.bindingAction("reset_font_size")
                    return 1
                }
            }

            // === Alt+arrows: pane focus navigation ===
            if isAlt && isCtrl {
                if keyval == UInt32(GDK_KEY_Left) || keyval == UInt32(GDK_KEY_Right) ||
                   keyval == UInt32(GDK_KEY_Up) || keyval == UInt32(GDK_KEY_Down) {
                    if let win = workspaceManager.window {
                        let winWidget = unsafeBitCast(win, to: UnsafeMutablePointer<GtkWidget>.self)
                        let forward = keyval == UInt32(GDK_KEY_Right) || keyval == UInt32(GDK_KEY_Down)
                        _ = gtk_widget_child_focus(winWidget, forward ? GTK_DIR_TAB_FORWARD : GTK_DIR_TAB_BACKWARD)
                    }
                    return 1
                }
            }

            // Use hardware keycode if valid, otherwise map from keyval
            let evdevKeycode: UInt32
            let mappedKeycode = gdkKeyvalToEvdev(keyval)
            if hwKeycode > 0 && hwKeycode != 9 {
                // GTK provided a real hardware keycode (not Escape/default)
                // But verify: if keyval doesn't match Escape, keycode 9 is wrong
                evdevKeycode = hwKeycode
            } else if mappedKeycode > 0 {
                evdevKeycode = mappedKeycode
            } else {
                evdevKeycode = hwKeycode
            }

            // Convert keyval to UTF-8 text
            let unichar = gdk_keyval_to_unicode(keyval)
            var text: String? = nil
            if unichar > 0, unichar < 0x110000, let scalar = Unicode.Scalar(unichar) {
                text = String(Character(scalar))
            }

            let handled = gApp.sendKey(keycode: evdevKeycode, text: text, mods: mods, action: 1)
            return handled ? 1 : 0
        }
        g_signal_connect_data(UnsafeMutableRawPointer(keyController), "key-pressed",
            unsafeBitCast(keyPressCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

        // Key release
        let keyReleaseCb: @convention(c) (
            OpaquePointer?, UInt32, UInt32, UInt32, gpointer?
        ) -> Void = { _, keyval, hwKeycode, state, _ in
            guard let gApp = ghosttyApp else { return }
            var mods: Int32 = 0
            if state & UInt32(GDK_SHIFT_MASK.rawValue) != 0 { mods |= 1 }
            if state & UInt32(GDK_CONTROL_MASK.rawValue) != 0 { mods |= 2 }
            if state & UInt32(GDK_ALT_MASK.rawValue) != 0 { mods |= 4 }
            if state & UInt32(GDK_SUPER_MASK.rawValue) != 0 { mods |= 8 }
            let evdevKeycode = gdkKeyvalToEvdev(keyval)
            _ = gApp.sendKey(keycode: evdevKeycode > 0 ? evdevKeycode : hwKeycode,
                            text: nil, mods: mods, action: 0)
        }
        g_signal_connect_data(UnsafeMutableRawPointer(keyController), "key-released",
            unsafeBitCast(keyReleaseCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

        // Add controller to the window widget
        let windowWidget = unsafeBitCast(win, to: UnsafeMutablePointer<GtkWidget>.self)
        // gtk_widget_add_controller expects GtkEventController*
        // keyController is already an OpaquePointer from gtk_event_controller_key_new
        withUnsafeMutablePointer(to: &windowWidget.pointee) { wPtr in
            // We need to pass it through — GTK4 takes ownership of the controller
        }
        // Use the C function directly with raw pointer cast
        typealias AddControllerFn = @convention(c) (UnsafeMutablePointer<GtkWidget>?, OpaquePointer?) -> Void
        let addController: AddControllerFn = gtk_widget_add_controller
        addController(windowWidget, keyController)
        cmuxLog("[cmux] Keyboard input connected")

        // Mouse motion
        let motionController = gtk_event_controller_motion_new()!
        let motionCb: @convention(c) (OpaquePointer?, Double, Double, gpointer?) -> Void = { _, x, y, _ in
            ghosttyApp?.mousePos(x: x, y: y, mods: 0)
        }
        g_signal_connect_data(UnsafeMutableRawPointer(motionController), "motion",
            unsafeBitCast(motionCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))
        let motionWidget = unsafeBitCast(win, to: UnsafeMutablePointer<GtkWidget>.self)
        let addMotion: @convention(c) (UnsafeMutablePointer<GtkWidget>?, OpaquePointer?) -> Void = gtk_widget_add_controller
        addMotion(motionWidget, motionController)

        // Mouse click (press/release)
        let clickGesture = gtk_gesture_click_new()!
        gtk_gesture_single_set_button(unsafeBitCast(clickGesture, to: OpaquePointer.self), 0) // 0 = all buttons
        let clickPressCb: @convention(c) (OpaquePointer?, Int32, Double, Double, gpointer?) -> Void = { gesture, nPress, x, y, _ in
            guard let gApp = ghosttyApp else { return }
            // Map GDK button number: 1=left, 2=middle, 3=right → ghostty: 1=left, 3=right, 2=middle
            let gdkButton = gtk_gesture_single_get_current_button(unsafeBitCast(gesture, to: OpaquePointer.self))
            let ghosttyButton: Int32 = switch Int32(gdkButton) {
                case 1: 1   // GHOSTTY_MOUSE_LEFT
                case 2: 3   // GHOSTTY_MOUSE_MIDDLE
                case 3: 2   // GHOSTTY_MOUSE_RIGHT
                default: Int32(gdkButton)
            }
            gApp.mousePos(x: x, y: y, mods: 0)
            _ = gApp.mouseButton(state: 1, button: ghosttyButton, mods: 0)  // press
            // Grab keyboard focus on click
            if let glArea = globalGLArea {
                let w = unsafeBitCast(glArea, to: UnsafeMutablePointer<GtkWidget>.self)
                _ = gtk_widget_grab_focus(w)
            }
        }
        g_signal_connect_data(UnsafeMutableRawPointer(clickGesture), "pressed",
            unsafeBitCast(clickPressCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

        let clickReleaseCb: @convention(c) (OpaquePointer?, Int32, Double, Double, gpointer?) -> Void = { gesture, nPress, x, y, _ in
            guard let gApp = ghosttyApp else { return }
            let gdkButton = gtk_gesture_single_get_current_button(unsafeBitCast(gesture, to: OpaquePointer.self))
            let ghosttyButton: Int32 = switch Int32(gdkButton) {
                case 1: 1; case 2: 3; case 3: 2; default: Int32(gdkButton)
            }
            _ = gApp.mouseButton(state: 0, button: ghosttyButton, mods: 0)  // release
        }
        g_signal_connect_data(UnsafeMutableRawPointer(clickGesture), "released",
            unsafeBitCast(clickReleaseCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

        let clickWidget = unsafeBitCast(win, to: UnsafeMutablePointer<GtkWidget>.self)
        let addClick: @convention(c) (UnsafeMutablePointer<GtkWidget>?, OpaquePointer?) -> Void = gtk_widget_add_controller
        addClick(clickWidget, unsafeBitCast(clickGesture, to: OpaquePointer.self))

        // Mouse scroll
        let scrollController = gtk_event_controller_scroll_new(
            GtkEventControllerScrollFlags(rawValue:
                GTK_EVENT_CONTROLLER_SCROLL_VERTICAL.rawValue |
                GTK_EVENT_CONTROLLER_SCROLL_HORIZONTAL.rawValue))!
        let scrollCb: @convention(c) (OpaquePointer?, Double, Double, gpointer?) -> gboolean = { _, dx, dy, _ in
            ghosttyApp?.mouseScroll(dx: dx, dy: dy, mods: 0)
            return 1
        }
        g_signal_connect_data(UnsafeMutableRawPointer(scrollController), "scroll",
            unsafeBitCast(scrollCb, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))
        let scrollWidget = unsafeBitCast(win, to: UnsafeMutablePointer<GtkWidget>.self)
        let addScroll: @convention(c) (UnsafeMutablePointer<GtkWidget>?, OpaquePointer?) -> Void = gtk_widget_add_controller
        addScroll(scrollWidget, scrollController)

        cmuxLog("[cmux] Mouse input connected")
    }

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

// Parse cmux-specific args and strip them before GTK sees them
var initialCommand: String? = nil
var initialDirectory: String? = nil
var initialTitle: String? = nil
var filteredArgs: [String] = [CommandLine.arguments[0]]  // Keep program name

do {
    var args = Array(CommandLine.arguments.dropFirst())
    var i = 0
    while i < args.count {
        switch args[i] {
        case "-e", "--command":
            if i + 1 < args.count { initialCommand = args[i + 1]; i += 2 } else { i += 1 }
        case "-d", "--directory":
            if i + 1 < args.count { initialDirectory = args[i + 1]; i += 2 } else { i += 1 }
        case "--title":
            if i + 1 < args.count { initialTitle = args[i + 1]; i += 2 } else { i += 1 }
        case "--help", "-h":
            print("""
            cmux-linux — Ghostty-based terminal with workspaces

            Usage: cmux-linux [OPTIONS]

            Options:
              -e, --command CMD    Run CMD in the initial terminal
              -d, --directory DIR  Set initial working directory
              --title TITLE        Set initial workspace title
              -h, --help           Show this help

            Keyboard Shortcuts:
              Super+T / Ctrl+Shift+T    New workspace
              Super+W / Ctrl+Shift+W    Close workspace
              Super+1-9                 Switch workspace
              Super+]/[                 Next/prev workspace
              Super+D                   Split horizontal
              Super+Shift+D / Ctrl+Shift+D  Split vertical
              Ctrl+Shift+C              Copy selection
              Ctrl+Shift+V              Paste clipboard
              Ctrl+Alt+arrows           Focus pane

            Socket API:
              SOCK=$(cat /tmp/cmux-socket-path)
              echo '{"method":"workspace.list"}' | socat - UNIX-CONNECT:$SOCK
            """)
            exit(0)
        default:
            filteredArgs.append(args[i])
            i += 1
        }
    }
}

// Force GDK to use desktop OpenGL (not GLES/Vulkan) — same as Ghostty GTK apprt.
setenv("GDK_DISABLE", "gles-api,vulkan", 1)
cmuxLog("cmux starting...")

// Handle SIGTERM/SIGINT to save session before exit
signal(SIGTERM) { _ in
    LinuxSessionPersistence.save()
    socketServer?.stop()
    exit(0)
}
signal(SIGINT) { _ in
    LinuxSessionPersistence.save()
    socketServer?.stop()
    exit(0)
}

// Start socket control server for CLI automation
socketServer = SocketControlServer()
socketServer?.start()
cmuxLog("Socket server: \(socketServer?.socketPath ?? "none")")

guard let app = gtk_application_new("com.cmux.linux", G_APPLICATION_NON_UNIQUE) else {
    fatalError("Failed to create GtkApplication")
}
let callback: @convention(c) (OpaquePointer?, gpointer?) -> Void = activateApp
g_signal_connect_data(app, "activate",
    unsafeBitCast(callback, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

let gapp = unsafeBitCast(app, to: UnsafeMutablePointer<GApplication>.self)
// Pass only the program name to GTK (we already parsed our args)
var progName = strdup(filteredArgs[0])!
var argv: [UnsafeMutablePointer<CChar>?] = [progName, nil]
let status = argv.withUnsafeMutableBufferPointer { buf in
    g_application_run(gapp, 1, buf.baseAddress)
}
free(progName)
// Save session before exit
LinuxSessionPersistence.save()
socketServer?.stop()
g_object_unref(app)
exit(status)
