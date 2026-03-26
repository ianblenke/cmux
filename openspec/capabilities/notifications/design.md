# Notifications Design

**Last Updated**: 2026-03-26

## Architecture

The notification system is split across two source files:
- `Sources/TerminalNotificationStore.swift` — Core store, system delivery, sound settings, dock badge, authorization
- `Sources/NotificationsPage.swift` — SwiftUI sidebar UI for viewing and managing notifications

The store is a `@MainActor` singleton that acts as the single source of truth for all notification state. It publishes changes via `@Published` properties for SwiftUI reactivity.

## Key Components

### TerminalNotification
Simple value type: `(id: UUID, tabId: UUID, surfaceId: UUID?, title: String, subtitle: String, body: String, createdAt: Date, isRead: Bool)`. Conforms to `Identifiable` and `Hashable`.

### TerminalNotificationStore
- **Singleton**: `TerminalNotificationStore.shared`
- **Published state**: `notifications` array, `focusedReadIndicatorByTabId` dict, `authorizationState`
- **Computed indexes**: `NotificationIndexes` struct rebuilt on every mutation, tracking unread count, unread count per tab, unread by tab+surface, latest unread per tab
- **Delivery decision**: If app is focused AND notification's tab+surface is the focused pane, suppress system delivery and show focused read indicator instead
- **System delivery**: Via `UNUserNotificationCenter` with configurable sound and category/action
- **Dock badge**: Computed label combining optional run tag with unread count (caps at "99+")

### NotificationSoundSettings
- 15 system sounds + custom file + none
- Custom file staging: copies/transcodes to `~/Library/Sounds/` with content-hash filenames
- Source metadata tracking: re-stages when source file changes (size/modification time/inode)
- Supported formats: aif, aiff, caf, wav (others transcoded to CAF)
- Background preparation queue for transcoding

### NotificationsPage
- SwiftUI view with header (title, jump-to-unread button, clear-all button)
- Scrollable `LazyVStack` of `NotificationRow` items
- Each row: unread dot, title, body (3-line limit), tab title, timestamp, clear (x) button
- Focus management with `@FocusState` for keyboard navigation
- Configurable jump-to-unread keyboard shortcut via `@AppStorage`

### Authorization Flow
- Tracks `NotificationAuthorizationState` (unknown/authorized/denied/provisional/ephemeral)
- Auto-requests on first notification delivery
- Settings button triggers explicit request
- Denied state: prompts user to open System Preferences notification settings
- Window provider, alert factory, and scheduler are injectable for testing

## Platform Abstraction

| Component | macOS | Linux |
|-----------|-------|-------|
| System notifications | UNUserNotificationCenter | libnotify / D-Bus |
| Notification sound | UNNotificationSound + NSSound | PulseAudio/PipeWire |
| Custom sound staging | ~/Library/Sounds/ | $XDG_DATA_HOME/sounds/ |
| Dock badge | NSApp.dockTile.badgeLabel | DE-specific (Unity, KDE) |
| Authorization | UNAuthorizationStatus | Not applicable (no auth needed) |
| UI | SwiftUI NotificationsPage | GTK or web-based equivalent |

Platform-independent (shared directly):
- `TerminalNotification` model
- Notification array management (add/remove/mark/clear)
- Deduplication logic (replace by tabId+surfaceId)
- Read/unread index computation
- Focused panel suppression decision
- Badge label computation

## Data Flow

### Notification Arrival
```
Terminal OSC 9/777 event
    |
    v
AppDelegate / Ghostty callback
    |
    v
TerminalNotificationStore.addNotification(tabId:, surfaceId:, title:, subtitle:, body:)
    |
    +--> Remove existing notification for same (tabId, surfaceId)
    +--> Check: is app focused AND is this the focused pane?
    |     |
    |     +--> YES: set focused read indicator + play suppressed feedback
    |     +--> NO:  schedule UNUserNotification + auto-reorder workspace
    |
    +--> Insert new notification at index 0
    +--> Rebuild indexes (unread counts)
    +--> Refresh dock badge
    +--> @Published triggers SwiftUI update
```

### User Interaction
```
NotificationsPage
    |
    +--> Tap notification row --> openNotification(tabId, surfaceId, notificationId)
    |                              --> activate window, select tab, switch sidebar to tabs
    |
    +--> Tap X on row --> store.remove(id:) --> clear from array + system notifications
    |
    +--> "Clear All" --> store.clearAll() --> empty array + clear all system notifications
    |
    +--> "Jump to Latest Unread" --> AppDelegate.jumpToLatestUnread()
                                      --> find latest unread, activate its tab
```

### System Notification Callback
```
User taps system notification banner / clicks "Show" action
    |
    v
UNUserNotificationCenter delegate
    |
    v
AppDelegate.openNotification(tabId:, surfaceId:, notificationId:)
    |
    +--> Activate window containing tab
    +--> Select tab in TabManager
    +--> Mark notification as read
```

## Dependencies

- **UserNotifications** — UNUserNotificationCenter, UNNotificationSound, UNMutableNotificationContent
- **AppKit** — NSApp.dockTile, NSSound, NSAlert, NSWorkspace
- **SwiftUI** — NotificationsPage view, @Published, @EnvironmentObject
- **Bonsplit** — SidebarSelection, TabManager
- **Foundation** — UserDefaults, FileManager, DispatchQueue
