# Notifications Specification

**Status**: EXTRACTED
**Last Updated**: 2026-03-26

## Overview

The notifications system captures terminal desktop notifications (OSC 9/777), stores them in an in-app notification center with read/unread tracking, delivers them via macOS UNUserNotificationCenter, and provides a sidebar notifications page with jump-to-unread navigation.

## Requirements

### REQ-NT-001: Notification model
- **Description**: `TerminalNotification` captures id (UUID), tabId, optional surfaceId, title, subtitle, body, createdAt timestamp, and isRead flag. Conforms to Identifiable and Hashable.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-NT-002: In-app notification store
- **Description**: `TerminalNotificationStore` is a singleton `@MainActor ObservableObject` that maintains an ordered array of notifications (newest first) with computed indexes for unread counts per tab and surface.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-NT-003: Add notification with deduplication
- **Description**: `addNotification` replaces any existing notification for the same (tabId, surfaceId) pair, clears the old system notification, and inserts the new one at the front. If the notification's tab/surface is currently focused and the app is active, delivery is suppressed (in-app only).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-NT-004: Read/unread state management
- **Description**: Supports `markRead(id:)`, `markRead(forTabId:)`, `markRead(forTabId:surfaceId:)`, `markUnread(forTabId:)`, and `markAllRead()`. Each marks updates the notification array and clears delivered system notifications.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-NT-005: Notification removal
- **Description**: `remove(id:)` removes a single notification. `clearAll()` clears all notifications and focused read indicators. `clearNotifications(forTabId:)` and `clearNotifications(forTabId:surfaceId:)` clear scoped subsets.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-NT-006: System notification delivery
- **Description**: When delivery is not suppressed, notifications are scheduled via `UNUserNotificationCenter` with a category identifier (`com.cmuxterm.app.userNotification`) and a "Show" action. Sound is configurable.
- **Platform**: macOS-only (UNUserNotificationCenter)
- **Status**: Implemented
- **Priority**: P0

### REQ-NT-007: Notification sound configuration
- **Description**: `NotificationSoundSettings` supports system sounds (Default, Basso, Blow, etc.), custom sound files (aif/aiff/caf/wav with staging to ~/Library/Sounds), a custom command option, and "None". Custom files are transcoded to CAF if needed and staged with source metadata tracking.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-NT-008: Dock badge
- **Description**: `dockBadgeLabel` renders unread count on the dock icon. Caps at "99+". Supports tagged run badge combining run tag with unread count. Badge updates on every notification change and UserDefaults change. Configurable via `NotificationBadgeSettings`.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-NT-009: Focused read indicator
- **Description**: When a notification arrives for the currently focused tab/surface while the app is active, a transient "focused read indicator" is shown instead of a system notification. Indicators are tracked per tab and cleared on surface change.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-NT-010: Notification authorization management
- **Description**: Tracks `authorizationState` (unknown/authorized/denied/provisional). Requests authorization on first notification delivery and from settings button. Handles denied state by prompting user to open System Preferences.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-NT-011: Off-main-thread removal
- **Description**: `removeDeliveredNotificationsOffMain` and `removePendingNotificationRequestsOffMain` dispatch removal calls to a utility queue to prevent UI freezes from slow `usernoted` XPC calls.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-NT-012: Notifications page UI
- **Description**: `NotificationsPage` SwiftUI view displays notifications in a scrollable list with unread dot indicators, notification title/body/timestamp, tab title, open and clear actions. Empty state shows "No notifications yet" message.
- **Platform**: macOS-only (SwiftUI)
- **Status**: Implemented
- **Priority**: P0

### REQ-NT-013: Jump to unread
- **Description**: "Jump to Latest Unread" button navigates to the tab/surface of the most recent unread notification, switches sidebar to tabs view, and activates the window. Keyboard shortcut is configurable.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-NT-014: Clear all button
- **Description**: "Clear All" button in the notifications page header removes all notifications from the store and clears all system-delivered notifications.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-NT-015: Workspace auto-reorder on notification
- **Description**: When `WorkspaceAutoReorderSettings.isEnabled()`, receiving a notification moves the associated tab to the top of the workspace list.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P2

### REQ-NT-016: Suppressed notification feedback
- **Description**: When system delivery is suppressed (focused panel), in-app audio/visual feedback is provided via `playSuppressedNotificationFeedback`.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P2

### REQ-NT-017: Pane flash on notification
- **Description**: Configurable pane flash visual effect when a notification arrives. Default enabled, togglable via `NotificationBadgeSettings`.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2

## Scenarios

### SCENARIO-NT-001: Dock badge count
- **Given**: Dock badge is enabled
- **When**: 1 unread notification exists
- **Then**: Badge shows "1"; at 100+ shows "99+"
- **Verifies**: REQ-NT-008
- **Status**: Covered

### SCENARIO-NT-002: Badge hidden when disabled
- **Given**: Dock badge is disabled in settings
- **When**: 5 unread notifications exist
- **Then**: Badge is nil (hidden)
- **Verifies**: REQ-NT-008
- **Status**: Covered

### SCENARIO-NT-003: Run tag badge
- **Given**: A tagged debug run with tag "verify-tag"
- **When**: No unread notifications
- **Then**: Badge shows "verify-tag"; with 7 unread shows "verify:7"
- **Verifies**: REQ-NT-008
- **Status**: Covered

### SCENARIO-NT-004: Notification dedup by tab+surface
- **Given**: A notification exists for (tabA, surfaceB)
- **When**: A new notification arrives for the same (tabA, surfaceB)
- **Then**: The old notification is removed and replaced; old system notification is cleared
- **Verifies**: REQ-NT-003
- **Status**: Covered

### SCENARIO-NT-005: Focused panel suppresses system delivery
- **Given**: The app is focused and the notification's tab/surface is active
- **When**: A notification arrives
- **Then**: System notification is not delivered; in-app focused read indicator is set instead
- **Verifies**: REQ-NT-009, REQ-NT-016
- **Status**: Covered

### SCENARIO-NT-006: Jump to latest unread
- **Given**: Multiple unread notifications across different tabs
- **When**: User clicks "Jump to Latest Unread"
- **Then**: The most recent unread notification's tab is activated and sidebar switches to tabs
- **Verifies**: REQ-NT-013
- **Status**: Covered

### SCENARIO-NT-007: Clear all notifications
- **Given**: Several notifications exist
- **When**: User clicks "Clear All"
- **Then**: All notifications removed from store, all system notifications cleared
- **Verifies**: REQ-NT-014
- **Status**: Covered

### SCENARIO-NT-008: Notification badge preference default
- **Given**: Fresh UserDefaults (no badge preference set)
- **When**: `isDockBadgeEnabled` is checked
- **Then**: Returns true (defaults to enabled)
- **Verifies**: REQ-NT-008
- **Status**: Covered

## Cross-Platform Notes

- **UNUserNotificationCenter** is macOS/iOS only. Linux requires `libnotify` / D-Bus `org.freedesktop.Notifications`.
- **Dock badge** is macOS-specific. Linux equivalent depends on desktop environment (Unity launcher count, KDE task manager badge).
- **NSSound** for notification sounds needs replacement with PulseAudio/PipeWire or GStreamer on Linux.
- **Custom sound staging to ~/Library/Sounds** is macOS-specific. Linux custom sounds go to `$XDG_DATA_HOME/sounds/` or are played directly.
- **NotificationsPage SwiftUI** view needs GTK equivalent for Linux.
- Core notification model, store logic, read/unread tracking, and deduplication are fully platform-independent.

## Implementation Status

| Requirement | Status | Notes |
|-------------|--------|-------|
| REQ-NT-001 | Implemented | TerminalNotification struct |
| REQ-NT-002 | Implemented | TerminalNotificationStore singleton |
| REQ-NT-003 | Implemented | addNotification with dedup |
| REQ-NT-004 | Implemented | markRead/markUnread variants |
| REQ-NT-005 | Implemented | remove/clearAll/clearNotifications |
| REQ-NT-006 | Implemented | UNUserNotificationCenter |
| REQ-NT-007 | Implemented | NotificationSoundSettings |
| REQ-NT-008 | Implemented | dockBadgeLabel |
| REQ-NT-009 | Implemented | focusedReadIndicator |
| REQ-NT-010 | Implemented | authorizationState management |
| REQ-NT-011 | Implemented | Off-main-thread removal |
| REQ-NT-012 | Implemented | NotificationsPage view |
| REQ-NT-013 | Implemented | Jump to unread |
| REQ-NT-014 | Implemented | Clear all |
| REQ-NT-015 | Implemented | Auto-reorder setting |
| REQ-NT-016 | Implemented | Suppressed feedback |
| REQ-NT-017 | Implemented | Pane flash setting |
