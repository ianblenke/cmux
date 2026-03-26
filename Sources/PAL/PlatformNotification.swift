// Platform Abstraction Layer — System Notifications
// REQ-XP-002: PAL protocol definitions

import Foundation

/// Abstracts system-level notification delivery (UNUserNotificationCenter / libnotify).
public protocol PlatformNotificationService {
    /// Post a system notification.
    func post(title: String, body: String, identifier: String)

    /// Request notification permission from the user.
    func requestPermission(completion: @escaping (Bool) -> Void)

    /// Whether notification permission has been granted.
    var isAuthorized: Bool { get }

    /// Set the application dock/taskbar badge count.
    func setBadgeCount(_ count: Int)
}
