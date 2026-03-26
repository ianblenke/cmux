// Ghostty Bridge — dlopen-based integration with libghostty on Linux
// REQ-XP-020: GTK4 application framework
// REQ-TC-001: Ghostty-based terminal emulation

import Foundation
import CGtk4
#if canImport(Glibc)
import Glibc
#endif

// MARK: - Constants

private let GHOSTTY_ACTION_RENDER: Int32 = 27

// MARK: - Global state for callbacks

/// Stored so the action callback can queue GL renders
var globalGLArea: UnsafeMutablePointer<GtkGLArea>?

// MARK: - Callbacks

private let wakeupCb: @convention(c) (UnsafeMutableRawPointer?) -> Void = { _ in
    // Schedule a tick on the GTK main loop
    g_idle_add({ _ -> gboolean in 0 }, nil)
}

// The action callback receives structs by value via the C ABI.
// ghostty_target_s = 16 bytes, ghostty_action_s = 32 bytes.
// On x86_64 SysV ABI, the 16-byte target may be in registers,
// and the 32-byte action is passed via hidden pointer.
// We use UnsafeRawPointer for the struct params.
private let actionCb: @convention(c) (
    UnsafeMutableRawPointer?,  // ghostty_app_t
    UnsafeMutableRawPointer?,  // ghostty_target_s (by value — pointer in some ABIs)
    UnsafeMutableRawPointer?   // ghostty_action_s (by value — pointer in some ABIs)
) -> Bool = { _, _, actionPtr in
    // The action tag is at offset 0 (int32)
    guard let actionPtr = actionPtr else { return false }
    let tag = actionPtr.load(as: Int32.self)

    if tag == GHOSTTY_ACTION_RENDER {
        // Queue a GL render on the GtkGLArea
        if let glArea = globalGLArea {
            gtk_gl_area_queue_render(glArea)
        }
        return true
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
) -> Void = { _, _ in
    fputs("[GhosttyBridge] Surface close requested\n", stderr)
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
    private var fn_config_free: (@convention(c) (UnsafeMutableRawPointer?) -> Void)?

    init?() {
        let paths = [
            "ghostty/zig-out/lib/libghostty.so",
            "./ghostty/zig-out/lib/libghostty.so",
            "libghostty.so",
        ]
        for path in paths {
            handle = dlopen(path, RTLD_NOW)
            if handle != nil {
                fputs("[GhosttyBridge] Loaded: \(path)\n", stderr)
                break
            }
        }
        guard let h = handle else {
            fputs("[GhosttyBridge] dlopen failed: \(dlerror().map { String(cString: $0) } ?? "?")\n", stderr)
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
              let surface_set_scale: @convention(c) (UnsafeMutableRawPointer?, Double, Double) -> Void = sym("ghostty_surface_set_content_scale")
        else {
            fputs("[GhosttyBridge] Symbol resolution failed\n", stderr)
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

        // Step 1: ghostty_init
        fputs("[GhosttyBridge] ghostty_init...\n", stderr)
        let initResult = ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv)
        guard initResult == 0 else {
            fputs("[GhosttyBridge] ghostty_init failed: \(initResult)\n", stderr)
            return nil
        }

        // Step 2: Config
        fputs("[GhosttyBridge] config...\n", stderr)
        config = config_new()
        guard config != nil else { return nil }
        config_load(config)
        config_finalize(config)

        // Step 3: App with runtime config (64 bytes)
        fputs("[GhosttyBridge] app_new...\n", stderr)
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
            fputs("[GhosttyBridge] app_new FAILED\n", stderr)
            config_free(config); self.config = nil; return nil
        }
        fputs("[GhosttyBridge] App created!\n", stderr)
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

        fputs("[GhosttyBridge] Creating surface...\n", stderr)
        surface = scfg.withUnsafeMutableBytes { buf in fn(app, buf.baseAddress!) }

        if surface != nil {
            fputs("[GhosttyBridge] Surface created!\n", stderr)
            return true
        } else {
            fputs("[GhosttyBridge] Surface creation failed\n", stderr)
            return false
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
