# Keyboard Shortcuts Specification

**Status**: EXTRACTED
**Last Updated**: 2026-03-26

## Overview

User-customizable keyboard shortcut system supporting 30+ actions across navigation, splits, panels, and UI controls. Shortcuts are persisted in UserDefaults, recordable via a custom recorder widget, and matched against events using keyboard layout-aware character resolution for international input methods.

## Requirements

### REQ-KS-001: Action Registry
- **Description**: All customizable shortcuts are defined as cases of `KeyboardShortcutSettings.Action` enum. Each action has a stable `rawValue` string, a localized `label`, a `defaultsKey` for UserDefaults persistence, and a `defaultShortcut` definition.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-KS-002: Supported Actions
- **Description**: The system supports the following action categories:
  - **Titlebar/UI**: toggleSidebar, newTab, newWindow, closeWindow, openFolder, sendFeedback, showNotifications, jumpToUnread, triggerFlash
  - **Navigation**: nextSurface, prevSurface, selectSurfaceByNumber, nextSidebarTab, prevSidebarTab, selectWorkspaceByNumber, renameTab, renameWorkspace, closeWorkspace, newSurface, toggleTerminalCopyMode
  - **Panes/Splits**: focusLeft, focusRight, focusUp, focusDown, splitRight, splitDown, toggleSplitZoom, splitBrowserRight, splitBrowserDown
  - **Panels**: openBrowser, toggleBrowserDeveloperTools, showBrowserJavaScriptConsole
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-KS-003: Default Shortcut Definitions
- **Description**: Every action has a default shortcut. Examples: toggleSidebar=Cmd+B, newTab=Cmd+N, newWindow=Cmd+Shift+N, splitRight=Cmd+D, focusLeft=Cmd+Option+Left, selectWorkspaceByNumber=Cmd+1-9, selectSurfaceByNumber=Ctrl+1-9.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-KS-004: UserDefaults Persistence
- **Description**: Custom shortcuts are stored as JSON-encoded `StoredShortcut` values in UserDefaults under action-specific keys (e.g., "shortcut.toggleSidebar"). When no custom value exists, the default shortcut is returned.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-KS-005: Shortcut Change Notifications
- **Description**: When a shortcut is set or reset, a `cmux.keyboardShortcutSettingsDidChange` notification is posted (with optional `action` in userInfo). This allows menu items and other UI to update their key equivalents.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-KS-006: Reset Individual and All Shortcuts
- **Description**: `resetShortcut(for:)` removes a single action's custom shortcut. `resetAll()` removes all custom shortcuts, restoring defaults for every action.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-KS-007: StoredShortcut Data Model
- **Description**: `StoredShortcut` stores: `key` (String), `command` (Bool), `shift` (Bool), `option` (Bool), `control` (Bool). It is Codable and Equatable. It provides computed properties: `displayString`, `modifierDisplayString`, `keyDisplayString`, `modifierFlags`, `keyEquivalent`, `eventModifiers`, `menuItemKeyEquivalent`.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-KS-008: Key Display Formatting
- **Description**: Modifier symbols use standard macOS notation: Control=`^`, Option=`a`, Shift=`^`, Command=`^`. Special keys: Tab="TAB", Return="↩", arrows use Unicode arrows. Keys are uppercased for display.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-KS-009: Numbered Digit Matching
- **Description**: `selectSurfaceByNumber` and `selectWorkspaceByNumber` actions use numbered digit matching: any digit 1-9 recorded during shortcut recording is normalized to "1" for storage, and displayed as "1...9". Non-digit keys are rejected for these actions.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-KS-010: Shortcut Recorder Widget
- **Description**: `KeyboardShortcutRecorder` provides a SwiftUI view with a label and a recorder button. Clicking the button enters recording mode ("Press shortcut..."), capturing the next key event. Escape cancels recording. Events without at least one modifier are rejected. Window resign also stops recording.
- **Platform**: macOS-only (NSEvent monitoring)
- **Status**: Implemented
- **Priority**: P0

### REQ-KS-011: Event-to-StoredShortcut Conversion
- **Description**: `StoredShortcut.from(event:)` converts an NSEvent to a StoredShortcut. It prefers keyCode mapping for symbol keys (brackets, minus, equals, punctuation) so shifted symbols record as their base key. Letters and numbers use `charactersIgnoringModifiers`. Events with no modifiers return nil.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-KS-012: Keyboard Layout Character Resolution
- **Description**: `KeyboardLayout.character(forKeyCode:modifierFlags:)` translates physical key codes to characters using the current keyboard input source's Unicode layout data via `UCKeyTranslate`. If the result is non-ASCII (e.g., CJK or Korean input), it falls back to `TISCopyCurrentASCIICapableKeyboardInputSource`.
- **Platform**: macOS-only (Carbon TIS/UCKey APIs)
- **Status**: Implemented
- **Priority**: P0

### REQ-KS-013: Normalized Characters for Event Matching
- **Description**: `KeyboardLayout.normalizedCharacters(for:)` returns ASCII-normalized characters for an NSEvent. If `charactersIgnoringModifiers` is already ASCII, it returns as-is. Otherwise, it uses layout character resolution. This is used throughout shortcut matching to handle non-Latin input methods.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-KS-014: Command-Aware Layout Support
- **Description**: The keyboard layout resolution respects command-aware layouts (e.g., "Dvorak - QWERTY Command") by passing the command modifier flag to UCKeyTranslate. This ensures Cmd+key shortcuts use QWERTY positions even on Dvorak.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-KS-015: AppDelegate Shortcut Routing
- **Description**: `AppDelegate` intercepts key events via `performKeyEquivalent` and a local event monitor. Custom shortcuts are matched against the registered actions. The routing uses the event's window context (not the active/focused window) to determine which tab manager receives the action.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-KS-016: Event Window Context for Multi-Window
- **Description**: When handling shortcuts like Cmd+N, the system uses the event's `windowNumber` to find the correct tab manager, even if a different window is the "active" manager. This prevents actions from being applied to the wrong window.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-KS-017: Full-Screen Toggle Shortcut
- **Description**: Cmd+Ctrl+F toggles full-screen on the main window. The shortcut matches by key code (3) with fallback through keyboard layout resolution when `charactersIgnoringModifiers` is empty or non-ASCII.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-KS-018: Split Shortcut Transient Focus Guard
- **Description**: Split shortcuts are suppressed when the first responder has fallen back to the window itself and the hosted view is either tiny (< 80px width) or detached from a window. This prevents accidental splits during workspace creation/transition.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2

### REQ-KS-019: Menu Key Equivalent Synchronization
- **Description**: Menu items update their key equivalents when shortcuts change (via the change notification). This ensures the menu bar displays the current custom shortcuts.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-KS-020: Backwards-Compatible API
- **Description**: Static convenience methods (e.g., `focusLeftShortcut()`, `showNotificationsShortcut()`) and key constants (e.g., `focusLeftKey`) provide a migration path for call sites that haven't adopted the Action-based API.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P2

### REQ-KS-021: Debug Input Source Override
- **Description**: In DEBUG builds, `KeyboardLayout.debugInputSourceIdOverride` allows tests to override the current input source ID for keyboard layout testing.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2

## Scenarios

### SCENARIO-KS-001: Cmd+N Creates Workspace in Event's Window
- **Given**: Two windows are open, the first is active/focused
- **When**: A Cmd+N event is dispatched with the second window's windowNumber
- **Then**: A new workspace is created in the second window, not the first
- **Verifies**: REQ-KS-015, REQ-KS-016
- **Status**: Covered

### SCENARIO-KS-002: Custom Shortcut Persists Across Sessions
- **Given**: User sets toggleSidebar to Cmd+Shift+B
- **When**: The app restarts
- **Then**: `shortcut(for: .toggleSidebar)` returns Cmd+Shift+B
- **Verifies**: REQ-KS-004
- **Status**: Partial (persistence tested, restart not automated)

### SCENARIO-KS-003: Reset All Restores Defaults
- **Given**: Multiple shortcuts have been customized
- **When**: `resetAll()` is called
- **Then**: All actions return their default shortcuts
- **Verifies**: REQ-KS-006
- **Status**: Covered (via test setUp/tearDown)

### SCENARIO-KS-004: Numbered Digit Normalization
- **Given**: User records Ctrl+5 for selectSurfaceByNumber
- **When**: The shortcut is stored
- **Then**: The stored key is "1" (normalized), and display shows "Ctrl+1...9"
- **Verifies**: REQ-KS-009
- **Status**: Missing (no isolated test)

### SCENARIO-KS-005: Non-Digit Rejected for Number Actions
- **Given**: User attempts to record Ctrl+A for selectSurfaceByNumber
- **When**: The shortcut is evaluated
- **Then**: The recording is rejected (nil returned)
- **Verifies**: REQ-KS-009
- **Status**: Missing

### SCENARIO-KS-006: Cmd+Ctrl+F Toggles Full Screen
- **Given**: The main window is not full screen
- **When**: Cmd+Ctrl+F is pressed
- **Then**: The window enters full screen
- **Verifies**: REQ-KS-017
- **Status**: Covered

### SCENARIO-KS-007: Full Screen Shortcut Works with Non-Latin Input
- **Given**: A CJK input method is active
- **When**: Cmd+Ctrl+F is pressed (keyCode 3)
- **Then**: Full screen toggles correctly via keyCode fallback
- **Verifies**: REQ-KS-012, REQ-KS-017
- **Status**: Covered

### SCENARIO-KS-008: Split Suppressed During Workspace Transition
- **Given**: A workspace is being created, the hosted view is tiny
- **When**: A split shortcut is triggered
- **Then**: The split is suppressed to avoid accidental splits
- **Verifies**: REQ-KS-018
- **Status**: Covered

### SCENARIO-KS-009: Cmd+N Works When WebView Is Focused
- **Given**: A browser panel is focused in a workspace
- **When**: Cmd+N is pressed
- **Then**: A new workspace is created (the shortcut is not consumed by WebView)
- **Verifies**: REQ-KS-015
- **Status**: Covered (UI test)

### SCENARIO-KS-010: Cmd+W Works When WebView Is Focused
- **Given**: A browser panel is focused after tab switching
- **When**: Cmd+Shift+W is pressed
- **Then**: The workspace closes (the shortcut is not consumed by WebView)
- **Verifies**: REQ-KS-015
- **Status**: Covered (UI test)

### SCENARIO-KS-011: Korean Input Method Shortcut Matching
- **Given**: Korean 두벌식 input method is active
- **When**: Cmd+B is pressed (keyCode for B)
- **Then**: toggleSidebar is triggered despite UCKeyTranslate returning Hangul, via ASCII fallback
- **Verifies**: REQ-KS-012, REQ-KS-013
- **Status**: Covered (unit test with debug override)

### SCENARIO-KS-012: Dvorak QWERTY Command Layout
- **Given**: "Dvorak - QWERTY Command" layout is active
- **When**: Cmd+key is pressed
- **Then**: The QWERTY position is used for matching, not the Dvorak position
- **Verifies**: REQ-KS-014
- **Status**: Partial (architecture supports it; specific layout test may be missing)

### SCENARIO-KS-013: Shortcut Change Notification Fires
- **Given**: A shortcut change listener is registered
- **When**: `setShortcut()` is called for an action
- **Then**: `cmux.keyboardShortcutSettingsDidChange` notification fires with the action in userInfo
- **Verifies**: REQ-KS-005
- **Status**: Missing (no isolated notification test)

### SCENARIO-KS-014: StoredShortcut Display String
- **Given**: A shortcut with command=true, shift=true, key="d"
- **When**: `displayString` is accessed
- **Then**: Result is "^`^`D" (shift+command+D)
- **Verifies**: REQ-KS-008
- **Status**: Missing (no isolated display string test)

### SCENARIO-KS-015: Event Without Modifiers Rejected
- **Given**: A key event for "a" with no modifier flags
- **When**: `StoredShortcut.from(event:)` is called
- **Then**: Returns nil (plain typing not recordable)
- **Verifies**: REQ-KS-011
- **Status**: Missing

## Cross-Platform Notes

- Keyboard layout resolution uses Carbon TIS APIs (`TISCopyCurrentKeyboardInputSource`, `UCKeyTranslate`) which are macOS-only. Linux would need `xkbcommon` or direct X11/Wayland keymap queries.
- `NSEvent` monitoring for shortcut interception is macOS-only. Linux would use X11/Wayland key event hooks.
- The `StoredShortcut` model, `Action` enum, defaults persistence, and change notification are portable.
- Menu key equivalent synchronization is AppKit-specific; Linux would need GTK/Qt menu integration.
- The `KeyboardShortcutRecorder` widget uses `NSEvent.addLocalMonitorForEvents` and `NSButton` subclassing; Linux would need a GTK/Qt equivalent.

## Implementation Status

| Component | File | Status |
|-----------|------|--------|
| KeyboardShortcutSettings (actions, persistence) | Sources/KeyboardShortcutSettings.swift | Complete |
| StoredShortcut (model, display, conversion) | Sources/KeyboardShortcutSettings.swift | Complete |
| KeyboardShortcutRecorder (UI widget) | Sources/KeyboardShortcutSettings.swift | Complete |
| KeyboardLayout (TIS/UCKey resolution) | Sources/KeyboardLayout.swift | Complete |
| AppDelegate shortcut routing | Sources/AppDelegate.swift | Complete |
