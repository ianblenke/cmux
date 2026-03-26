# Cross-Platform Specification

**Status**: PROPOSED
**Last Updated**: 2026-03-26

## Overview

cmux is currently a macOS-only application built with Swift, SwiftUI, and AppKit. This capability defines the requirements for porting cmux to Linux while maintaining feature parity where feasible, establishing a Platform Abstraction Layer (PAL), and defining clear boundaries between cross-platform core logic and platform-specific UI code.

## Requirements

### Platform Abstraction Layer (PAL)

#### REQ-XP-001: Platform abstraction layer exists
- **Description**: A well-defined Platform Abstraction Layer (PAL) separates platform-specific UI and system integration code from shared core logic. All platform-specific code lives behind PAL protocols/interfaces. Core logic (workspace management, tab management, session persistence, config, socket control, notification store) must not import AppKit, SwiftUI, Cocoa, or GTK directly.
- **Platform**: all
- **Status**: Proposed
- **Priority**: P0

#### REQ-XP-002: PAL protocol definitions
- **Description**: The PAL defines Swift protocols for each platform-dependent capability: window management, surface rendering, clipboard access, file dialogs, notifications (OS-level), drag-and-drop, web view embedding, menu bar, keyboard shortcut registration, update checking, and system locale/appearance detection.
- **Platform**: all
- **Status**: Proposed
- **Priority**: P0

#### REQ-XP-003: Compile-time platform selection
- **Description**: Platform backends are selected at compile time via Swift conditional compilation (`#if os(macOS)` / `#if os(Linux)`). No runtime platform detection is used for backend selection. Each platform target compiles only its own backend code.
- **Platform**: all
- **Status**: Proposed
- **Priority**: P0

### Build System

#### REQ-XP-010: Swift Package Manager build on Linux
- **Description**: The project builds on Linux using Swift Package Manager (SPM) without Xcode. The `Package.swift` defines all targets, dependencies, and conditional platform code. The Xcode project remains for macOS development but is not required for Linux builds.
- **Platform**: Linux
- **Status**: Proposed
- **Priority**: P0

#### REQ-XP-011: Linux CI pipeline
- **Description**: A GitHub Actions CI workflow builds and tests the Linux target on Ubuntu (latest LTS) and optionally Fedora. The pipeline installs Swift toolchain, system dependencies (GTK4, WebKitGTK, etc.), builds the project, and runs unit and integration tests.
- **Platform**: Linux
- **Status**: Proposed
- **Priority**: P0

#### REQ-XP-012: GhosttyKit xcframework replaced on Linux
- **Description**: On macOS, libghostty is consumed as `GhosttyKit.xcframework`. On Linux, the Zig build produces a shared library (`libghostty.so`) or static archive that is linked via SPM's system library target or C interop module. The existing `ghostty.h` C header serves as the FFI boundary on both platforms.
- **Platform**: Linux
- **Status**: Proposed
- **Priority**: P0

#### REQ-XP-013: Bonsplit cross-platform or replacement
- **Description**: The Bonsplit split-pane engine (currently a Swift/AppKit library in `vendor/bonsplit`) must either be ported to work on Linux or replaced with an equivalent that supports both platforms. Split pane functionality (horizontal/vertical splits, resize, drag-and-drop tab reorder) must be available on Linux.
- **Platform**: all
- **Status**: Proposed
- **Priority**: P0

#### REQ-XP-014: Linux packaging
- **Description**: The Linux build produces distributable packages: at minimum a `.deb` (Debian/Ubuntu) and `.rpm` (Fedora/RHEL), plus a Flatpak manifest. Packages include the binary, desktop entry, icon, shell integration scripts, and terminfo overlays.
- **Platform**: Linux
- **Status**: Proposed
- **Priority**: P1

### Linux UI Framework

#### REQ-XP-020: GTK4 UI backend
- **Description**: The Linux UI is built with GTK4, accessed from Swift either via a Swift-GTK binding library or via C interop with the GTK4 API. The GTK4 backend implements all PAL protocols for window management, widget rendering, input handling, and system integration.
- **Platform**: Linux
- **Status**: Proposed
- **Priority**: P0

#### REQ-XP-021: Terminal surface rendering on Linux
- **Description**: libghostty's rendering backend on Linux uses OpenGL or Vulkan (already supported by Ghostty upstream). The GTK4 UI hosts the GPU-rendered terminal surface via `GtkGLArea` or equivalent. The surface must respond to resize, focus, and input events identically to the macOS Metal-backed surface.
- **Platform**: Linux
- **Status**: Proposed
- **Priority**: P0

#### REQ-XP-022: WebKitGTK for browser panels
- **Description**: Browser panels on Linux use WebKitGTK (the GTK port of WebKit) instead of macOS's WKWebView. The browser panel PAL protocol abstracts URL loading, JavaScript bridge, navigation events, popup windows, and cookie/session management. Feature parity with the macOS browser panel is required for core browsing; macOS-specific WKWebView features (e.g., `WKWebExtension`) are not required on Linux.
- **Platform**: Linux
- **Status**: Proposed
- **Priority**: P1

#### REQ-XP-023: System tray and notifications on Linux
- **Description**: On Linux, application notifications use `libnotify` or the XDG notification portal (for Flatpak sandboxing). System tray integration (if applicable) uses the StatusNotifierItem D-Bus protocol. The notification PAL protocol abstracts notification posting, action handling, and badge counts.
- **Platform**: Linux
- **Status**: Proposed
- **Priority**: P2

#### REQ-XP-024: Keyboard shortcut handling on Linux
- **Description**: Global and application keyboard shortcuts on Linux are handled through GTK4's event controllers. Modifier key naming adapts to the platform (Ctrl on Linux maps to Cmd equivalent functionality). The keyboard shortcut settings system must present platform-appropriate modifier names and handle platform-specific key codes.
- **Platform**: Linux
- **Status**: Proposed
- **Priority**: P0

#### REQ-XP-025: Clipboard and drag-and-drop on Linux
- **Description**: Clipboard operations on Linux use GTK4's `GdkClipboard` API (supporting Wayland and X11). Drag-and-drop for tab reorder and pane rearrangement uses GTK4's DnD API. The custom UTTypes (`com.splittabbar.tabtransfer`, `com.cmux.sidebar-tab-reorder`) are replaced with MIME types or GType identifiers on Linux.
- **Platform**: Linux
- **Status**: Proposed
- **Priority**: P1

### Feature Parity

#### REQ-XP-030: Terminal core feature parity
- **Description**: Terminal emulation (VT parsing, PTY management, GPU rendering, font handling, cursor styles, selection, scrollback) is fully cross-platform via libghostty. No feature regression on Linux vs. macOS for core terminal functionality.
- **Platform**: all
- **Status**: Proposed (libghostty already supports Linux)
- **Priority**: P0

#### REQ-XP-031: Workspace and tab management parity
- **Description**: Workspaces, tabs, split panes, sidebar, and tab management features are available on Linux with the same data model and behavior as macOS. UI presentation may differ (GTK4 widgets vs. SwiftUI views) but the logical operations (create/close/reorder/rename workspace, split pane, move tab) are identical.
- **Platform**: all
- **Status**: Proposed
- **Priority**: P0

#### REQ-XP-032: Socket control parity
- **Description**: The Unix socket control server (`/tmp/cmux-*.sock`) operates identically on Linux. The CLI (`cmux` command) and socket protocol are cross-platform. All socket commands work on Linux.
- **Platform**: all
- **Status**: Proposed
- **Priority**: P0

#### REQ-XP-033: Session persistence parity
- **Description**: Session persistence (save/restore workspaces, panes, working directories on restart) works on Linux. The persistence file format is the same. Platform-specific paths (e.g., `~/Library/Application Support/` on macOS vs. `$XDG_DATA_HOME/cmux/` on Linux) are abstracted.
- **Platform**: all
- **Status**: Proposed
- **Priority**: P1

#### REQ-XP-034: Remote daemon parity
- **Description**: The `cmuxd` remote daemon (Go binary) already builds and runs on Linux. No additional work is required for the daemon itself. The SSH detection and relay bootstrap features must work with Linux SSH clients.
- **Platform**: all
- **Status**: Proposed (cmuxd is already cross-platform)
- **Priority**: P1

#### REQ-XP-035: Configuration file parity
- **Description**: The configuration file format and all configuration keys are identical on macOS and Linux. Platform-specific keys (e.g., macOS window chrome options) are documented as platform-specific and silently ignored on other platforms. Config file location follows XDG on Linux (`$XDG_CONFIG_HOME/cmux/config`).
- **Platform**: all
- **Status**: Proposed
- **Priority**: P0

#### REQ-XP-036: Shell integration parity
- **Description**: Shell integration scripts (bash, zsh, fish) work identically on Linux. The `Resources/shell-integration/` directory is bundled and installed on both platforms.
- **Platform**: all
- **Status**: Proposed
- **Priority**: P0

### macOS-Only Features

#### REQ-XP-040: AppleScript support is macOS-only
- **Description**: AppleScript/Open Scripting Architecture support (`cmux.sdef`, `NSAppleScriptEnabled`) is macOS-only. No Linux equivalent is planned. D-Bus scripting may be considered in the future as a Linux-specific alternative.
- **Platform**: macOS-only
- **Status**: Implemented (macOS)
- **Priority**: P2

#### REQ-XP-041: Sparkle update system is macOS-only
- **Description**: The Sparkle auto-update framework is macOS-only. On Linux, updates are delivered through package managers (apt, dnf, flatpak). An optional self-update mechanism (checking GitHub releases) may be added for tarball installs.
- **Platform**: macOS-only (Sparkle); Linux uses package managers
- **Status**: Implemented (macOS)
- **Priority**: P1

#### REQ-XP-042: Finder services are macOS-only
- **Description**: macOS Finder service menu items ("New cmux Workspace Here", "New cmux Window Here") are macOS-only. On Linux, equivalent functionality may be provided via file manager extensions (Nautilus scripts, Dolphin service menus) as a P2 item.
- **Platform**: macOS-only
- **Status**: Implemented (macOS)
- **Priority**: P2

#### REQ-XP-043: Touchbar support is macOS-only
- **Description**: Any Touch Bar integration is macOS-only with no Linux equivalent.
- **Platform**: macOS-only
- **Status**: Implemented (macOS)
- **Priority**: P2

### Performance

#### REQ-XP-050: Input latency parity
- **Description**: Keystroke-to-render latency on Linux must be within 5ms of the macOS baseline for the same hardware. The rendering pipeline (libghostty OpenGL/Vulkan) and input event delivery (GTK4 event controllers) must not introduce additional latency beyond the macOS Metal path.
- **Platform**: all
- **Status**: Proposed
- **Priority**: P0

#### REQ-XP-051: Memory usage parity
- **Description**: Baseline memory usage (single window, single terminal, idle) on Linux should be within 20% of the macOS baseline. GTK4 overhead should not significantly exceed SwiftUI/AppKit overhead.
- **Platform**: all
- **Status**: Proposed
- **Priority**: P1

#### REQ-XP-052: Startup time parity
- **Description**: Cold start time on Linux should be within 500ms of the macOS baseline on comparable hardware. The Linux build must not introduce heavyweight runtime initialization.
- **Platform**: all
- **Status**: Proposed
- **Priority**: P1

### Display Server Support

#### REQ-XP-060: Wayland support
- **Description**: The Linux build runs natively on Wayland compositors. GTK4 provides native Wayland support. GPU rendering, clipboard, and DnD use Wayland-native protocols where available.
- **Platform**: Linux
- **Status**: Proposed
- **Priority**: P0

#### REQ-XP-061: X11 support
- **Description**: The Linux build runs on X11 via GTK4's X11 backend or XWayland. Core functionality is not degraded on X11, though some features (e.g., per-monitor DPI) may have reduced fidelity.
- **Platform**: Linux
- **Status**: Proposed
- **Priority**: P1

## Scenarios

### SCENARIO-XP-001: Build on Ubuntu
- **Given**: A fresh Ubuntu LTS system with Swift toolchain and GTK4 development packages installed
- **When**: The developer runs `swift build` in the repository root
- **Then**: The project compiles without errors and produces a `cmux` binary
- **Verifies**: REQ-XP-010, REQ-XP-003
- **Status**: Missing

### SCENARIO-XP-002: Launch on Wayland
- **Given**: A Linux system running a Wayland compositor (e.g., GNOME on Wayland)
- **When**: The user launches the `cmux` binary
- **Then**: A window appears with a functional terminal, sidebar, and tab bar; keyboard input produces characters in the terminal
- **Verifies**: REQ-XP-020, REQ-XP-021, REQ-XP-060, REQ-XP-030
- **Status**: Missing

### SCENARIO-XP-003: Split panes on Linux
- **Given**: cmux is running on Linux with a single terminal pane
- **When**: The user triggers a vertical split (keyboard shortcut or socket command)
- **Then**: Two terminal panes appear side-by-side, each with an independent shell session; the divider is draggable
- **Verifies**: REQ-XP-013, REQ-XP-031
- **Status**: Missing

### SCENARIO-XP-004: Socket control on Linux
- **Given**: cmux is running on Linux
- **When**: The user runs `cmux list-windows` from another terminal
- **Then**: The CLI connects via the Unix socket and returns the list of windows/workspaces in the same format as macOS
- **Verifies**: REQ-XP-032
- **Status**: Missing

### SCENARIO-XP-005: Browser panel on Linux
- **Given**: cmux is running on Linux with WebKitGTK installed
- **When**: The user opens a browser panel and navigates to a URL
- **Then**: The web page renders within the cmux panel, with navigation controls and JavaScript execution
- **Verifies**: REQ-XP-022
- **Status**: Missing

### SCENARIO-XP-006: Session persistence on Linux
- **Given**: cmux is running on Linux with two workspaces and several split panes
- **When**: The user quits and relaunches cmux
- **Then**: The workspaces, panes, and working directories are restored from `$XDG_DATA_HOME/cmux/`
- **Verifies**: REQ-XP-033
- **Status**: Missing

### SCENARIO-XP-007: Config file on Linux
- **Given**: The user has a config file at `$XDG_CONFIG_HOME/cmux/config`
- **When**: cmux launches
- **Then**: Configuration is loaded and applied (fonts, colors, keybindings); macOS-specific keys are silently ignored
- **Verifies**: REQ-XP-035
- **Status**: Missing

### SCENARIO-XP-008: Keyboard shortcuts adapt to Linux
- **Given**: cmux is running on Linux
- **When**: The user opens keyboard shortcut settings
- **Then**: Modifier keys show "Ctrl" instead of "Cmd"; shortcuts use Linux conventions (Ctrl+Shift+T for new tab, etc.)
- **Verifies**: REQ-XP-024
- **Status**: Missing

### SCENARIO-XP-009: macOS build unchanged
- **Given**: The PAL refactoring is complete
- **When**: The developer builds and runs cmux on macOS via Xcode
- **Then**: All existing features work identically; no regressions from the PAL introduction
- **Verifies**: REQ-XP-001, REQ-XP-003
- **Status**: Missing

### SCENARIO-XP-010: libghostty linked on Linux
- **Given**: The Ghostty submodule is built with `zig build` producing `libghostty.so`
- **When**: SPM builds the cmux target on Linux
- **Then**: The ghostty C header is found, the shared library links, and terminal surface creation succeeds
- **Verifies**: REQ-XP-012
- **Status**: Missing

### SCENARIO-XP-011: Flatpak package builds
- **Given**: The Flatpak manifest is defined in the repository
- **When**: `flatpak-builder` runs against the manifest
- **Then**: A Flatpak bundle is produced that installs and launches on a clean system
- **Verifies**: REQ-XP-014
- **Status**: Missing

### SCENARIO-XP-012: Input latency measurement
- **Given**: cmux is running on Linux
- **When**: A keystroke latency benchmark is executed (e.g., typometer or equivalent)
- **Then**: Average keystroke-to-render latency is within 5ms of the macOS measurement on equivalent hardware
- **Verifies**: REQ-XP-050
- **Status**: Missing

## Cross-Platform Notes

### What is already cross-platform
- **libghostty**: Terminal engine (Zig) -- builds on macOS, Linux, FreeBSD
- **cmuxd**: Remote relay daemon (Go) -- builds on all major platforms
- **ghostty.h**: C FFI header -- usable from Swift on any platform
- **Shell integration scripts**: Bash/Zsh/Fish -- platform-independent
- **Terminfo overlays**: Standard terminfo format
- **Socket protocol**: Unix domain sockets -- POSIX standard
- **Configuration format**: Text file, no platform dependencies

### What must be ported
- **UI layer**: SwiftUI/AppKit to GTK4
- **Split pane engine**: Bonsplit (AppKit) to GTK4 equivalent
- **Browser panels**: WKWebView to WebKitGTK
- **Update system**: Sparkle to package manager / self-update
- **Build system**: Xcode project to SPM-only
- **Localization runtime**: Apple String Catalog to portable format
- **System integration**: Finder services, AppleScript, Touch Bar (macOS-only, skip or replace)

### What stays macOS-only
- AppleScript/SDEF scripting
- Sparkle update framework
- Finder service menu items
- Touch Bar integration
- Metal rendering backend (Linux uses OpenGL/Vulkan)
- NSApplication/NSWindow lifecycle (replaced by GtkApplication/GtkWindow)

## Implementation Status

| Requirement | Status | Notes |
|-------------|--------|-------|
| REQ-XP-001 | Proposed | PAL does not exist yet; architecture doc has planned diagram |
| REQ-XP-002 | Proposed | Protocol definitions not yet written |
| REQ-XP-003 | Proposed | Some `#if os()` exists for minor items |
| REQ-XP-010 | Proposed | Package.swift exists but is macOS-only |
| REQ-XP-011 | Proposed | No Linux CI workflow |
| REQ-XP-012 | Proposed | ghostty.h exists; Linux linking not configured |
| REQ-XP-013 | Proposed | Bonsplit is AppKit-only |
| REQ-XP-014 | Proposed | No packaging manifests |
| REQ-XP-020 | Proposed | No GTK4 code exists |
| REQ-XP-021 | Proposed | libghostty supports Linux rendering |
| REQ-XP-022 | Proposed | No WebKitGTK integration |
| REQ-XP-023 | Proposed | No Linux notification code |
| REQ-XP-024 | Proposed | Keyboard handling is AppKit-only |
| REQ-XP-025 | Proposed | DnD uses Apple UTTypes |
| REQ-XP-030 | Proposed | libghostty is cross-platform |
| REQ-XP-031 | Proposed | Data model is portable; UI is not |
| REQ-XP-032 | Proposed | Socket code is mostly portable |
| REQ-XP-033 | Proposed | Persistence format is portable; paths need XDG |
| REQ-XP-034 | Proposed | cmuxd already runs on Linux |
| REQ-XP-035 | Proposed | Config parsing is portable |
| REQ-XP-036 | Proposed | Shell scripts are portable |
| REQ-XP-040 | Implemented (macOS) | macOS-only, no port needed |
| REQ-XP-041 | Implemented (macOS) | Sparkle on macOS; Linux uses pkg mgr |
| REQ-XP-042 | Implemented (macOS) | macOS-only |
| REQ-XP-043 | Implemented (macOS) | macOS-only |
| REQ-XP-050 | Proposed | No Linux benchmarks yet |
| REQ-XP-051 | Proposed | No Linux benchmarks yet |
| REQ-XP-052 | Proposed | No Linux benchmarks yet |
| REQ-XP-060 | Proposed | GTK4 provides Wayland support |
| REQ-XP-061 | Proposed | GTK4 provides X11 support |
