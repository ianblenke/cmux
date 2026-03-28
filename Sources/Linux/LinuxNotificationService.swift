// Linux Desktop Notification Service — dlopen-based libnotify integration
// REQ-XP-002: PAL notification protocol implementation for Linux
//
// Uses dlopen to load libnotify at runtime so the binary works without it installed.
// Falls back to GTK urgency hint + g_log if libnotify is unavailable.

import Foundation
import CGtk4
#if canImport(Glibc)
import Glibc
#endif

/// Delivers desktop notifications via libnotify (if available) and sets
/// GTK window urgency hints so the taskbar flashes on bell/notification.
final class LinuxNotificationService {
    static let shared = LinuxNotificationService()

    // libnotify function pointers (resolved via dlopen)
    private var handle: UnsafeMutableRawPointer?
    private var fn_notify_init: (@convention(c) (UnsafePointer<CChar>) -> gboolean)?
    private var fn_notify_notification_new: (@convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> OpaquePointer)?
    private var fn_notify_notification_show: (@convention(c) (OpaquePointer, UnsafeMutablePointer<OpaquePointer?>?) -> gboolean)?
    private var fn_notify_notification_set_timeout: (@convention(c) (OpaquePointer, Int32) -> Void)?
    private var fn_notify_notification_set_urgency: (@convention(c) (OpaquePointer, Int32) -> Void)?
    private var fn_g_object_unref: (@convention(c) (OpaquePointer) -> Void)?

    private(set) var isAvailable = false
    private var initialized = false

    /// Whether the cmux window currently has focus (suppress notifications when focused)
    var windowIsFocused = true

    private init() {
        // Try to load libnotify
        let paths = [
            "libnotify.so.4",
            "libnotify.so",
            "/usr/lib/libnotify.so.4",
            "/usr/lib/x86_64-linux-gnu/libnotify.so.4",
            "/usr/lib64/libnotify.so.4",
        ]
        for path in paths {
            handle = dlopen(path, RTLD_NOW)
            if handle != nil {
                cmuxLog("[notify] Loaded libnotify: \(path)")
                break
            }
        }
        guard let h = handle else {
            cmuxLog("[notify] libnotify not found — desktop notifications disabled")
            return
        }

        func sym<T>(_ name: String) -> T? {
            guard let p = dlsym(h, name) else { return nil }
            return unsafeBitCast(p, to: T.self)
        }

        fn_notify_init = sym("notify_init")
        fn_notify_notification_new = sym("notify_notification_new")
        fn_notify_notification_show = sym("notify_notification_show")
        fn_notify_notification_set_timeout = sym("notify_notification_set_timeout")
        fn_notify_notification_set_urgency = sym("notify_notification_set_urgency")
        fn_g_object_unref = sym("g_object_unref")

        guard fn_notify_init != nil,
              fn_notify_notification_new != nil,
              fn_notify_notification_show != nil else {
            cmuxLog("[notify] Failed to resolve libnotify symbols")
            dlclose(h); handle = nil
            return
        }

        // Initialize libnotify
        if fn_notify_init!("cmux") != 0 {
            isAvailable = true
            initialized = true
            cmuxLog("[notify] libnotify initialized")
        } else {
            cmuxLog("[notify] notify_init failed")
        }
    }

    deinit {
        if let h = handle { dlclose(h) }
    }

    // MARK: - Public API

    /// Post a desktop notification. Suppressed if the window is focused.
    func post(title: String, body: String) {
        // Skip desktop notification if window is focused
        if windowIsFocused {
            cmuxLog("[notify] Suppressed (window focused): \(title)")
            return
        }

        guard isAvailable else {
            cmuxLog("[notify] No libnotify — urgency hint only: \(title)")
            return
        }

        let displayTitle = title.isEmpty ? "cmux" : title
        let displayBody = body.isEmpty ? nil : body

        guard let notification = fn_notify_notification_new?(
            displayTitle,
            displayBody,
            "utilities-terminal"  // freedesktop icon name
        ) else {
            cmuxLog("[notify] Failed to create notification")
            return
        }

        // 5 second timeout
        fn_notify_notification_set_timeout?(notification, 5000)
        // Normal urgency
        fn_notify_notification_set_urgency?(notification, 1)

        let shown = fn_notify_notification_show?(notification, nil) ?? 0
        fn_g_object_unref?(notification)

        cmuxLog("[notify] Posted: \(displayTitle) — shown=\(shown != 0)")
    }

    /// Handle terminal bell — urgency hint + optional notification
    func bell() {
        // Play system bell sound
        if let display = gdk_display_get_default() {
            gdk_display_beep(display)
        }

        // Only show desktop notification if window is not focused
        if !windowIsFocused && isAvailable {
            post(title: "cmux", body: "Terminal bell")
        }
    }

    // MARK: - Urgency / Focus

    /// Clear urgency when the window gains focus
    func clearUrgency() {
        windowIsFocused = true
    }

    /// Mark window as unfocused
    func windowLostFocus() {
        windowIsFocused = false
    }
}
