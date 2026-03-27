// Ghostty Bridge — dlopen-based integration with libghostty on Linux
// REQ-XP-020: GTK4 application framework
// REQ-TC-001: Ghostty-based terminal emulation

import Foundation
import CGtk4
import CGhosttyHelpers
#if canImport(Glibc)
import Glibc
#endif


// MARK: - Global state for callbacks

/// Stored so the action callback can queue GL renders
var globalGLArea: UnsafeMutablePointer<GtkGLArea>?

// MARK: - Callbacks

private let wakeupCb: @convention(c) (UnsafeMutableRawPointer?) -> Void = { _ in
    // Schedule ghostty_app_tick on the GTK main loop
    g_idle_add({ _ -> gboolean in
        ghosttyApp?.tick()
        return 0 // G_SOURCE_REMOVE — one-shot
    }, nil)
}

// Action callback — routes through C helper for correct ABI handling.
// cmux_ghostty_action_handler parses the action struct and calls our
// Swift callbacks for title, pwd, and render events.

// Read clipboard: ghostty wants to paste. We need to read from GDK clipboard
// and call ghostty_surface_complete_clipboard_request with the result.
// For now, complete with empty string — full async clipboard requires more plumbing.
private let readClipboardCb: @convention(c) (
    UnsafeMutableRawPointer?, Int32, UnsafeMutableRawPointer?
) -> Void = { userdata, clipboardType, request in
    // TODO: Implement async GDK clipboard read
    // For now ghostty will handle paste through key bindings
}

private let confirmReadClipboardCb: @convention(c) (
    UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?, Int32
) -> Void = { _, _, _, _ in
    // Auto-approve clipboard reads
}

// Write clipboard: ghostty wants to copy text (e.g., terminal selection)
private let writeClipboardCb: @convention(c) (
    UnsafeMutableRawPointer?, Int32, UnsafeMutableRawPointer?, Int, Bool
) -> Void = { _, clipboardType, contentPtr, count, confirmed in
    guard let contentPtr = contentPtr, count > 0 else { return }

    // ghostty_clipboard_content_s is { const char* mime; const char* data; }
    // Each entry is 16 bytes (two pointers)
    let content = contentPtr.assumingMemoryBound(to: (UnsafePointer<CChar>?, UnsafePointer<CChar>?).self)

    // Use the first content entry's data
    if let dataPtr = content.pointee.1 {
        let text = String(cString: dataPtr)
        // Write to GDK clipboard
        if let display = gdk_display_get_default() {
            let clipboard = gdk_display_get_clipboard(display)
            gdk_clipboard_set_text(clipboard, text)
            cmuxLog("[clipboard] Copied \(text.count) chars")
        }
    }
}

private let closeSurfaceCb: @convention(c) (
    UnsafeMutableRawPointer?, Bool
) -> Void = { _, processActive in
    cmuxLog("[GhosttyBridge] Surface close requested (processActive=\(processActive))")
    // Don't exit — keep the window open
}

// MARK: - Ghostty App (dlopen-based)

final class GhosttyApp {
    private var handle: UnsafeMutableRawPointer?
    private var app: UnsafeMutableRawPointer?
    private var config: UnsafeMutableRawPointer?
    var surface: UnsafeMutableRawPointer?

    // Function pointers
    private var fn_app_free: (@convention(c) (UnsafeMutableRawPointer?) -> Void)?
    private var fn_app_tick: (@convention(c) (UnsafeMutableRawPointer?) -> Void)?
    private var fn_surface_new: (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?)?
    var fn_surface_free: (@convention(c) (UnsafeMutableRawPointer?) -> Void)?
    private var fn_surface_draw: (@convention(c) (UnsafeMutableRawPointer?) -> Void)?
    var fn_surface_set_size: (@convention(c) (UnsafeMutableRawPointer?, UInt32, UInt32) -> Void)?
    var fn_surface_set_focus: (@convention(c) (UnsafeMutableRawPointer?, Bool) -> Void)?
    var fn_surface_set_content_scale: (@convention(c) (UnsafeMutableRawPointer?, Double, Double) -> Void)?
    private var fn_surface_refresh: (@convention(c) (UnsafeMutableRawPointer?) -> Void)?
    private var fn_surface_key: (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Bool)?
    private var fn_surface_text: (@convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UInt) -> Void)?
    private var fn_surface_mouse_button: (@convention(c) (UnsafeMutableRawPointer?, Int32, Int32, Int32) -> Bool)?
    private var fn_surface_mouse_pos: (@convention(c) (UnsafeMutableRawPointer?, Double, Double, Int32) -> Void)?
    private var fn_surface_mouse_scroll: (@convention(c) (UnsafeMutableRawPointer?, Double, Double, Int32) -> Void)?
    private var fn_surface_binding_action: (@convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UInt) -> Bool)?
    private var fn_config_free: (@convention(c) (UnsafeMutableRawPointer?) -> Void)?

    init?() {
        // Resolve library path relative to the executable
        let execDir = ProcessInfo.processInfo.arguments[0]
            .split(separator: "/").dropLast().joined(separator: "/")
        let paths = [
            "/home/ianblenke/github.com/ianblenke/cmux/ghostty/zig-out/lib/libghostty.so",
            "ghostty/zig-out/lib/libghostty.so",
            "libghostty.so",
        ]
        for path in paths {
            handle = dlopen(path, RTLD_NOW)
            if handle != nil {
                cmuxLog("[GhosttyBridge] Loaded: \(path)")
                break
            }
        }
        guard let h = handle else {
            cmuxLog("[GhosttyBridge] dlopen failed: \(dlerror().map { String(cString: $0) } ?? "?")")
            return nil
        }

        func sym<T>(_ name: String) -> T? {
            guard let p = dlsym(h, name) else { return nil }
            return unsafeBitCast(p, to: T.self)
        }

        // Resolve all symbols
        guard let ghostty_init: @convention(c) (UInt, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32 = sym("ghostty_init"),
              let config_new: @convention(c) () -> UnsafeMutableRawPointer? = sym("ghostty_config_new"),
              let config_free: @convention(c) (UnsafeMutableRawPointer?) -> Void = sym("ghostty_config_free"),
              let config_load: @convention(c) (UnsafeMutableRawPointer?) -> Void = sym("ghostty_config_load_default_files"),
              let config_finalize: @convention(c) (UnsafeMutableRawPointer?) -> Void = sym("ghostty_config_finalize"),
              let app_new: @convention(c) (UnsafeRawPointer?, UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? = sym("ghostty_app_new"),
              let app_free: @convention(c) (UnsafeMutableRawPointer?) -> Void = sym("ghostty_app_free"),
              let app_tick: @convention(c) (UnsafeMutableRawPointer?) -> Void = sym("ghostty_app_tick"),
              let surface_new: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? = sym("ghostty_surface_new"),
              let surface_free: @convention(c) (UnsafeMutableRawPointer?) -> Void = sym("ghostty_surface_free"),
              let surface_draw: @convention(c) (UnsafeMutableRawPointer?) -> Void = sym("ghostty_surface_draw"),
              let surface_refresh: @convention(c) (UnsafeMutableRawPointer?) -> Void = sym("ghostty_surface_refresh"),
              let surface_set_size: @convention(c) (UnsafeMutableRawPointer?, UInt32, UInt32) -> Void = sym("ghostty_surface_set_size"),
              let surface_set_focus: @convention(c) (UnsafeMutableRawPointer?, Bool) -> Void = sym("ghostty_surface_set_focus"),
              let surface_set_scale: @convention(c) (UnsafeMutableRawPointer?, Double, Double) -> Void = sym("ghostty_surface_set_content_scale"),
              let surface_key: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Bool = sym("ghostty_surface_key"),
              let surface_text: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UInt) -> Void = sym("ghostty_surface_text"),
              let surface_mouse_button: @convention(c) (UnsafeMutableRawPointer?, Int32, Int32, Int32) -> Bool = sym("ghostty_surface_mouse_button"),
              let surface_mouse_pos: @convention(c) (UnsafeMutableRawPointer?, Double, Double, Int32) -> Void = sym("ghostty_surface_mouse_pos"),
              let surface_mouse_scroll: @convention(c) (UnsafeMutableRawPointer?, Double, Double, Int32) -> Void = sym("ghostty_surface_mouse_scroll"),
              let surface_binding_action: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UInt) -> Bool = sym("ghostty_surface_binding_action")
        else {
            cmuxLog("[GhosttyBridge] Symbol resolution failed")
            dlclose(h); handle = nil; return nil
        }

        self.fn_config_free = config_free
        self.fn_app_free = app_free
        self.fn_app_tick = app_tick
        self.fn_surface_new = surface_new
        self.fn_surface_free = surface_free
        self.fn_surface_draw = surface_draw
        self.fn_surface_refresh = surface_refresh
        self.fn_surface_set_size = surface_set_size
        self.fn_surface_set_focus = surface_set_focus
        self.fn_surface_set_content_scale = surface_set_scale
        self.fn_surface_key = surface_key
        self.fn_surface_text = surface_text
        self.fn_surface_mouse_button = surface_mouse_button
        self.fn_surface_mouse_pos = surface_mouse_pos
        self.fn_surface_mouse_scroll = surface_mouse_scroll
        self.fn_surface_binding_action = surface_binding_action

        // Resolve C helper functions (for correct ABI calling convention)
        cmux_ghostty_resolve_key_fns(h)
        cmux_ghostty_resolve_selection_fns(h)

        // Set up action callbacks for title/pwd/render
        // Notification callbacks
        cmux_set_notification_callbacks(
            // Desktop notification (OSC 9/99/777)
            { title, body in
                let t: String
                if let title = title, title[0] != 0 {
                    t = String(cString: title)
                } else {
                    t = ""
                }
                let b: String
                if let body = body, body[0] != 0 {
                    b = String(cString: body)
                } else {
                    b = ""
                }
                if !t.isEmpty || !b.isEmpty {
                    workspaceManager.notifyActive(title: t, body: b)
                }
            },
            // Bell
            {
                workspaceManager.bellActive()
            }
        )

        // Action callbacks
        cmux_set_action_callbacks(
            // Title changed
            { title in
                guard let title = title else { return }
                let str = String(cString: title)
                cmuxLog("[action] title: \(str)")
                workspaceManager.updateActiveTitle(str)
            },
            // PWD changed
            { pwd in
                guard let pwd = pwd else { return }
                let str = String(cString: pwd)
                cmuxLog("[action] pwd: \(str)")
                workspaceManager.updateActiveCwd(str)
            },
            // Render requested
            {
                if let glArea = globalGLArea {
                    gtk_gl_area_queue_render(glArea)
                }
            }
        )

        // Step 1: ghostty_init
        cmuxLog("[GhosttyBridge] ghostty_init...")
        let initResult = ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv)
        guard initResult == 0 else {
            cmuxLog("[GhosttyBridge] ghostty_init failed: \(initResult)")
            return nil
        }

        // Step 2: Config
        cmuxLog("[GhosttyBridge] config...")
        config = config_new()
        guard config != nil else { return nil }
        config_load(config)
        config_finalize(config)

        // Step 3: App with runtime config (64 bytes)
        cmuxLog("[GhosttyBridge] app_new...")
        var rtConfig = [UInt8](repeating: 0, count: 64)
        rtConfig.withUnsafeMutableBytes { buf in
            buf.storeBytes(of: true, toByteOffset: 8, as: Bool.self)
            buf.storeBytes(of: wakeupCb, toByteOffset: 16, as: (@convention(c) (UnsafeMutableRawPointer?) -> Void).self)
            // Use C action handler with correct struct-by-value ABI
            let actionFnPtr = cmux_ghostty_get_action_handler()!
            buf.storeBytes(of: actionFnPtr, toByteOffset: 24, as: UnsafeMutableRawPointer.self)
            buf.storeBytes(of: readClipboardCb, toByteOffset: 32, as: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutableRawPointer?) -> Void).self)
            buf.storeBytes(of: confirmReadClipboardCb, toByteOffset: 40, as: (@convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?, Int32) -> Void).self)
            buf.storeBytes(of: writeClipboardCb, toByteOffset: 48, as: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutableRawPointer?, Int, Bool) -> Void).self)
            buf.storeBytes(of: closeSurfaceCb, toByteOffset: 56, as: (@convention(c) (UnsafeMutableRawPointer?, Bool) -> Void).self)
        }

        app = rtConfig.withUnsafeBytes { buf in
            app_new(buf.baseAddress!, config)
        }
        guard app != nil else {
            cmuxLog("[GhosttyBridge] app_new FAILED")
            config_free(config); self.config = nil; return nil
        }
        cmuxLog("[GhosttyBridge] App created!")
    }

    deinit {
        if let surface = surface { fn_surface_free?(surface) }
        if let app = app { fn_app_free?(app) }
        if let config = config { fn_config_free?(config) }
        if let handle = handle { dlclose(handle) }
    }

    func createSurface(glArea: UnsafeMutablePointer<GtkGLArea>, widget: UnsafeMutablePointer<GtkWidget>,
                       command: String? = nil, workingDirectory: String? = nil) -> Bool {
        guard let app = app, let fn = fn_surface_new else { return false }

        // Store for render callback
        globalGLArea = glArea

        // Build surface_config (120 bytes)
        var scfg = [UInt8](repeating: 0, count: 120)
        scfg.withUnsafeMutableBytes { buf in
            buf.storeBytes(of: Int32(3), toByteOffset: 0, as: Int32.self) // GHOSTTY_PLATFORM_LINUX
            buf.storeBytes(of: UnsafeMutableRawPointer(glArea), toByteOffset: 8, as: UnsafeMutableRawPointer.self)
            buf.storeBytes(of: UnsafeMutableRawPointer(widget), toByteOffset: 16, as: UnsafeMutableRawPointer.self)
            buf.storeBytes(of: Double(1.0), toByteOffset: 32, as: Double.self) // scale_factor
        }

        // Set CMUX_SOCKET_PATH env var so shell integration can find us
        // ghostty_env_var_s is {const char* key, const char* value} (16 bytes)
        let socketPath = socketServer?.socketPath ?? ""
        let envKey = strdup("CMUX_SOCKET_PATH")!
        let envVal = strdup(socketPath)!
        let integKey = strdup("CMUX_SHELL_INTEGRATION")!
        let integVal = strdup("1")!
        let integDirKey = strdup("CMUX_SHELL_INTEGRATION_DIR")!
        // Resolve path to shell integration scripts
        let projectDir = ProcessInfo.processInfo.environment["PWD"] ?? "/home/ianblenke/github.com/ianblenke/cmux"
        let integDirVal = strdup("\(projectDir)/Resources/shell-integration")!
        defer { free(envKey); free(envVal); free(integKey); free(integVal); free(integDirKey); free(integDirVal) }

        // Build env vars array: [{key, value}, ...]
        var envVars = [UnsafeRawPointer?](repeating: nil, count: 6)
        envVars[0] = UnsafeRawPointer(envKey)
        envVars[1] = UnsafeRawPointer(envVal)
        envVars[2] = UnsafeRawPointer(integKey)
        envVars[3] = UnsafeRawPointer(integVal)
        envVars[4] = UnsafeRawPointer(integDirKey)
        envVars[5] = UnsafeRawPointer(integDirVal)

        envVars.withUnsafeMutableBufferPointer { buf in
            scfg.withUnsafeMutableBytes { scfgBuf in
                // env_vars at offset 64 (pointer to array)
                scfgBuf.storeBytes(of: buf.baseAddress!, toByteOffset: 64, as: UnsafeRawPointer.self)
                // env_var_count at offset 72 (size_t)
                scfgBuf.storeBytes(of: UInt(3), toByteOffset: 72, as: UInt.self)
            }
        }

        // Set working directory and command using strdup to keep strings alive
        var dirStr: UnsafeMutablePointer<CChar>? = nil
        var cmdStr: UnsafeMutablePointer<CChar>? = nil
        if let dir = workingDirectory { dirStr = strdup(dir) }
        if let cmd = command { cmdStr = strdup(cmd) }
        defer { free(dirStr); free(cmdStr) }

        if let d = dirStr {
            scfg.withUnsafeMutableBytes { buf in
                buf.storeBytes(of: UnsafePointer(d), toByteOffset: 48, as: UnsafePointer<CChar>?.self)
            }
        }
        if let c = cmdStr {
            scfg.withUnsafeMutableBytes { buf in
                buf.storeBytes(of: UnsafePointer(c), toByteOffset: 56, as: UnsafePointer<CChar>?.self)
            }
        }

        cmuxLog("[GhosttyBridge] Creating surface...")
        surface = scfg.withUnsafeMutableBytes { buf in fn(app, buf.baseAddress!) }

        if surface != nil {
            cmuxLog("[GhosttyBridge] Surface created!")
            return true
        } else {
            cmuxLog("[GhosttyBridge] Surface creation failed")
            return false
        }
    }

    /// Send a key event to the ghostty surface via C helper (correct ABI).
    func sendKey(keycode: UInt32, text: String?, mods: Int32, action: Int32) -> Bool {
        guard let surface = surface else { return false }

        if let text = text, !text.isEmpty {
            return text.withCString { cStr in
                cmux_ghostty_surface_key(surface, action, mods, 0, keycode, cStr, 0, false)
            }
        } else {
            return cmux_ghostty_surface_key(surface, action, mods, 0, keycode, nil, 0, false)
        }
    }

    /// Send raw text input to the surface (for IME).
    func sendText(_ text: String) {
        guard let surface = surface else { return }
        text.withCString { cStr in
            cmux_ghostty_surface_text(surface, cStr, text.utf8.count)
        }
    }

    // MARK: - Binding Actions

    /// Execute a ghostty binding action by name (e.g., "increase_font_size:1")
    @discardableResult
    func bindingAction(_ action: String) -> Bool {
        guard let surface = surface, let fn = fn_surface_binding_action else { return false }
        return action.withCString { cStr in
            fn(surface, cStr, UInt(action.utf8.count))
        }
    }

    // MARK: - Clipboard

    /// Copy terminal selection to GDK clipboard. Returns true if copied.
    func copySelection() -> Bool {
        guard let surface = surface else { return false }
        guard let cStr = cmux_ghostty_copy_selection(surface) else { return false }
        let text = String(cString: cStr)
        free(cStr)
        if let display = gdk_display_get_default() {
            let clipboard = gdk_display_get_clipboard(display)
            gdk_clipboard_set_text(clipboard, text)
            cmuxLog("[clipboard] Copied \(text.count) chars")
            return true
        }
        return false
    }

    /// Paste from GDK clipboard into terminal
    func pasteFromClipboard() {
        guard let surface = surface else { return }
        // GDK async clipboard read — for now use a simpler approach
        // by reading the clipboard synchronously via the X11/Wayland selection
        // TODO: Implement proper async GDK clipboard read
        // For now, we'll use ghostty's built-in paste binding
    }

    // MARK: - Mouse input

    /// Mouse button press/release
    /// state: 0=release, 1=press
    /// button: 1=left, 2=right, 3=middle
    func mouseButton(state: Int32, button: Int32, mods: Int32) -> Bool {
        guard let surface = surface, let fn = fn_surface_mouse_button else { return false }
        return fn(surface, state, button, mods)
    }

    /// Mouse position update
    func mousePos(x: Double, y: Double, mods: Int32) {
        guard let surface = surface, let fn = fn_surface_mouse_pos else { return }
        fn(surface, x, y, mods)
    }

    /// Mouse scroll
    func mouseScroll(dx: Double, dy: Double, mods: Int32) {
        guard let surface = surface, let fn = fn_surface_mouse_scroll else { return }
        fn(surface, dx, dy, mods)
    }

    // MARK: - Rendering

    func draw() {
        guard let surface = surface else { return }
        fn_surface_draw?(surface)
    }

    func refresh() {
        guard let surface = surface else { return }
        fn_surface_refresh?(surface)
    }

    func setSize(_ w: UInt32, _ h: UInt32) {
        guard let surface = surface else { return }
        fn_surface_set_size?(surface, w, h)
    }

    func setFocus(_ focused: Bool) {
        guard let surface = surface else { return }
        fn_surface_set_focus?(surface, focused)
    }

    /// Set focus on a specific surface (for workspace switching)
    func setFocusOnSurface(_ surface: UnsafeMutableRawPointer, focused: Bool) {
        fn_surface_set_focus?(surface, focused)
    }

    /// Draw a specific surface (for workspace switching)
    func drawSurface(_ surface: UnsafeMutableRawPointer) {
        fn_surface_draw?(surface)
    }

    func setContentScale(_ x: Double, _ y: Double) {
        guard let surface = surface else { return }
        fn_surface_set_content_scale?(surface, x, y)
    }

    func tick() {
        guard let app = app else { return }
        fn_app_tick?(app)
    }
}
