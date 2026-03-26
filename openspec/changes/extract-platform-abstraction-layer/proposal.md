## Why

cmux is currently a macOS-only application with platform-specific code (AppKit, SwiftUI, WKWebView, Sparkle) deeply interleaved with platform-agnostic logic (workspace model, tab management, config parsing, socket control, session persistence, notification store). This makes a Linux port impossible without a full rewrite. Extracting a Platform Abstraction Layer (PAL) is the necessary first step — it separates shared core logic from OS-specific UI code behind protocol boundaries, enabling Linux (and future platform) backends without touching the core. This is Phase 1 of ADR-001 and is a non-breaking refactor: zero behavior change on macOS, all existing tests pass.

## What Changes

- **Define PAL protocols** in new `Sources/PAL/` directory — `PlatformWindow`, `PlatformSurface`, `PlatformWebView`, `PlatformSplitContainer`, `PlatformClipboard`, `PlatformNotification`, `PlatformMenuBar`, `PlatformKeyboard`, `PlatformDragDrop`, `PlatformUpdateChecker`, `PlatformAppLifecycle`, `PlatformFileDialog`, `PlatformAppearance`
- **Move shared logic** to `Sources/Core/` — Workspace model, TabManager, SessionPersistence, CmuxConfig, CmuxConfigExecutor, GhosttyConfig, SocketControlSettings, TerminalNotificationStore, PortScanner, TerminalSSHSessionDetector, KeyboardShortcutSettings (model layer), SidebarSelectionState (model layer)
- **Create macOS backend** in `Sources/macOS/` — thin wrappers implementing PAL protocols around existing AppKit/SwiftUI code
- **Update imports** — Core code imports PAL protocols only; macOS code imports AppKit/SwiftUI
- **Update build targets** — SPM `Package.swift` gets `cmux-core`, `cmux-pal`, and `cmux-macos` targets; Xcode project updated to match

## Capabilities

### New Capabilities
- `platform-abstraction-layer`: Defines the PAL protocol suite, platform type aliases, and cross-platform path conventions. This is the interface contract between core logic and platform backends.

### Modified Capabilities
- `cross-platform`: REQ-XP-001 (PAL exists), REQ-XP-002 (PAL protocol definitions), REQ-XP-003 (capability detection) move from Proposed to Implemented
- `terminal-core`: REQ-TC-001 through REQ-TC-020 — implementation moves behind PlatformSurface protocol; no behavioral change
- `tab-management`: REQ-TM-001 through REQ-TM-021 — TabManager moves to Core; no behavioral change
- `workspaces`: REQ-WS-001 through REQ-WS-033 — Workspace model moves to Core; no behavioral change
- `session-persistence`: REQ-SPE-001 through REQ-SPE-014 — SessionPersistence moves to Core; no behavioral change
- `notifications`: REQ-NT-001 through REQ-NT-017 — TerminalNotificationStore model moves to Core; delivery stays platform-specific
- `socket-control`: REQ-SC-001 through REQ-SC-016 — SocketControlSettings moves to Core; no behavioral change
- `configuration`: REQ-CF-001 through REQ-CF-022 — Config parsing moves to Core; no behavioral change

## Platform Abstraction

This change is entirely about platform abstraction. Every source file is classified as:
- **Core** (no platform imports) — moved to `Sources/Core/`
- **PAL** (protocol definitions) — new in `Sources/PAL/`
- **macOS** (AppKit/SwiftUI implementations) — moved to `Sources/macOS/`

The key constraint: `Sources/Core/` must not import AppKit, SwiftUI, Cocoa, WebKit, or any macOS framework. Only Foundation and PAL protocols.

## Impact

- **Source layout**: Major reorganization from flat `Sources/` to `Sources/{Core,PAL,macOS}/`
- **Build system**: `Package.swift` needs new targets; `GhosttyTabs.xcodeproj` needs updated file references
- **Imports**: Every Swift file gets updated imports (Core files drop AppKit; macOS files add explicit imports)
- **No API changes**: Socket API, CLI, config format all unchanged
- **No behavioral changes**: All 46 existing tests must pass without modification
- **Dependencies**: No new external dependencies; internal dependency graph becomes explicit
