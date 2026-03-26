# Window Management Specification

**Status**: EXTRACTED
**Last Updated**: 2026-03-26

## Overview

Manages macOS window chrome, toolbar, traffic light positioning, titlebar drag handling, and AppKit portal hosting for terminal and browser surfaces within cmux windows.

## Requirements

### REQ-WM-001: Window Accessor (SwiftUI-to-NSWindow Bridge)
- **Description**: `WindowAccessor` is an `NSViewRepresentable` that provides SwiftUI views with a reference to their hosting `NSWindow` via a callback. Supports deduplication to avoid redundant callbacks when the window reference hasn't changed.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-WM-002: Window Decorations Controller
- **Description**: `WindowDecorationsController` manages traffic light button visibility and positioning. Hides standard buttons on sheets, doc-modal windows, and non-activating panels. Applies custom offsets for the Settings window. Responds to window become-key/main notifications.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-WM-003: Window Toolbar Controller
- **Description**: `WindowToolbarController` attaches a compact unified toolbar to each window displaying the focused terminal's command title. Updates are coalesced (30fps) to avoid excessive redraws during rapid title changes.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-WM-004: Titlebar Drag Handle
- **Description**: `WindowDragHandleView` provides a transparent view that captures mouse-down events in empty titlebar space to enable window dragging while keeping `isMovableByWindowBackground = false`. It performs sibling hit-testing to yield to interactive controls (buttons, icons) layered in the titlebar.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-WM-005: Titlebar Double-Click Action
- **Description**: Double-clicking in the titlebar area triggers the standard macOS action (zoom, minimize, or none) based on `AppleActionOnDoubleClick` / `AppleMiniaturizeOnDoubleClick` user defaults. A separate `TitlebarDoubleClickMonitorView` ensures double-clicks work even when hosted by SwiftUI container views.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-WM-006: Window Drag Suppression
- **Description**: A reference-counted suppression mechanism prevents window drags during sidebar tab reordering or other interactive gestures. Suppression is tracked via ObjC associated objects on the NSWindow. Stale suppression is automatically cleared when the left mouse button is released.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-WM-007: Re-entrancy Guard for Hit Testing
- **Description**: The sibling hit-test walk in `windowDragHandleShouldCaptureHit` is protected by a re-entrancy guard to prevent Swift exclusive-access violations when SwiftUI view-body evaluation triggers recursive `hitTest` calls.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-WM-008: Terminal Window Portal (AppKit Hosting)
- **Description**: `WindowTerminalHostView` hosts Ghostty terminal surfaces at the AppKit layer for correct z-ordering during split/workspace transitions. Manages cursor rects for split divider regions and routes pointer events to sidebar/drag handles.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-WM-009: Browser Window Portal (WebView Hosting)
- **Description**: `BrowserWindowPortal` manages WKWebView instances at the AppKit layer, handling rendering state suspension/reattachment when views are hidden/shown during workspace switches. Uses private API calls (`viewDidHide`, `_exitInWindow`) to properly suspend WebKit rendering.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-WM-010: Temporary Window Movability
- **Description**: `withTemporaryWindowMovableEnabled` temporarily sets `window.isMovable = true` for explicit drag-handle drags, then restores the previous movability state. This allows window dragging from the titlebar while keeping the window non-movable-by-background for content drags.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

## Scenarios

### SCENARIO-WM-001: Window Accessor Deduplication
- **Given**: A `WindowAccessor` with `dedupeByWindow: true`
- **When**: The view moves to the same window twice
- **Then**: The callback fires only once
- **Verifies**: REQ-WM-001
- **Status**: Covered

### SCENARIO-WM-002: Traffic Lights Hidden on Sheet
- **Given**: A window presented as a sheet
- **When**: `WindowDecorationsController.apply(to:)` is called
- **Then**: Close, miniaturize, and zoom buttons are hidden
- **Verifies**: REQ-WM-002
- **Status**: Missing

### SCENARIO-WM-003: Titlebar Drag Yields to Sibling Control
- **Given**: A drag handle view with an interactive button sibling
- **When**: `windowDragHandleShouldCaptureHit` is called at the button's location
- **Then**: Returns false, allowing the button to handle the event
- **Verifies**: REQ-WM-004
- **Status**: Covered

### SCENARIO-WM-004: Standard Double-Click Zoom Action
- **Given**: Default macOS user preferences (no custom AppleActionOnDoubleClick)
- **When**: `resolvedStandardTitlebarDoubleClickAction` is called
- **Then**: Returns `.zoom`
- **Verifies**: REQ-WM-005
- **Status**: Covered

### SCENARIO-WM-005: Double-Click Miniaturize When Preference Set
- **Given**: `AppleActionOnDoubleClick` set to "Minimize"
- **When**: `resolvedStandardTitlebarDoubleClickAction` is called
- **Then**: Returns `.miniaturize`
- **Verifies**: REQ-WM-005
- **Status**: Covered

### SCENARIO-WM-006: Drag Suppression During Tab Reorder
- **Given**: A window with drag suppression active (depth > 0)
- **When**: `windowDragHandleShouldCaptureHit` is called while left mouse is down
- **Then**: Returns false, preventing window drag
- **Verifies**: REQ-WM-006
- **Status**: Covered

### SCENARIO-WM-007: Stale Drag Suppression Recovery
- **Given**: A window with stale drag suppression (left mouse released)
- **When**: `windowDragHandleShouldCaptureHit` is called
- **Then**: Suppression is cleared and hit resolution proceeds normally
- **Verifies**: REQ-WM-006
- **Status**: Covered

### SCENARIO-WM-008: Window Registration and Context Routing
- **Given**: Multiple main windows registered with the app delegate
- **When**: `synchronizeActiveMainWindowContext` is called with a preferred window
- **Then**: The preferred window's tab manager is used rather than a stale active manager
- **Verifies**: REQ-WM-001, REQ-WM-008
- **Status**: Covered

## Cross-Platform Notes

- All window management code is deeply macOS-specific (NSWindow, NSView, NSToolbar, AppKit portals).
- Linux port will require a completely different windowing implementation (likely GTK or a Wayland compositor integration).
- The concepts of traffic lights, toolbar, and titlebar drag are macOS-specific UI patterns.
- Platform abstraction should define a `WindowManagement` protocol that each platform implements independently.

## Implementation Status

| Requirement | Status | Test Coverage |
|-------------|--------|--------------|
| REQ-WM-001 | Implemented | WindowAndDragTests |
| REQ-WM-002 | Implemented | Manual testing |
| REQ-WM-003 | Implemented | Manual testing |
| REQ-WM-004 | Implemented | WindowAndDragTests |
| REQ-WM-005 | Implemented | WindowAndDragTests |
| REQ-WM-006 | Implemented | WindowAndDragTests |
| REQ-WM-007 | Implemented | WindowAndDragTests |
| REQ-WM-008 | Implemented | WindowAndDragTests |
| REQ-WM-009 | Implemented | Manual testing |
| REQ-WM-010 | Implemented | WindowAndDragTests |
