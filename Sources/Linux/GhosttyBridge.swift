// Ghostty Bridge — dlopen-based integration with libghostty on Linux
// REQ-XP-020: GTK4 application framework
// REQ-TC-001: Ghostty-based terminal emulation

import Foundation
import CGtk4
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

// The action callback. On x86_64 SysV ABI, ghostty_action_s (32 bytes)
// is passed via hidden pointer. The tag is at offset 0.
private let GHOSTTY_ACTION_RENDER: Int32 = 27
private let GHOSTTY_ACTION_QUIT: Int32 = 40

private let actionCb: @convention(c) (
    UnsafeMutableRawPointer?,  // ghostty_app_t
    UnsafeMutableRawPointer?,  // ghostty_target_s
    UnsafeMutableRawPointer?   // ghostty_action_s
) -> Bool = { _, _, actionPtr in
    // Try to read the action tag — the struct is passed by hidden pointer
    // on x86_64 for >16 byte structs
    if let glArea = globalGLArea {
        gtk_gl_area_queue_render(glArea)
    }
    return false
}

private let readClipboardCb: @convention(c) (
    UnsafeMutableRawPointer?, Int32, UnsafeMutableRawPointer?
) -> Void = { _, _, _ in }

private let confirmReadClipboardCb: @convention(c) (
    UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?, Int32
) -> Void = { _, _, _, _ in }

private let writeClipboardCb: @convention(c) (
    UnsafeMutableRawPointer?, Int32, UnsafeMutableRawPointer?, Int, Bool
) -> Void = { _, _, _, _, _ in }

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
    private var fn_surface_free: (@convention(c) (UnsafeMutableRawPointer?) -> Void)?
    private var fn_surface_draw: (@convention(c) (UnsafeMutableRawPointer?) -> Void)?
    private var fn_surface_set_size: (@convention(c) (UnsafeMutableRawPointer?, UInt32, UInt32) -> Void)?
    private var fn_surface_set_focus: (@convention(c) (UnsafeMutableRawPointer?, Bool) -> Void)?
    private var fn_surface_set_content_scale: (@convention(c) (UnsafeMutableRawPointer?, Double, Double) -> Void)?
    private var fn_surface_refresh: (@convention(c) (UnsafeMutableRawPointer?) -> Void)?
    private var fn_surface_key: (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Bool)?
    private var fn_surface_text: (@convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UInt) -> Void)?
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
              let surface_text: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UInt) -> Void = sym("ghostty_surface_text")
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
            buf.storeBytes(of: actionCb, toByteOffset: 24, as: (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Bool).self)
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

    func createSurface(glArea: UnsafeMutablePointer<GtkGLArea>, widget: UnsafeMutablePointer<GtkWidget>) -> Bool {
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

    /// Send a key event to the ghostty surface.
    /// keycode: hardware evdev scancode (from GTK EventControllerKey)
    /// text: UTF-8 text produced by the key (from gdk_keyval_to_unicode)
    /// mods: ghostty modifier flags
    /// action: 0=release, 1=press, 2=repeat
    func sendKey(keycode: UInt32, text: String?, mods: Int32, action: Int32) -> Bool {
        guard let surface = surface, let fn = fn_surface_key else { return false }

        // Build ghostty_input_key_s (32 bytes)
        var keyBuf = [UInt8](repeating: 0, count: 32)
        var result = false

        if let text = text, !text.isEmpty {
            text.withCString { cStr in
                keyBuf.withUnsafeMutableBytes { buf in
                    buf.storeBytes(of: action, toByteOffset: 0, as: Int32.self)       // action
                    buf.storeBytes(of: mods, toByteOffset: 4, as: Int32.self)          // mods
                    buf.storeBytes(of: Int32(0), toByteOffset: 8, as: Int32.self)      // consumed_mods
                    buf.storeBytes(of: keycode, toByteOffset: 12, as: UInt32.self)     // keycode
                    buf.storeBytes(of: cStr, toByteOffset: 16, as: UnsafePointer<CChar>.self)  // text
                    buf.storeBytes(of: UInt32(0), toByteOffset: 24, as: UInt32.self)   // unshifted_codepoint
                    buf.storeBytes(of: false, toByteOffset: 28, as: Bool.self)         // composing
                }
                result = keyBuf.withUnsafeMutableBytes { buf in
                    fn(surface, buf.baseAddress!)
                }
            }
        } else {
            keyBuf.withUnsafeMutableBytes { buf in
                buf.storeBytes(of: action, toByteOffset: 0, as: Int32.self)
                buf.storeBytes(of: mods, toByteOffset: 4, as: Int32.self)
                buf.storeBytes(of: Int32(0), toByteOffset: 8, as: Int32.self)
                buf.storeBytes(of: keycode, toByteOffset: 12, as: UInt32.self)
                // text pointer remains null (0)
                buf.storeBytes(of: UInt32(0), toByteOffset: 24, as: UInt32.self)
                buf.storeBytes(of: false, toByteOffset: 28, as: Bool.self)
            }
            result = keyBuf.withUnsafeMutableBytes { buf in
                fn(surface, buf.baseAddress!)
            }
        }
        return result
    }

    /// Send raw text input to the surface (for IME).
    func sendText(_ text: String) {
        guard let surface = surface, let fn = fn_surface_text else { return }
        text.withCString { cStr in
            fn(surface, cStr, UInt(text.utf8.count))
        }
    }

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

    func setContentScale(_ x: Double, _ y: Double) {
        guard let surface = surface else { return }
        fn_surface_set_content_scale?(surface, x, y)
    }

    func tick() {
        guard let app = app else { return }
        fn_app_tick?(app)
    }
}
