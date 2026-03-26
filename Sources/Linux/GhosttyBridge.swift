// Ghostty Bridge — dlopen-based loading of libghostty on Linux
// REQ-XP-020: GTK4 application framework
// REQ-TC-001: Ghostty-based terminal emulation
//
// Uses dlopen to load libghostty.so lazily, avoiding the Zig global
// constructor crash that occurs when linking at compile time.

import Foundation
import CGtk4
#if canImport(Glibc)
import Glibc
#endif

// MARK: - Function pointer types matching ghostty.h

typealias GhosttyInitFn = @convention(c) (UInt, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32
typealias GhosttyConfigNewFn = @convention(c) () -> UnsafeMutableRawPointer?
typealias GhosttyConfigFreeFn = @convention(c) (UnsafeMutableRawPointer?) -> Void
typealias GhosttyConfigLoadDefaultFilesFn = @convention(c) (UnsafeMutableRawPointer?) -> Void
typealias GhosttyConfigFinalizeFn = @convention(c) (UnsafeMutableRawPointer?) -> Void
typealias GhosttyAppTickFn = @convention(c) (UnsafeMutableRawPointer?) -> Void
typealias GhosttyAppFreeFn = @convention(c) (UnsafeMutableRawPointer?) -> Void

// ghostty_app_new takes (const ghostty_runtime_config_s*, ghostty_config_t)
// Both are pointers. We'll use raw pointer types.
typealias GhosttyAppNewFn = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?

// MARK: - Ghostty Library Handle

/// Lazily loads libghostty.so via dlopen and resolves function pointers.
final class GhosttyLibrary {
    private let handle: UnsafeMutableRawPointer

    let ghostty_init: GhosttyInitFn
    let ghostty_config_new: GhosttyConfigNewFn
    let ghostty_config_free: GhosttyConfigFreeFn
    let ghostty_config_load_default_files: GhosttyConfigLoadDefaultFilesFn
    let ghostty_config_finalize: GhosttyConfigFinalizeFn
    let ghostty_app_new: GhosttyAppNewFn
    let ghostty_app_free: GhosttyAppFreeFn
    let ghostty_app_tick: GhosttyAppTickFn

    init?() {
        // Try to find libghostty.so
        let paths = [
            "ghostty/zig-out/lib/libghostty.so",
            "./ghostty/zig-out/lib/libghostty.so",
            "libghostty.so",
        ]

        var loadedHandle: UnsafeMutableRawPointer? = nil
        for path in paths {
            loadedHandle = dlopen(path, RTLD_NOW)
            if loadedHandle != nil {
                fputs("[GhosttyLib] Loaded: \(path)\n", stderr)
                break
            } else {
                let err = dlerror().map { String(cString: $0) } ?? "unknown"
                fputs("[GhosttyLib] dlopen(\(path)) failed: \(err)\n", stderr)
            }
        }

        guard let h = loadedHandle else {
            let err = String(cString: dlerror()!)
            print("[GhosttyLib] Failed to load libghostty.so: \(err)")
            return nil
        }
        handle = h

        // Resolve function pointers
        func sym<T>(_ name: String) -> T? {
            guard let p = dlsym(h, name) else {
                print("[GhosttyLib] Missing symbol: \(name)")
                return nil
            }
            return unsafeBitCast(p, to: T.self)
        }

        guard let init_fn: GhosttyInitFn = sym("ghostty_init"),
              let config_new: GhosttyConfigNewFn = sym("ghostty_config_new"),
              let config_free: GhosttyConfigFreeFn = sym("ghostty_config_free"),
              let config_load: GhosttyConfigLoadDefaultFilesFn = sym("ghostty_config_load_default_files"),
              let config_finalize: GhosttyConfigFinalizeFn = sym("ghostty_config_finalize"),
              let app_new: GhosttyAppNewFn = sym("ghostty_app_new"),
              let app_free: GhosttyAppFreeFn = sym("ghostty_app_free"),
              let app_tick: GhosttyAppTickFn = sym("ghostty_app_tick")
        else {
            dlclose(h)
            return nil
        }

        self.ghostty_init = init_fn
        self.ghostty_config_new = config_new
        self.ghostty_config_free = config_free
        self.ghostty_config_load_default_files = config_load
        self.ghostty_config_finalize = config_finalize
        self.ghostty_app_new = app_new
        self.ghostty_app_free = app_free
        self.ghostty_app_tick = app_tick

        print("[GhosttyLib] All symbols resolved")
    }

    deinit {
        dlclose(handle)
    }
}

// MARK: - Ghostty App Wrapper

final class GhosttyApp {
    private var lib: GhosttyLibrary?
    private var app: UnsafeMutableRawPointer?
    private var config: UnsafeMutableRawPointer?

    init?() {
        print("[GhosttyBridge] Loading library...")
        lib = GhosttyLibrary()
        guard let lib = lib else { return nil }

        print("[GhosttyBridge] ghostty_init...")
        let argc = Int(CommandLine.argc)
        let argv = CommandLine.unsafeArgv
        let initResult = lib.ghostty_init(UInt(argc), argv)
        guard initResult == 0 else {
            print("[GhosttyBridge] ghostty_init failed: \(initResult)")
            return nil
        }
        print("[GhosttyBridge] ghostty_init OK")

        print("[GhosttyBridge] config...")
        config = lib.ghostty_config_new()
        guard config != nil else {
            print("[GhosttyBridge] ghostty_config_new failed")
            return nil
        }
        lib.ghostty_config_load_default_files(config)
        lib.ghostty_config_finalize(config)
        print("[GhosttyBridge] config OK")

        // For now, skip ghostty_app_new since it requires the runtime config
        // struct with callbacks that crash. Just verify init + config work.
        print("[GhosttyBridge] Init + config successful (app creation deferred)")
    }

    deinit {
        if let app = app, let lib = lib { lib.ghostty_app_free(app) }
        if let config = config, let lib = lib { lib.ghostty_config_free(config) }
    }

    func tick() {
        guard let app = app, let lib = lib else { return }
        lib.ghostty_app_tick(app)
    }
}
