# Window Management Design

**Last Updated**: 2026-03-26

## Architecture

Window management in cmux bridges SwiftUI's declarative UI model with AppKit's imperative window system. The architecture uses several layers:

1. **SwiftUI Layer**: Declarative views for content, sidebar, panels
2. **Bridge Layer**: `WindowAccessor`, `WindowDragHandleView` (NSViewRepresentable wrappers)
3. **AppKit Controller Layer**: `WindowDecorationsController`, `WindowToolbarController`
4. **Portal Layer**: `WindowTerminalHostView`, `BrowserWindowPortal` (direct NSView/WKWebView hosting)

## Key Components

### WindowAccessor
- `NSViewRepresentable` that observes `viewWillMove(toWindow:)` and `viewDidMoveToWindow()`
- Deduplication via `Coordinator.lastWindow` weak reference
- Enables SwiftUI views to configure their hosting NSWindow

### WindowDecorationsController
- Singleton-style controller started once at app launch
- Observes `NSWindow.didBecomeKeyNotification` / `didBecomeMainNotification`
- Manages traffic light visibility based on window type (sheet, modal panel, etc.)
- Caches base frames for traffic light buttons to apply custom offsets

### WindowToolbarController
- NSToolbarDelegate that creates a unified compact toolbar per window
- Displays "Cmd: <focused command title>" with coalesced updates (30fps via NotificationBurstCoalescer)
- Observes `.ghosttyDidSetTitle`, `.ghosttyDidFocusTab`, and window-main notifications

### WindowDragHandleView
- Transparent NSView with custom `hitTest` and `mouseDown`
- Hit-test logic:
  1. Check drag suppression (associated object on NSWindow)
  2. Only resolve for `leftMouseDown` events from the correct window
  3. Walk sibling views in reverse z-order; yield if any non-passive sibling claims the hit
  4. Capture if no sibling claims it
- Mouse-down logic: double-click triggers standard titlebar action; single-click initiates `window.performDrag(with:)` with temporary movability

### Drag Suppression
- Reference-counted depth via ObjC associated objects (`beginWindowDragSuppression` / `endWindowDragSuppression`)
- Prevents window drag during sidebar tab reorder or other interactive gestures
- Automatic recovery: stale suppression cleared when left mouse button is released

### Terminal Window Portal (WindowTerminalHostView)
- NSView subclass hosting Ghostty terminal surfaces at the AppKit layer
- Manages cursor rect registration for split divider regions
- Routes pointer events based on sidebar edge detection and divider proximity

### Browser Window Portal
- Manages WKWebView lifecycle at the AppKit layer
- Handles rendering state suspension when views are hidden during workspace switches
- Uses WebKit private API for proper GPU resource management

## Platform Abstraction

This is entirely macOS-specific. A Linux port would need:

| macOS Component | Linux Equivalent |
|----------------|-----------------|
| NSWindow + NSToolbar | GTK Window / Wayland toplevel |
| Traffic lights | Window manager decorations (typically CSD or SSD) |
| NSView hitTest/portal | GTK widget tree / direct Wayland surface |
| WKWebView hosting | WebKitGTK or CEF |
| ObjC associated objects | Widget data attachment mechanism |

## Data Flow

```
App Launch
  -> WindowDecorationsController.start()
  -> WindowToolbarController.start(tabManager:)

New Window Created
  -> WindowAccessor fires onWindow callback
  -> WindowToolbarController.attach(to:) installs toolbar
  -> WindowDecorationsController.apply(to:) configures traffic lights

User Interaction in Titlebar
  -> WindowDragHandleView.hitTest checks suppression, bounds, siblings
  -> If captured: mouseDown triggers drag or double-click action
  -> If yielded: event passes through to interactive control

Workspace Switch
  -> Terminal portal updates hosted Ghostty surface
  -> Browser portal suspends/reattaches WKWebView rendering state
```

## Dependencies

- AppKit (NSWindow, NSView, NSToolbar, NSEvent)
- SwiftUI (NSViewRepresentable bridge)
- Bonsplit (split container framework, used in portal views)
- ObjectiveC runtime (associated objects for drag suppression)
- WebKit (WKWebView in browser portal)
