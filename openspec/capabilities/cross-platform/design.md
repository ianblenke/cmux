# Cross-Platform Design

**Last Updated**: 2026-03-26

## Architecture

The cross-platform architecture introduces a Platform Abstraction Layer (PAL) between the shared core logic and platform-specific UI backends. The core logic layer is pure Swift with no platform UI imports. Each platform provides a backend that implements the PAL protocols using native frameworks.

```
┌─────────────────────────────────────────────────────────────────┐
│                      Platform Backends                           │
│                                                                  │
│  ┌─────────────────────────┐    ┌─────────────────────────────┐ │
│  │    macOS Backend        │    │      Linux Backend          │ │
│  │                         │    │                             │ │
│  │  SwiftUI + AppKit       │    │  GTK4 (via C interop or    │ │
│  │  WKWebView              │    │   Swift-GTK bindings)      │ │
│  │  Bonsplit (AppKit)      │    │  WebKitGTK                 │ │
│  │  Sparkle                │    │  GTK4 Paned/custom splits  │ │
│  │  Metal rendering        │    │  libnotify / XDG portals   │ │
│  │  NSPasteboard           │    │  OpenGL/Vulkan rendering   │ │
│  │  NSDragging             │    │  GdkClipboard              │ │
│  │  NSMenu                 │    │  GtkDnD                    │ │
│  │  AppleScript (SDEF)     │    │  (no equivalent)           │ │
│  └────────────┬────────────┘    └──────────────┬──────────────┘ │
│               │                                │                 │
│               └──────────┬─────────────────────┘                 │
│                          ▼                                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │           Platform Abstraction Layer (PAL)                │   │
│  │                                                           │   │
│  │  Protocols:                                               │   │
│  │    PlatformWindow          PlatformClipboard              │   │
│  │    PlatformSurface         PlatformDragDrop               │   │
│  │    PlatformWebView         PlatformNotification           │   │
│  │    PlatformMenuBar         PlatformAppLifecycle           │   │
│  │    PlatformKeyboard        PlatformFileDialog             │   │
│  │    PlatformSplitContainer  PlatformUpdateChecker          │   │
│  │    PlatformStringLocalizer PlatformAppearance             │   │
│  └──────────────────────────────┬────────────────────────────┘   │
│                                 ▼                                │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                  Core Logic Layer                         │   │
│  │  (Pure Swift, no platform UI imports)                     │   │
│  │                                                           │   │
│  │  TabManager         WorkspaceModel        ConfigManager   │   │
│  │  SessionPersistence NotificationStore     SocketControl   │   │
│  │  SSHDetector        PortScanner           KeybindModel    │   │
│  └──────────────────────────────┬────────────────────────────┘   │
│                                 ▼                                │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Terminal Engine (libghostty)                  │   │
│  │  C FFI via ghostty.h — identical on all platforms         │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Key Components

### PAL Protocol Suite

Each protocol defines the minimal interface the core logic needs from the platform. Platform backends conform to these protocols.

#### PlatformAppLifecycle
```swift
protocol PlatformAppLifecycle {
    func run() -> Never  // Enter main event loop
    func quit()
    var isActive: Bool { get }
    func registerURLScheme(_ scheme: String)
}
// macOS: wraps NSApplication
// Linux: wraps GtkApplication
```

#### PlatformWindow
```swift
protocol PlatformWindow: AnyObject {
    var title: String { get set }
    var frame: PlatformRect { get set }
    var isFullScreen: Bool { get set }
    func makeKeyAndVisible()
    func close()
    func addSplitContainer(_ container: PlatformSplitContainer)
    func setSidebar(visible: Bool, width: CGFloat)
    func setToolbar(_ items: [ToolbarItem])
}
// macOS: wraps NSWindow + SwiftUI hosting
// Linux: wraps GtkApplicationWindow
```

#### PlatformSurface
```swift
protocol PlatformSurface: AnyObject {
    /// The native view/widget that renders the terminal
    var nativeView: Any { get }
    func focus()
    func resize(to size: PlatformSize)
    func sendInput(_ data: Data)
    var onTitleChange: ((String) -> Void)? { get set }
    var onBell: (() -> Void)? { get set }
    var onClose: (() -> Void)? { get set }
}
// macOS: wraps GhosttySurfaceView (NSView + Metal)
// Linux: wraps GtkGLArea + libghostty OpenGL surface
```

#### PlatformSplitContainer
```swift
protocol PlatformSplitContainer: AnyObject {
    func split(direction: SplitDirection, at surface: PlatformSurface) -> PlatformSurface
    func removeSurface(_ surface: PlatformSurface)
    func moveDivider(at index: Int, to position: CGFloat)
    var surfaces: [PlatformSurface] { get }
}
// macOS: wraps Bonsplit
// Linux: wraps GtkPaned tree or custom split widget
```

#### PlatformWebView
```swift
protocol PlatformWebView: AnyObject {
    func load(url: URL)
    func evaluateJavaScript(_ script: String) async throws -> Any?
    var onNavigate: ((URL) -> Void)? { get set }
    var onTitleChange: ((String) -> Void)? { get set }
    var nativeView: Any { get }
}
// macOS: wraps WKWebView
// Linux: wraps WebKitGTK WebView
```

#### PlatformClipboard
```swift
protocol PlatformClipboard {
    func copy(_ string: String)
    func paste() -> String?
    func copyImage(_ data: Data, type: String)
}
// macOS: wraps NSPasteboard
// Linux: wraps GdkClipboard (Wayland/X11)
```

#### PlatformUpdateChecker
```swift
protocol PlatformUpdateChecker {
    func checkForUpdates()
    var updateAvailable: ((UpdateInfo) -> Void)? { get set }
    var isSupported: Bool { get }  // false on Linux pkg-managed installs
}
// macOS: wraps Sparkle
// Linux: GitHub release check or no-op for pkg-managed
```

### Component Classification

| Component | Classification | Notes |
|-----------|---------------|-------|
| Workspace model | Shared | Pure Swift, no OS deps |
| TabManager | Shared | Pure Swift, no OS deps |
| NotificationStore | Shared | Pure Swift model, delivery via PAL |
| SessionPersistence | Shared | File I/O only (Foundation) |
| CmuxConfig | Shared | File parsing only |
| SocketControlServer | Shared | POSIX sockets (Foundation) |
| CLI (cmux command) | Shared | Socket client only |
| SSHDetector | Shared | Environment variables + process inspection |
| PortScanner | Shared | POSIX sockets |
| GhosttyTerminalView | Platform-specific | AppKit NSView / GTK4 Widget |
| ContentView (sidebar) | Platform-specific | SwiftUI / GTK4 |
| BrowserPanelView | Platform-specific | WKWebView / WebKitGTK |
| UpdateController | Platform-specific | Sparkle / Linux updater |
| AppDelegate | Platform-specific | NSApplicationDelegate / GApplication |
| WindowToolbar | Platform-specific | NSToolbar / GtkHeaderBar |
| Bonsplit UI layer | Platform-specific | NSView / GtkWidget |
| Bonsplit tree model | Shared | Split tree data structure (pure Swift) |

### Source Layout

```
Sources/
  Core/                          # Shared core logic (no platform imports)
    TabManager.swift
    Workspace.swift
    SessionPersistence.swift
    ConfigManager.swift
    SocketControlServer.swift
    NotificationStore.swift
    SSHDetector.swift
    PortScanner.swift
    KeybindModel.swift
  PAL/                           # Protocol definitions
    PlatformAppLifecycle.swift
    PlatformWindow.swift
    PlatformSurface.swift
    PlatformSplitContainer.swift
    PlatformWebView.swift
    PlatformClipboard.swift
    PlatformMenuBar.swift
    PlatformKeyboard.swift
    PlatformDragDrop.swift
    PlatformNotification.swift
    PlatformUpdateChecker.swift
    PlatformFileDialog.swift
    PlatformAppearance.swift
    PlatformStringLocalizer.swift
    PlatformTypes.swift          # Cross-platform type aliases
  macOS/                         # macOS backend (SwiftUI + AppKit)
    macOSApp.swift
    macOSWindow.swift
    macOSSurface.swift
    macOSSplitContainer.swift    # Bonsplit wrapper
    macOSWebView.swift           # WKWebView wrapper
    macOSClipboard.swift
    macOSMenuBar.swift
    macOSUpdateChecker.swift     # Sparkle wrapper
    macOSAppleScript.swift       # macOS-only, no PAL protocol
    ...existing SwiftUI views...
  Linux/                         # Linux backend (GTK4)
    LinuxApp.swift               # GtkApplication entry point
    LinuxWindow.swift
    LinuxSurface.swift
    LinuxSplitContainer.swift    # GtkPaned wrapper
    LinuxWebView.swift           # WebKitGTK wrapper
    LinuxClipboard.swift
    LinuxMenuBar.swift
    LinuxNotification.swift      # libnotify wrapper
    ...
  CLI/                           # Cross-platform CLI
    main.swift
```

## Platform Abstraction

### Type Aliases

A `PlatformTypes.swift` file provides cross-platform type aliases:

```swift
#if os(macOS)
import AppKit
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
public typealias PlatformImage = NSImage
public typealias PlatformRect = NSRect
public typealias PlatformSize = NSSize
public typealias PlatformPoint = NSPoint
#elseif os(Linux)
import Foundation
public typealias PlatformColor = CmuxColor  // Custom RGBA struct
public typealias PlatformFont = CmuxFont    // Custom font descriptor
public typealias PlatformImage = CmuxImage  // Custom image wrapper
public typealias PlatformRect = CGRect      // Foundation on Linux
public typealias PlatformSize = CGSize
public typealias PlatformPoint = CGPoint
#endif
```

### Path Conventions

```swift
enum PlatformPaths {
    static var configDir: URL {
        #if os(macOS)
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/cmux")
        #elseif os(Linux)
        if let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] {
            return URL(fileURLWithPath: xdg).appendingPathComponent("cmux")
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/cmux")
        #endif
    }

    static var dataDir: URL {
        #if os(macOS)
        configDir  // macOS uses same dir
        #elseif os(Linux)
        if let xdg = ProcessInfo.processInfo.environment["XDG_DATA_HOME"] {
            return URL(fileURLWithPath: xdg).appendingPathComponent("cmux")
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/cmux")
        #endif
    }

    static var runtimeDir: URL? {
        #if os(Linux)
        if let xdg = ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"] {
            return URL(fileURLWithPath: xdg).appendingPathComponent("cmux")
        }
        return nil
        #else
        return nil
        #endif
    }

    static var socketPath: String {
        #if os(Linux)
        if let runtimeDir = runtimeDir {
            return runtimeDir.appendingPathComponent("cmux.sock").path
        }
        #endif
        return "/tmp/cmux-\(ProcessInfo.processInfo.processIdentifier).sock"
    }
}
```

### Compile-Time Platform Selection

```swift
// In Package.swift — conditional target inclusion
.target(name: "cmux-macos", dependencies: ["cmux-core", "cmux-pal"],
        path: "Sources/macOS",
        condition: .when(platforms: [.macOS])),
.target(name: "cmux-linux", dependencies: ["cmux-core", "cmux-pal"],
        path: "Sources/Linux",
        condition: .when(platforms: [.linux])),
```

Core logic code uses PAL protocols exclusively -- no `#if os()` in shared code:

```swift
// In Core/WorkspaceManager.swift — uses protocols, not concrete types
class WorkspaceManager {
    let windowProvider: any PlatformWindow
    let clipboardProvider: any PlatformClipboard
    // ... never imports AppKit, SwiftUI, or GTK
}
```

## Data Flow

### Application Startup

```
main.swift
    |
    +-- #if os(macOS)
    |       macOSApp.run()
    |       +-- NSApplication setup
    |       +-- AppDelegate initialization
    |       +-- SwiftUI scene creation
    |       +-- Bonsplit/GhosttyKit initialization
    |
    +-- #if os(Linux)
            LinuxApp.run()
            +-- GtkApplication setup
            +-- GTK4 window creation
            +-- libghostty.so initialization via ghostty.h FFI
            +-- GtkPaned split container setup
```

### Terminal Surface Creation

```
Core: TabManager.createTerminal()
    |
    v
PAL: PlatformSurface = platformFactory.createSurface(config)
    |
    +-- macOS: GhosttySurfaceView(Metal) via GhosttyKit.xcframework
    |
    +-- Linux: GtkGLArea + ghostty_surface_new() via libghostty.so
               ghostty.h FFI (same C API on both platforms)
```

### Cross-Platform Input Path

```
Keystroke
    +-- macOS: NSEvent -> performKeyEquivalent / keyDown
    +-- Linux: GdkEvent -> GTK4 event controller
    |
    v
PAL key normalization (shared modifier mapping)
    |
    v
ghostty_surface_key_event() (C FFI, identical on both platforms)
    |
    v
PTY write (POSIX, shared)
    |
    v
PTY read (POSIX, shared)
    |
    v
ghostty render callback
    |
    +-- macOS: CAMetalLayer draw
    +-- Linux: GtkGLArea render signal
```

### Socket Command Flow

```
CLI (cmux list-workspaces)
    |
    v
Unix socket connect (POSIX, identical on both platforms)
    |
    v
SocketControlServer (Core/, shared code)
    |
    v
TabManager / WorkspaceModel (Core/, shared code)
    |
    v
PAL callback -> platform UI update
    +-- macOS: DispatchQueue.main.async { SwiftUI state update }
    +-- Linux: g_idle_add { GTK4 widget update }
```

## Dependencies

### Shared (all platforms)

| Dependency | Role | Source |
|------------|------|--------|
| libghostty | Terminal engine | Zig build, `ghostty.h` C FFI |
| cmuxd | Remote relay daemon | Go binary (separate process) |
| swift-argument-parser | CLI argument parsing | SPM package |
| Foundation | File I/O, JSON, networking | Apple (macOS) / swift-corelibs (Linux) |

### macOS-only

| Dependency | Role | Source |
|------------|------|--------|
| SwiftUI | Declarative UI | System framework |
| AppKit | Window management, NSView | System framework |
| WebKit (WKWebView) | Browser panels | System framework |
| Bonsplit | Split pane engine | `vendor/bonsplit` (AppKit) |
| Sparkle | Auto-update | SPM package |
| Metal | GPU rendering | System framework (via libghostty) |
| PostHog | Analytics | SPM package |
| Sentry | Crash reporting | SPM package |

### Linux-only

| Dependency | Role | System package |
|------------|------|----------------|
| GTK4 | UI framework | `libgtk-4-dev` |
| WebKitGTK | Browser panels | `libwebkitgtk-6.0-dev` |
| libnotify | Desktop notifications | `libnotify-dev` |
| libadwaita (optional) | GNOME HIG compliance | `libadwaita-1-dev` |
| OpenGL / Mesa | GPU rendering (via libghostty) | `libgl-dev` / `mesa-common-dev` |

### System Package Requirements (Linux)

```bash
# Ubuntu/Debian
sudo apt install \
    swift \
    libgtk-4-dev \
    libwebkitgtk-6.0-dev \
    libnotify-dev \
    libadwaita-1-dev \
    pkg-config \
    zig

# Fedora
sudo dnf install \
    swift-lang \
    gtk4-devel \
    webkitgtk6.0-devel \
    libnotify-devel \
    libadwaita-devel \
    zig
```

## Migration Strategy

The port should proceed in phases to avoid destabilizing the macOS build:

### Phase 1: Extract Core Logic (macOS-only, no Linux code yet)
1. Define PAL protocols in new `Sources/PAL/` directory
2. Move shared logic from `Sources/` to `Sources/Core/`
3. Create `Sources/macOS/` with AppKit/SwiftUI backends implementing PAL protocols
4. Verify macOS build is green with zero regressions
5. All existing tests pass

### Phase 2: Linux Scaffold
1. Create `Sources/Linux/` with stub GTK4 implementations
2. Configure SPM conditional compilation
3. Set up Linux CI (compile-only, stubs return defaults)
4. Link libghostty.so on Linux

### Phase 3: Terminal Core on Linux
1. Implement `LinuxSurface` with GtkGLArea + libghostty
2. Implement `LinuxWindow` with GtkApplicationWindow
3. Basic single-terminal-window functionality
4. Keyboard input and rendering working

### Phase 4: Feature Build-out
1. Split panes (GtkPaned tree or custom widget)
2. Tabs and workspaces (GtkNotebook or custom tab bar)
3. Sidebar (GtkListBox or GtkColumnView)
4. Config loading (XDG paths)
5. Socket control server (already portable)
6. Session persistence (XDG data directory)

### Phase 5: Polish
1. Browser panels (WebKitGTK)
2. Notifications (libnotify / D-Bus)
3. Keyboard shortcut settings (Ctrl/Super mapping)
4. Clipboard and drag-and-drop
5. Localization backend (gettext or Foundation on Linux)
6. Packaging (.deb, .rpm, Flatpak)

### Phase 6: Performance and Parity
1. Input latency benchmarking (typometer or equivalent)
2. Memory profiling (valgrind / heaptrack)
3. Startup time optimization
4. Feature parity audit against macOS
5. Wayland + X11 testing matrix

## Open Questions

1. **GTK4 from Swift**: Should we use a Swift-GTK binding library (e.g., SwiftGtk, adwaita-swift) or raw C interop with GTK4's C API? Raw C interop is more work but avoids a third-party dependency. SwiftGtk bindings may not cover GTK4 fully.
2. **Bonsplit on Linux**: Is it more practical to port Bonsplit's split logic to GTK4 (replacing NSView with GtkWidget) or to write a new split container using nested GtkPaned widgets? GtkPaned only supports binary splits, so a tree structure is needed for arbitrary layouts -- which happens to match Bonsplit's existing tree model.
3. **libadwaita**: Should the Linux UI use libadwaita for GNOME Human Interface Guidelines compliance, or stick with plain GTK4 for broader desktop environment compatibility (KDE, XFCE, etc.)?
4. **Swift on Linux maturity**: Swift's Linux support is production-ready for server-side code but less proven for GUI applications. Are there known gaps in Foundation, Combine, or async/await on Linux that would affect cmux?
5. **Wayland-first vs. X11-first**: Should development target Wayland first (the modern standard) or X11 first (broader current install base)? GTK4 abstracts this, but testing priorities matter.
6. **Analytics and crash reporting**: PostHog and Sentry SDKs are available for Linux. Should the Linux build include them from the start, or defer to post-launch?
