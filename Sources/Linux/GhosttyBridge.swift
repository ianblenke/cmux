// Ghostty Bridge — Swift wrapper for the libghostty C embedding API on Linux
// REQ-XP-020: GTK4 application framework
// REQ-TC-001: Ghostty-based terminal emulation

import Foundation
import CGtk4
import CGhostty

// MARK: - Ghostty App Wrapper

/// Manages the ghostty_app_t lifecycle and provides terminal surface creation.
final class GhosttyApp {
    private var app: ghostty_app_t?
    private var config: ghostty_config_t?

    init?() {
        // Initialize ghostty
        let argc = Int(CommandLine.argc)
        let argv = CommandLine.unsafeArgv
        let initResult = ghostty_init(UInt(argc), argv)
        guard initResult == GHOSTTY_SUCCESS else {
            print("ghostty_init failed with code \(initResult)")
            return nil
        }

        // Create config
        config = ghostty_config_new()
        guard config != nil else {
            print("ghostty_config_new failed")
            return nil
        }

        // Load default config files (~/.config/ghostty/config)
        ghostty_config_load_default_files(config)
        ghostty_config_finalize(config)

        // Create runtime config with callbacks
        var runtimeConfig = ghostty_runtime_config_s()
        runtimeConfig.userdata = Unmanaged.passUnretained(self).toOpaque()
        runtimeConfig.supports_selection_clipboard = true
        runtimeConfig.wakeup_cb = ghosttyWakeupCb
        runtimeConfig.action_cb = ghosttyActionCb
        runtimeConfig.read_clipboard_cb = ghosttyReadClipboardCb
        runtimeConfig.confirm_read_clipboard_cb = ghosttyConfirmReadClipboardCb
        runtimeConfig.write_clipboard_cb = ghosttyWriteClipboardCb
        runtimeConfig.close_surface_cb = ghosttyCloseSurfaceCb

        // Create the ghostty app
        app = ghostty_app_new(&runtimeConfig, config)
        guard app != nil else {
            print("ghostty_app_new failed")
            ghostty_config_free(config)
            config = nil
            return nil
        }

        print("[GhosttyBridge] App initialized successfully")
    }

    deinit {
        if let app = app {
            ghostty_app_free(app)
        }
        if let config = config {
            ghostty_config_free(config)
        }
    }

    /// Create a new terminal surface backed by a GtkGLArea.
    func createSurface(glArea: UnsafeMutablePointer<GtkGLArea>,
                       widget: UnsafeMutablePointer<GtkWidget>) -> ghostty_surface_t? {
        guard let app = app else { return nil }

        var surfaceConfig = ghostty_surface_config_new()
        surfaceConfig.platform_tag = GHOSTTY_PLATFORM_LINUX
        surfaceConfig.platform.gtk.gl_area = UnsafeMutableRawPointer(glArea)
        surfaceConfig.platform.gtk.widget = UnsafeMutableRawPointer(widget)
        surfaceConfig.scale_factor = 1.0

        let surface = ghostty_surface_new(app, &surfaceConfig)
        if surface != nil {
            print("[GhosttyBridge] Surface created successfully")
        } else {
            print("[GhosttyBridge] Surface creation failed")
        }
        return surface
    }

    /// Tick the ghostty event loop.
    func tick() {
        guard let app = app else { return }
        ghostty_app_tick(app)
    }
}

// MARK: - C Callbacks (must match exact C function pointer signatures)

private let ghosttyWakeupCb: @convention(c) (UnsafeMutableRawPointer?) -> Void = { _ in
    g_idle_add({ _ -> gboolean in
        return 0 // G_SOURCE_REMOVE
    }, nil)
}

private let ghosttyActionCb: @convention(c) (
    ghostty_app_t?, ghostty_target_s, ghostty_action_s
) -> Bool = { app, target, action in
    return false
}

private let ghosttyReadClipboardCb: @convention(c) (
    UnsafeMutableRawPointer?, ghostty_clipboard_e, UnsafeMutableRawPointer?
) -> Void = { userdata, clipboard, request in
    // TODO: Implement GDK clipboard read
}

private let ghosttyConfirmReadClipboardCb: @convention(c) (
    UnsafeMutableRawPointer?,
    UnsafePointer<CChar>?,
    UnsafeMutableRawPointer?,
    ghostty_clipboard_request_e
) -> Void = { userdata, content, request, requestType in
    // Auto-approve for now
}

private let ghosttyWriteClipboardCb: @convention(c) (
    UnsafeMutableRawPointer?,
    ghostty_clipboard_e,
    UnsafePointer<ghostty_clipboard_content_s>?,
    Int,
    Bool
) -> Void = { userdata, clipboard, content, count, confirmed in
    // TODO: Implement GDK clipboard write
}

private let ghosttyCloseSurfaceCb: @convention(c) (
    UnsafeMutableRawPointer?, Bool
) -> Void = { userdata, processActive in
    print("[GhosttyBridge] Surface close requested")
}
