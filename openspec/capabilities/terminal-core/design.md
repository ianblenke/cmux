# Terminal Core Design

**Last Updated**: 2026-03-26

## Architecture

Terminal core sits at the foundation of cmux, providing terminal emulation and rendering for every workspace panel of type `.terminal`. It wraps libghostty (a C library compiled as GhosttyKit.xcframework via Zig) and bridges it into AppKit/SwiftUI.

```
SwiftUI Layer        AppKit Layer           Native Layer
-----------          -----------            ------------
GhosttyTerminalView  GhosttySurfaceScrollView  ghostty_surface_t
(NSViewRepresentable)  (NSView portal host)     (C API, Metal render)
        |                    |                       |
        +-----> TerminalSurface <----> GhosttyNSView
                (lifecycle owner)      (Metal surface view)
```

## Key Components

### GhosttyApp (singleton)
- Initializes libghostty runtime (`ghostty_app_t`)
- Manages global state: default background color, background opacity, config reload notifications
- Provides `defaultBackgroundColor` and `defaultBackgroundOpacity` for theme synchronization

### GhosttyConfig
- Parses Ghostty-compatible config files (key=value format)
- Resolves themes from multiple search paths with light/dark pairing
- Caches parsed configs per color scheme preference (thread-safe)
- Config keys: `font-family`, `font-size`, `theme`, `background`, `foreground`, `cursor-color`, `palette`, `scrollback-limit`, `working-directory`, `background-opacity`, `unfocused-split-opacity`, `split-divider-color`, `sidebar-background`, `sidebar-tint-opacity`

### TerminalSurface
- Owns the `ghostty_surface_t` lifecycle (creation, teardown, quarantine)
- Tracks surface state: `hasLiveSurface`, `isViewInWindow`, portal lifecycle
- Provides `SearchState` for incremental terminal search
- Holds port ordinal for `CMUX_PORT` environment variable
- Manages inherited config (font size zoom) across splits

### TerminalSurfaceRegistry
- Global weak-reference registry of all live `TerminalSurface` instances
- Maps `ghostty_surface_t` raw pointers to owner UUIDs
- Thread-safe via NSLock

### GhosttySurfaceScrollView
- AppKit NSView that hosts the Metal-rendered terminal surface
- Manages: background view, notification ring, focus flash animation, search overlay
- Handles file drop (URL forwarding to terminal), focus flash styles (navigation vs notification)

### GhosttyTerminalView
- SwiftUI `NSViewRepresentable` bridge for `GhosttySurfaceScrollView`
- Manages pane drop zones, portal z-priority, inactive overlay, unread notification ring
- Coordinates reattach tokens for surface portal reparenting

### GhosttyPasteboardHelper
- Static helper for clipboard read/write operations
- Supports: plain text, file URLs (shell-escaped), HTML, RTF, RTFD, image data
- Image clipboard creates temporary PNG/JPEG files for terminal image protocols

### GhosttySurfaceCallbackContext
- Weak-reference bridge between Ghostty C callbacks and Swift objects
- Routes surface events (title change, bell, child exit) to the correct `TerminalSurface`

### SwiftTerm fallback (TerminalView.swift)
- Alternative terminal implementation using SwiftTerm library
- `SwiftTermView` (NSViewRepresentable) wraps `LocalProcessTerminalView`
- Applies GhosttyConfig colors and palette
- Used as a simpler fallback without Ghostty dependencies

## Platform Abstraction

### Platform-specific (macOS only)
- `GhosttySurfaceScrollView`, `GhosttyNSView` (AppKit views)
- `GhosttyTerminalView` (NSViewRepresentable)
- `GhosttyPasteboardHelper` (NSPasteboard)
- `NSColor` extensions (hex parsing, luminance, darkening)
- Metal rendering pipeline
- Window transparency and glass effects

### Platform-agnostic (reusable on Linux)
- `GhosttyConfig` parsing and theme resolution (except NSColor references)
- `TerminalSurfaceRegistry` (needs no platform APIs)
- Surface lifecycle management and pointer safety checks
- Config file search path logic (already supports XDG)
- Shell escape logic
- Port ordinal assignment

### Linux porting needs
- Replace NSColor with a cross-platform color type or platform-conditional typealias
- Replace NSViewRepresentable with GTK widget hosting or custom rendering
- Replace NSPasteboard with X11/Wayland clipboard
- Replace Metal rendering with OpenGL/Vulkan (handled by Ghostty itself)
- Replace AppKit focus/first-responder model with platform equivalent

## Data Flow

### Config loading
```
Ghostty config files -> GhosttyConfig.loadFromDisk() -> parse() -> loadTheme()
  -> resolveSidebarBackground() -> applySidebarAppearanceToUserDefaults()
  -> cached by color scheme preference
```

### Surface creation
```
Workspace.newTerminalSurface()
  -> TerminalSurface(config, workingDirectory, environment)
  -> GhosttySurfaceScrollView (AppKit host)
  -> GhosttyNSView (Metal surface)
  -> ghostty_surface_create() (C API)
  -> TerminalSurfaceRegistry.register()
```

### Theme change propagation
```
ghosttyConfigDidReload / ghosttyDefaultBackgroundDidChange notification
  -> GhosttyConfig.invalidateLoadCache()
  -> WorkspaceContentView.refreshGhosttyAppearanceConfig()
  -> workspace.applyGhosttyChrome()
  -> terminalPanel.applyWindowBackgroundIfActive()
```

### Clipboard paste
```
Cmd+V / Ghostty paste callback
  -> GhosttyPasteboardHelper.stringContents(from:)
  -> tries: file URLs (escaped) -> plain text -> HTML -> RTF -> RTFD -> image path
  -> ghostty_surface_paste() or terminal feed
```

## Dependencies

### Internal
- **Workspace** (Sources/Workspace.swift): Creates and manages terminal surfaces
- **Panel protocol** (Sources/Panels/Panel.swift): Terminal panels conform to Panel
- **BonsplitController** (vendor/bonsplit): Manages pane layout containing terminal views

### External
- **GhosttyKit.xcframework**: libghostty compiled for macOS (universal binary)
- **Metal framework**: GPU rendering for terminal surfaces
- **IOSurface framework**: Shared GPU surfaces between Ghostty and AppKit
- **SwiftTerm** (fallback only): Pure Swift terminal emulator library
- **Sentry**: Crash reporting and breadcrumbs
