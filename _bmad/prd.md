# Product Requirements Document — cmux

**Version**: 1.0.0
**Last Updated**: 2026-03-26
**Status**: EXTRACTED (backfilled from existing codebase)

---

## 1. Product Vision

cmux is a cross-platform, Ghostty-based terminal multiplexer designed for developers who run multiple AI coding agents in parallel. It provides composable primitives — terminals, browsers, notifications, workspaces, splits, tabs, and a CLI — rather than prescriptive workflows.

**Tagline**: A Ghostty-based terminal with vertical tabs and notifications for AI coding agents.

## 2. Problem Statement

Developers running multiple Claude Code, Codex, or other AI coding sessions simultaneously face:

1. **Notification blindness**: Native OS notifications lack context ("Claude is waiting for your input" with no terminal identity)
2. **Tab overload**: With enough tabs, window titles become unreadable
3. **Performance**: Electron/Tauri-based orchestrators have noticeable latency for terminal workloads
4. **Workflow lock-in**: GUI orchestrators force specific workflows; terminals are more composable
5. **Platform limitation**: The original cmux targets macOS only; Linux developers need the same capabilities

## 3. Target Users

1. **Power developers** running 3+ AI coding agent sessions concurrently
2. **DevOps/SRE** managing multiple remote SSH sessions
3. **Open source contributors** who need a fast, scriptable terminal on Linux and macOS

## 4. Core Product Requirements

### 4.1 Terminal Rendering (terminal-core)

The application must provide GPU-accelerated terminal rendering using libghostty, compatible with existing Ghostty configuration files.

### 4.2 Workspace Management (workspaces)

Workspaces are the primary organizational unit. Each workspace appears as a sidebar entry and contains one or more panes with surfaces.

### 4.3 Tab Management (tab-management)

Vertical sidebar tabs display rich metadata: git branch, PR status/number, working directory, listening ports, latest notification text.

### 4.4 Split Panes (split-panes)

Horizontal and vertical pane splitting within workspaces, with directional focus navigation.

### 4.5 Browser Panels (browser-panels)

In-app browser with a scriptable API ported from agent-browser. Agents can snapshot accessibility trees, get element refs, click, fill forms, evaluate JS.

### 4.6 Notification System (notifications)

Terminal notification detection (OSC 9/99/777) and a CLI notification API. Panes get blue rings, tabs light up. Jump-to-unread navigation.

### 4.7 Session Persistence (session-persistence)

Restore window/workspace/pane layout, working directories, terminal scrollback, and browser URLs on relaunch. Live process state is NOT restored.

### 4.8 Socket Control & CLI (socket-control)

Full scriptability through CLI and Unix socket API with v1 (text) and v2 (JSON-RPC) protocols. Create workspaces, split panes, send keystrokes, automate browser.

### 4.9 Configuration (configuration)

Read Ghostty config files for themes, fonts, colors. Additional cmux-specific configuration.

### 4.10 Keyboard Shortcuts (keyboard-shortcuts)

Comprehensive keyboard shortcuts for workspaces, surfaces, splits, browser, notifications, find, terminal, and window operations. Customizable via settings.

### 4.11 Search/Find (search-find)

Find-in-terminal and find-in-browser with next/previous navigation.

### 4.12 Update System (update-system)

Auto-update via Sparkle (macOS). Nightly build channel with separate bundle ID.

### 4.13 Remote SSH (remote-daemon)

`cmux ssh` for durable remote terminals with reconnect/reuse, browser traffic proxying via remote host, and daemon-managed sessions.

### 4.14 SSH Session Detection (ssh-detection)

Detect when a terminal is connected to a remote host via SSH.

### 4.15 Window Management (window-management)

Native window management with toolbar, decorations, drag handles, and multi-window support.

### 4.16 Sidebar (sidebar)

Vertical sidebar with workspace list, rich metadata display, drag-and-drop reordering, resize, and help menu.

### 4.17 AppleScript Support (applescript)

AppleScript integration for macOS automation workflows.

### 4.18 Port Scanning (port-scanning)

Detect listening ports in terminal sessions for sidebar display and browser integration.

### 4.19 Analytics (analytics)

Optional PostHog analytics and Sentry error reporting.

### 4.20 Localization (localization)

All user-facing strings localized. Currently English and Japanese. 19 README translations.

### 4.21 Cross-Platform (cross-platform)

**NEW CAPABILITY**: Port cmux from macOS-only to cross-platform (macOS + Linux), with a platform abstraction layer (PAL) enabling future Ghostty-compatible platforms.

## 5. Non-Functional Requirements

| Category | Requirement |
|----------|-------------|
| Performance | Native app performance; no Electron. Sub-100ms keystroke-to-render latency. |
| Memory | Lower memory footprint than Electron alternatives |
| Startup | Fast cold start (<1s on modern hardware) |
| Compatibility | Read existing Ghostty config files |
| Security | Sandbox entitlements, socket authentication, daemon artifact trust via SHA-256 |
| Accessibility | macOS accessibility APIs; keyboard-navigable UI |
| Localization | All UI strings localizable; XCStrings format |

## 6. Out of Scope (Current Phase)

- Live process state restoration (tmux/vim sessions)
- Windows platform support
- Built-in AI agent integration (cmux is a primitive, not a solution)
- Collaboration features (screen sharing, pair programming)

## 7. Success Metrics

- Feature parity between macOS and Linux builds
- All existing tests passing on both platforms
- No typing latency regression from cross-platform abstraction
- Ghostty config compatibility maintained

## 8. Dependencies

| Dependency | Purpose | Platform |
|-----------|---------|----------|
| libghostty | Terminal rendering | All (Zig, cross-compiles) |
| Bonsplit | Tab/pane split UI | macOS (Swift); needs Linux port |
| WKWebView / WebKitGTK | Browser panels | macOS / Linux |
| Sparkle | Auto-update | macOS only |
| SwiftUI + AppKit / GTK4 | UI framework | macOS / Linux |
