# Architecture Document — cmux

**Last Reconciled**: 2026-03-26
**Status**: EXTRACTED (backfilled from existing codebase)

---

## 1. System Overview

cmux is a native terminal multiplexer built on libghostty. The architecture is layered:

```
┌──────────────────────────────────────────────────────────┐
│                    Platform UI Layer                      │
│  ┌─────────────────┐  ┌──────────────────────────────┐   │
│  │  SwiftUI/AppKit │  │  GTK4 (Linux, planned)       │   │
│  │  (macOS)        │  │                              │   │
│  └────────┬────────┘  └──────────────┬───────────────┘   │
│           └──────────┬───────────────┘                   │
│                      ▼                                    │
│          ┌──────────────────────┐                         │
│          │  Platform Abstraction│                         │
│          │  Layer (PAL)         │                         │
│          └──────────┬───────────┘                         │
│                     ▼                                     │
│  ┌──────────────────────────────────────────────────┐    │
│  │              Core Logic Layer                     │    │
│  │  ┌──────────┐ ┌──────────┐ ┌───────────────┐    │    │
│  │  │Workspace │ │Tab       │ │Notification   │    │    │
│  │  │Manager   │ │Manager   │ │Store          │    │    │
│  │  └──────────┘ └──────────┘ └───────────────┘    │    │
│  │  ┌──────────┐ ┌──────────┐ ┌───────────────┐    │    │
│  │  │Session   │ │Config    │ │Socket Control │    │    │
│  │  │Persist.  │ │Manager   │ │Server         │    │    │
│  │  └──────────┘ └──────────┘ └───────────────┘    │    │
│  └──────────────────────┬───────────────────────────┘    │
│                         ▼                                 │
│  ┌──────────────────────────────────────────────────┐    │
│  │            Terminal Engine (libghostty)            │    │
│  │  GPU-accelerated rendering, VT parsing, PTY mgmt  │    │
│  └──────────────────────────────────────────────────┘    │
│                         ▼                                 │
│  ┌──────────────────────────────────────────────────┐    │
│  │       Split Pane Engine (Bonsplit)                │    │
│  │  Vertical/horizontal splits, tab bar, drag/drop   │    │
│  └──────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│                  External Processes                        │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │  CLI (cmux)  │  │  cmuxd-remote│  │  Shell procs   │  │
│  │  Swift       │  │  Go daemon   │  │  PTY children  │  │
│  └──────┬───────┘  └──────┬───────┘  └────────────────┘  │
│         │                 │                               │
│         └────── Unix Socket / TCP ──────┘                 │
└──────────────────────────────────────────────────────────┘
```

## 2. Component Inventory

### 2.1 Application Entry Point

| Component | File | Responsibility |
|-----------|------|---------------|
| cmuxApp | Sources/cmuxApp.swift | SwiftUI app lifecycle, scene management |
| AppDelegate | Sources/AppDelegate.swift | AppKit delegate, global key monitoring, menu bar |

### 2.2 Core Model

| Component | File | Responsibility |
|-----------|------|---------------|
| Workspace | Sources/Workspace.swift | Workspace model (sidebar entry containing panes) |
| TabManager | Sources/TabManager.swift | Workspace collection management, ordering, selection |
| Panel | Sources/Panels/Panel.swift | Base panel model (terminal or browser surface) |
| TerminalPanel | Sources/Panels/TerminalPanel.swift | Terminal surface model |
| BrowserPanel | Sources/Panels/BrowserPanel.swift | Browser surface model |
| MarkdownPanel | Sources/Panels/MarkdownPanel.swift | Markdown viewer surface model |

### 2.3 UI Layer (macOS — SwiftUI + AppKit)

| Component | File | Responsibility |
|-----------|------|---------------|
| ContentView | Sources/ContentView.swift | Main window content, sidebar + workspace display |
| WorkspaceContentView | Sources/WorkspaceContentView.swift | Workspace body with split pane tree |
| GhosttyTerminalView | Sources/GhosttyTerminalView.swift | AppKit terminal surface wrapping libghostty |
| TerminalWindowPortal | Sources/TerminalWindowPortal.swift | AppKit portal for terminal hosting in SwiftUI |
| BrowserPanelView | Sources/Panels/BrowserPanelView.swift | WKWebView-based browser panel |
| SidebarSelectionState | Sources/SidebarSelectionState.swift | Sidebar UI state management |

### 2.4 Terminal Engine Integration

| Component | File | Responsibility |
|-----------|------|---------------|
| GhosttyConfig | Sources/GhosttyConfig.swift | Ghostty config file parsing/application |
| TerminalController | Sources/TerminalController.swift | Terminal lifecycle, input handling |
| TerminalView | Sources/TerminalView.swift | Terminal view abstraction |

### 2.5 Notification System

| Component | File | Responsibility |
|-----------|------|---------------|
| TerminalNotificationStore | Sources/TerminalNotificationStore.swift | Notification aggregation, unread tracking |
| NotificationsPage | Sources/NotificationsPage.swift | Notifications panel UI |

### 2.6 Socket Control

| Component | File | Responsibility |
|-----------|------|---------------|
| SocketControlSettings | Sources/SocketControlSettings.swift | Socket server configuration |
| CLI | CLI/cmux.swift | CLI client (514KB monolith) |

### 2.7 Session Persistence

| Component | File | Responsibility |
|-----------|------|---------------|
| SessionPersistence | Sources/SessionPersistence.swift | Save/restore workspace layout and metadata |

### 2.8 Configuration

| Component | File | Responsibility |
|-----------|------|---------------|
| CmuxConfig | Sources/CmuxConfig.swift | cmux-specific config parsing |
| CmuxConfigExecutor | Sources/CmuxConfigExecutor.swift | Config application at runtime |

### 2.9 Update System (macOS)

| Component | Files | Responsibility |
|-----------|-------|---------------|
| UpdateController | Sources/Update/UpdateController.swift | Sparkle integration orchestration |
| UpdateDriver | Sources/Update/UpdateDriver.swift | Update check/download logic |
| UpdateViewModel | Sources/Update/UpdateViewModel.swift | UI state for update flow |
| UpdatePill | Sources/Update/UpdatePill.swift | Toolbar update badge |

### 2.10 Remote Daemon

| Component | Files | Responsibility |
|-----------|-------|---------------|
| cmuxd-remote | daemon/remote/ | Go daemon for SSH sessions |
| RemoteRelayZshBootstrap | Sources/RemoteRelayZshBootstrap.swift | Remote shell bootstrap |
| TerminalSSHSessionDetector | Sources/TerminalSSHSessionDetector.swift | SSH session detection |

### 2.11 Browser Automation

| Component | Files | Responsibility |
|-----------|-------|---------------|
| CmuxWebView | Sources/Panels/CmuxWebView.swift | WKWebView wrapper with scriptable API |
| BrowserFindJavaScript | Sources/Find/BrowserFindJavaScript.swift | JS injection for browser find |
| BrowserSearchOverlay | Sources/Find/BrowserSearchOverlay.swift | Browser search UI |

## 3. Data Flow

### 3.1 Terminal Input Path (Latency-Critical)

```
Keystroke → AppDelegate.performKeyEquivalent
         → TerminalWindowPortal.hitTest (pointer events only)
         → ghostty_surface_key_event (libghostty)
         → PTY write → Shell process
         → PTY read → ghostty_surface wakeup
         → GPU render → Display
```

**Constraint**: No allocations, file I/O, or formatting in this path.

### 3.2 Socket Command Path

```
CLI (cmux <command>) → Unix socket connect
                     → Socket server parse (off-main for telemetry)
                     → DispatchQueue.main.async (UI mutations only)
                     → Response → CLI stdout
```

### 3.3 Notification Path

```
Terminal OSC 9/99/777 → libghostty callback
                      → TerminalNotificationStore.add
                      → Workspace.hasUnread = true
                      → Sidebar tab lights up (blue ring)
                      → macOS notification (if configured)
```

## 4. Platform Abstraction Strategy

### 4.1 Current State

The codebase is 100% macOS-specific:
- SwiftUI + AppKit for all UI
- WKWebView for browser
- Sparkle for updates
- AppKit NSApplication lifecycle
- macOS-specific entitlements and sandbox

### 4.2 Cross-Platform Strategy (ADR-001)

**Decision**: Introduce a Platform Abstraction Layer (PAL) that isolates OS-specific code behind protocol/interface boundaries.

**Approach**:
1. **Shared core**: Workspace model, notification logic, config parsing, session persistence, socket protocol — these are platform-agnostic
2. **PAL protocols**: Define Swift protocols for platform-dependent operations (window management, browser embedding, update checking, clipboard, file dialogs)
3. **Platform implementations**: macOS uses existing AppKit/SwiftUI; Linux uses GTK4 via Swift bindings or a separate frontend
4. **Build system**: Conditional compilation (`#if os(macOS)` / `#if os(Linux)`) at PAL boundaries only; core logic has no platform conditionals

**Rationale**: This preserves the existing macOS codebase while enabling Linux support without a full rewrite. libghostty already cross-compiles. The Go daemon already runs on Linux.

**Alternatives rejected**:
- Full rewrite in cross-platform framework (too expensive, loses native feel)
- Electron wrapper (contradicts core value proposition of native performance)
- Separate codebases per platform (maintenance nightmare)

## 5. Architecture Decision Records

### ADR-001: Platform Abstraction Layer for Cross-Platform Support

- **Date**: 2026-03-26
- **Status**: Proposed
- **Context**: cmux is macOS-only but based on Ghostty which supports Linux. Users need Linux support.
- **Decision**: Introduce PAL protocols to abstract OS-specific code; implement Linux frontend using GTK4 or equivalent.
- **Consequences**: Some performance overhead from abstraction; need to maintain two UI implementations; core logic becomes truly portable.

### ADR-002: Ghostty as Terminal Engine

- **Date**: Pre-existing (inherited)
- **Status**: Accepted
- **Context**: Need GPU-accelerated terminal rendering.
- **Decision**: Use libghostty (Zig library) for terminal rendering, VT parsing, PTY management.
- **Consequences**: Ties to Ghostty fork; benefits from Ghostty's cross-platform support; requires Zig build toolchain.

### ADR-003: Bonsplit for Split Pane Management

- **Date**: Pre-existing (inherited)
- **Status**: Accepted
- **Context**: Need vertical/horizontal split panes with tab bars.
- **Decision**: Vendor Bonsplit as a submodule.
- **Consequences**: Currently macOS-only (SwiftUI); will need Linux port or replacement for cross-platform.

### ADR-004: Socket API Dual Protocol (v1 + v2)

- **Date**: Pre-existing (inherited)
- **Status**: Accepted
- **Context**: Need scriptable automation API.
- **Decision**: Support both v1 (text) and v2 (JSON-RPC) protocols over Unix socket.
- **Consequences**: Maintains backwards compatibility; v2 is the future; both must be tested.

### ADR-005: Go for Remote Daemon

- **Date**: Pre-existing (inherited)
- **Status**: Accepted
- **Context**: Need a lightweight daemon binary deployable to remote SSH hosts.
- **Decision**: Write cmuxd-remote in Go for easy cross-compilation and static linking.
- **Consequences**: Separate language from main app; simple deployment to any Linux/macOS remote.

## 6. Build System

### 6.1 macOS

- **Xcode project**: `GhosttyTabs.xcodeproj` (scheme: `cmux`)
- **SPM**: `Package.swift` (SwiftTerm dependency)
- **GhosttyKit**: Pre-built xcframework or built from source via Zig
- **Signing**: Apple Developer certificate, notarization, Sparkle for updates

### 6.2 Linux (Planned)

- **Build**: Swift Package Manager or CMake
- **Dependencies**: libghostty (Zig build), GTK4, WebKitGTK
- **Distribution**: AppImage, Flatpak, or native packages

### 6.3 Remote Daemon

- **Build**: `go build` in `daemon/remote/`
- **Cross-compile**: `GOOS=linux/darwin GOARCH=arm64/amd64`
- **Optimization**: `zig build -Doptimize=ReleaseFast` when building via Zig

## 7. Security Model

- **Sandbox**: macOS app sandbox with entitlements
- **Socket auth**: Password-protected socket control
- **Daemon trust**: SHA-256 digest verification for remote daemon artifacts
- **Relay auth**: HMAC-SHA256 challenge-response for CLI relay
- **Directory trust**: CmuxDirectoryTrust for config file trust decisions

## 8. Key Constraints

1. **Typing latency**: Must not regress from cross-platform abstraction (see CLAUDE.md pitfalls)
2. **Ghostty compatibility**: Must read existing `~/.config/ghostty/config`
3. **Socket focus policy**: Commands must not steal macOS app focus
4. **Thread safety**: High-frequency socket telemetry must be off-main-thread
5. **Localization**: All user-facing strings must use `String(localized:defaultValue:)`
