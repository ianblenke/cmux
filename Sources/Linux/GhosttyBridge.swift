// Ghostty Bridge — dlopen-based integration with libghostty on Linux
// REQ-XP-020: GTK4 application framework
// REQ-TC-001: Ghostty-based terminal emulation

import Foundation
import CGtk4
#if canImport(Glibc)
import Glibc
#endif

// MARK: - C struct layout (matches ghostty.h exactly)

// ghostty_runtime_config_s: 64 bytes
//   0: userdata (void*)
//   8: supports_selection_clipboard (bool, padded to 8)
//  16: wakeup_cb (fn ptr)
//  24: action_cb (fn ptr)
//  32: read_clipboard_cb (fn ptr)
//  40: confirm_read_clipboard_cb (fn ptr)
//  48: write_clipboard_cb (fn ptr)
//  56: close_surface_cb (fn ptr)

// ghostty_surface_config_s: 120 bytes
//   0: platform_tag (int32, padded to 8)
//   8: platform (union, 16 bytes — gtk.gl_area + gtk.widget)
//  24: userdata (void*)
//  32: scale_factor (double)
//  40: font_size (float, padded)
//  48: working_directory (char*)
//  56: command (char*)
//  64: env_vars (ptr)
//  72: env_var_count (size_t)
//  80: initial_input (char*)
//  88: wait_after_command (bool, padded)
//  92: context (int32)
//  96: io_mode (int32)
// 100: io_write_cb (fn ptr)
// 108: io_write_userdata (void*)

// MARK: - Callback types

private let wakeupCb: @convention(c) (UnsafeMutableRawPointer?) -> Void = { _ in }

private let actionCb: @convention(c) (
    UnsafeMutableRawPointer?,       // ghostty_app_t
    UnsafeMutableRawPointer,        // ghostty_target_s (value, 16 bytes)
    UnsafeMutableRawPointer         // ghostty_action_s (value, varies)
) -> Bool = { _, _, _ in false }

// read_clipboard: (void* userdata, ghostty_clipboard_e, void* request)
private let readClipboardCb: @convention(c) (
    UnsafeMutableRawPointer?, Int32, UnsafeMutableRawPointer?
) -> Void = { _, _, _ in }

// confirm_read_clipboard: (void*, const char*, void*, ghostty_clipboard_request_e)
private let confirmReadClipboardCb: @convention(c) (
    UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?, Int32
) -> Void = { _, _, _, _ in }

// write_clipboard: (void*, ghostty_clipboard_e, const ghostty_clipboard_content_s*, size_t, bool)
private let writeClipboardCb: @convention(c) (
    UnsafeMutableRawPointer?, Int32, UnsafeMutableRawPointer?, Int, Bool
) -> Void = { _, _, _, _, _ in }

// close_surface: (void*, bool)
private let closeSurfaceCb: @convention(c) (
    UnsafeMutableRawPointer?, Bool
) -> Void = { _, _ in
    fputs("[GhosttyBridge] Surface close requested\n", stderr)
}

// MARK: - Ghostty Library (dlopen)

final class GhosttyApp {
    private var handle: UnsafeMutableRawPointer?
    private var app: UnsafeMutableRawPointer?
    private var config: UnsafeMutableRawPointer?
    var surface: UnsafeMutableRawPointer?

    // Resolved function pointers
    private var fn_config_free: (@convention(c) (UnsafeMutableRawPointer?) -> Void)?
    private var fn_app_free: (@convention(c) (UnsafeMutableRawPointer?) -> Void)?
    private var fn_app_tick: (@convention(c) (UnsafeMutableRawPointer?) -> Void)?
    private var fn_surface_new: (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?)?
    private var fn_surface_free: (@convention(c) (UnsafeMutableRawPointer?) -> Void)?
    private var fn_surface_draw: (@convention(c) (UnsafeMutableRawPointer?) -> Void)?
    private var fn_surface_set_size: (@convention(c) (UnsafeMutableRawPointer?, UInt32, UInt32) -> Void)?
    private var fn_surface_set_focus: (@convention(c) (UnsafeMutableRawPointer?, Bool) -> Void)?
    private var fn_surface_set_content_scale: (@convention(c) (UnsafeMutableRawPointer?, Double, Double) -> Void)?
    private var fn_surface_config_new: (@convention(c) () -> UnsafeMutableRawPointer)?  // returns struct by value — we'll handle differently

    init?() {
        // Load library
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
            let err = dlerror().map { String(cString: $0) } ?? "unknown"
            fputs("[GhosttyBridge] dlopen failed: \(err)\n", stderr)
            return nil
        }

        // Resolve symbols
        func sym<T>(_ name: String) -> T? {
            guard let p = dlsym(h, name) else { return nil }
            return unsafeBitCast(p, to: T.self)
        }

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
              let surface_set_size: @convention(c) (UnsafeMutableRawPointer?, UInt32, UInt32) -> Void = sym("ghostty_surface_set_size"),
              let surface_set_focus: @convention(c) (UnsafeMutableRawPointer?, Bool) -> Void = sym("ghostty_surface_set_focus"),
              let surface_set_scale: @convention(c) (UnsafeMutableRawPointer?, Double, Double) -> Void = sym("ghostty_surface_set_content_scale")
        else {
            fputs("[GhosttyBridge] Failed to resolve symbols\n", stderr)
            dlclose(h)
            handle = nil
            return nil
        }

        self.fn_config_free = config_free
        self.fn_app_free = app_free
        self.fn_app_tick = app_tick
        self.fn_surface_new = surface_new
        self.fn_surface_free = surface_free
        self.fn_surface_draw = surface_draw
        self.fn_surface_set_size = surface_set_size
        self.fn_surface_set_focus = surface_set_focus
        self.fn_surface_set_content_scale = surface_set_scale

        // ghostty_init
        fputs("[GhosttyBridge] ghostty_init...\n", stderr)
        let initResult = ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv)
        guard initResult == 0 else {
            fputs("[GhosttyBridge] ghostty_init failed: \(initResult)\n", stderr)
            return nil
        }

        // Config
        fputs("[GhosttyBridge] config...\n", stderr)
        config = config_new()
        guard config != nil else {
            fputs("[GhosttyBridge] config_new failed\n", stderr)
            return nil
        }
        config_load(config)
        config_finalize(config)

        // Build runtime config struct (64 bytes)
        fputs("[GhosttyBridge] app_new...\n", stderr)
        var rtConfig = [UInt8](repeating: 0, count: 64)
        rtConfig.withUnsafeMutableBytes { buf in
            // userdata (offset 0): nil
            // supports_selection_clipboard (offset 8): true
            buf.storeBytes(of: true, toByteOffset: 8, as: Bool.self)
            // wakeup_cb (offset 16)
            buf.storeBytes(of: wakeupCb, toByteOffset: 16, as: (@convention(c) (UnsafeMutableRawPointer?) -> Void).self)
            // action_cb (offset 24)
            buf.storeBytes(of: actionCb, toByteOffset: 24, as: (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer, UnsafeMutableRawPointer) -> Bool).self)
            // read_clipboard_cb (offset 32)
            buf.storeBytes(of: readClipboardCb, toByteOffset: 32, as: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutableRawPointer?) -> Void).self)
            // confirm_read_clipboard_cb (offset 40)
            buf.storeBytes(of: confirmReadClipboardCb, toByteOffset: 40, as: (@convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?, Int32) -> Void).self)
            // write_clipboard_cb (offset 48)
            buf.storeBytes(of: writeClipboardCb, toByteOffset: 48, as: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutableRawPointer?, Int, Bool) -> Void).self)
            // close_surface_cb (offset 56)
            buf.storeBytes(of: closeSurfaceCb, toByteOffset: 56, as: (@convention(c) (UnsafeMutableRawPointer?, Bool) -> Void).self)
        }

        app = rtConfig.withUnsafeBytes { buf in
            app_new(buf.baseAddress!, config)
        }

        guard app != nil else {
            fputs("[GhosttyBridge] app_new FAILED\n", stderr)
            config_free(config)
            self.config = nil
            return nil
        }
        fputs("[GhosttyBridge] App created successfully!\n", stderr)
    }

    deinit {
        if let surface = surface { fn_surface_free?(surface) }
        if let app = app { fn_app_free?(app) }
        if let config = config { fn_config_free?(config) }
        if let handle = handle { dlclose(handle) }
    }

    /// Create a terminal surface for a GtkGLArea
    func createSurface(glArea: UnsafeMutableRawPointer, widget: UnsafeMutableRawPointer) -> Bool {
        guard let app = app, let fn = fn_surface_new else { return false }

        // Build surface_config (120 bytes)
        var scfg = [UInt8](repeating: 0, count: 120)
        scfg.withUnsafeMutableBytes { buf in
            // platform_tag (offset 0): GHOSTTY_PLATFORM_LINUX = 3
            buf.storeBytes(of: Int32(3), toByteOffset: 0, as: Int32.self)
            // platform.gtk.gl_area (offset 8)
            buf.storeBytes(of: glArea, toByteOffset: 8, as: UnsafeMutableRawPointer.self)
            // platform.gtk.widget (offset 16)
            buf.storeBytes(of: widget, toByteOffset: 16, as: UnsafeMutableRawPointer.self)
            // scale_factor (offset 32): 1.0
            buf.storeBytes(of: Double(1.0), toByteOffset: 32, as: Double.self)
        }

        surface = scfg.withUnsafeMutableBytes { buf in
            fn(app, buf.baseAddress!)
        }

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
