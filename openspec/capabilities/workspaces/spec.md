# Workspaces Specification

**Status**: EXTRACTED
**Last Updated**: 2026-03-26

## Overview

Workspaces are the primary organizational unit in cmux. Each workspace is an independent container with its own split pane tree, panel collection, title, color, directory context, git metadata, remote connection state, and sidebar presence. Workspaces replace the concept of traditional terminal tabs with a richer, workspace-oriented model.

## Requirements

### REQ-WS-001: Workspace identity and observable state
- **Description**: `Workspace` is an `Identifiable`, `ObservableObject` class with a UUID `id`. Published properties include `title`, `customTitle`, `isPinned`, `customColor` (hex string), `currentDirectory`, `panels`, `panelDirectories`, `panelTitles`, `panelCustomTitles`, `pinnedPanelIds`, and `manualUnreadPanelIds`.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-WS-002: Panel collection management
- **Description**: `panels: [UUID: any Panel]` maps panel IDs to Panel instances (terminal, browser, markdown). Panels are created via `newTerminalSurface()`, `newBrowserSurface()`, and closed via `closePanel()`. The workspace maintains bidirectional mapping between Bonsplit TabIDs and panel UUIDs via `surfaceIdToPanelId`.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-WS-003: Focused panel tracking
- **Description**: `focusedPanelId` is a computed property that resolves the focused pane's selected tab to a panel ID. `focusedTerminalPanel` returns the focused terminal panel (if any). `focusPanel()` sets focus with optional trigger context.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-WS-004: Terminal surface creation
- **Description**: `newTerminalSurface(inPane:focus:workingDirectory:)` creates a new terminal panel in a specific pane. Supports optional working directory override and focus control. `newTerminalSurfaceInFocusedPane()` is a convenience wrapper.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-WS-005: Browser surface creation
- **Description**: `newBrowserSurface(inPane:url:focus:)` creates a new browser panel in a specific pane. Supports optional initial URL and focus control.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-WS-006: Panel close
- **Description**: `closePanel(_:force:)` removes a panel from the workspace. When `force` is true, close confirmation is bypassed. Closing the last panel in a pane may trigger pane collapse.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-WS-007: Split creation from panel
- **Description**: `newTerminalSplit(from:orientation:insertFirst:focus:)` creates a new split pane with a terminal surface. Finds the source pane, splits it, and creates a terminal in the new pane.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-WS-008: Surface reordering within pane
- **Description**: `reorderSurface(panelId:toIndex:)` moves a panel to a specific index within its pane's tab list.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-WS-009: Surface navigation (next/previous/index/last)
- **Description**: `selectNextSurface()`, `selectPreviousSurface()`, `selectSurface(at:)`, and `selectLastSurface()` cycle through surfaces in the focused pane.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-WS-010: Custom workspace title
- **Description**: `setCustomTitle()` sets a user-defined workspace title. `customTitle` overrides the process-derived `title` in sidebar display.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-WS-011: Custom workspace color
- **Description**: `customColor` stores a hex color string (e.g., "#C0392B") for sidebar accent coloring. Color palette managed by `WorkspaceTabColorSettings` with default palette, custom colors (up to 24), and per-color overrides.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-WS-012: Workspace pinning
- **Description**: `isPinned` marks a workspace as pinned. Pinned workspaces are grouped at the top of the sidebar. Closing pinned workspaces requires confirmation. New workspace insertion respects pinned count.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-WS-013: Panel pinning
- **Description**: `pinnedPanelIds: Set<UUID>` tracks pinned panels within the workspace. Pinned panels show a pin indicator in the pane tab bar.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P2 (nice-to-have)

### REQ-WS-014: Manual unread marking
- **Description**: `manualUnreadPanelIds: Set<UUID>` tracks manually marked unread panels. `shouldClearManualUnread()` determines when to auto-clear based on focus changes, with a grace interval to prevent immediate clearing on mark.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-WS-015: Unread indicator display logic
- **Description**: `Workspace.shouldShowUnreadIndicator()` combines notification-based unread state and manual unread state to determine indicator visibility.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-WS-016: Session snapshot and restore
- **Description**: `sessionSnapshot(includeScrollback:)` serializes workspace state including: process title, custom title, custom color, pinned state, directory, focused panel, split layout, panel snapshots (terminal scrollback, browser URL/history, markdown path), status entries, log entries, progress, git branch.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-WS-017: Session layout snapshot (split tree)
- **Description**: Split tree is serialized recursively as `SessionWorkspaceLayoutSnapshot` (`.pane` with panel IDs and selection, or `.split` with orientation, divider position, and two children).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-WS-018: Session panel snapshot by type
- **Description**: Each panel type has specific snapshot data: terminals get working directory and scrollback; browsers get URL, profile ID, zoom, dev tools state, and navigation history; markdown panels get file path.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-WS-019: Terminal scrollback persistence
- **Description**: Terminal scrollback is captured for session snapshots with line limits. Falls back to previously restored scrollback when live capture unavailable. `SessionPersistencePolicy` enforces max lines and workspace/panel limits.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-WS-020: Remote workspace configuration
- **Description**: `configureRemoteConnection()` sets up SSH-based remote sessions with destination, port, identity file, SSH options, relay configuration, and local socket path. Remote workspaces support daemon manifest for cross-platform binary distribution.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-WS-021: Remote daemon manifest
- **Description**: `WorkspaceRemoteDaemonManifest` describes available remote daemon binaries by OS/arch with SHA256 checksums. Used for automatic remote daemon deployment.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-WS-022: Sidebar metadata (status entries, log, progress, git)
- **Description**: Workspaces display rich sidebar metadata: `statusEntries` (key-value with icon/color/url/priority), `logEntries` (message/level/source/timestamp), `progress` (value/label), `gitBranch` (branch name/dirty state), `pullRequest` (number/label/url/status/checks).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-WS-023: Panel-level git branch and PR tracking
- **Description**: `panelGitBranches` and `panelPullRequests` track per-panel git state. `sidebarPullRequestsInDisplayOrder()` resolves the best PR state across panels, filtering branch mismatches and preferring the highest-quality state.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-WS-024: Listening ports tracking
- **Description**: `surfaceListeningPorts` tracks per-panel listening ports (from `CMUX_PORT` and runtime detection). Port ordinal assignment uses session-wide base and range from UserDefaults.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-WS-025: Workspace attention flash
- **Description**: `triggerDebugFlash()` and notification-driven flash trigger a visual flash animation on a panel. `tmuxWorkspaceFlashPanelId`, `tmuxWorkspaceFlashReason`, and `tmuxWorkspaceFlashToken` coordinate flash state. `WorkspaceAttentionFlashReason` distinguishes navigation, notification arrival, dismissal, manual unread, and debug.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P2 (nice-to-have)

### REQ-WS-026: Tmux layout snapshot
- **Description**: `tmuxLayoutSnapshot` stores the current tmux pane layout for overlay rendering. `effectiveTmuxLayoutSnapshot()` falls back to cached snapshots when live snapshots have no renderable geometry.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P2 (nice-to-have)

### REQ-WS-027: Workspace presentation mode
- **Description**: `WorkspacePresentationModeSettings` supports "minimal" mode (titlebar-less, Bonsplit tab bar only) and standard mode. Minimal mode uses `ignoresSafeArea(.container, edges: .top)` and a titlebar double-click monitor.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-WS-028: Sidebar detail visibility settings
- **Description**: `SidebarWorkspaceDetailSettings` controls visibility of metadata, notification messages, and auxiliary details. `SidebarWorkspaceAuxiliaryDetailVisibility` resolves per-item visibility with a global "hide all" override.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P2 (nice-to-have)

### REQ-WS-029: Sidebar active tab indicator style
- **Description**: `SidebarActiveTabIndicatorSettings` supports "left rail" and "solid fill" indicator styles with legacy value migration.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P2 (nice-to-have)

### REQ-WS-030: Sidebar branch layout
- **Description**: `SidebarBranchLayoutSettings` controls whether sidebar branch/directory info uses vertical or horizontal layout.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P2 (nice-to-have)

### REQ-WS-031: Workspace tab color palette
- **Description**: `WorkspaceTabColorSettings` provides a 16-color default palette with named entries, per-color hex overrides, and up to 24 user-defined custom colors. Colors are brightened for dark mode display.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-WS-032: Font size inheritance across panels
- **Description**: `lastTerminalConfigInheritancePanelId` and `lastTerminalConfigInheritanceFontPoints` track the last focused terminal's font size. New terminal surfaces inherit this zoom level. Per-panel lineage tracked in `terminalInheritanceFontPointsByPanelId`.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-WS-033: Ghostty chrome synchronization
- **Description**: `applyGhosttyChrome(from:reason:)` propagates theme colors from GhosttyConfig to the BonsplitController's chrome appearance (background, divider colors). Triggered on theme change, color scheme change, and workspace activation.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

## Scenarios

### SCENARIO-WS-001: Manual unread cleared when focus moves to different panel
- **Given**: Panel A is manually marked unread, panel B exists
- **When**: Focus moves from A to B
- **Then**: Panel A's manual unread is cleared
- **Verifies**: REQ-WS-014
- **Status**: Covered

### SCENARIO-WS-002: Manual unread not cleared within grace interval on same panel
- **Given**: Panel is marked unread 0.05s ago, focus re-enters same panel
- **When**: `shouldClearManualUnread` is evaluated with 0.2s grace
- **Then**: Returns false (within grace period)
- **Verifies**: REQ-WS-014
- **Status**: Covered

### SCENARIO-WS-003: Manual unread cleared after grace interval on same panel
- **Given**: Panel is marked unread 0.25s ago, focus re-enters same panel
- **When**: `shouldClearManualUnread` is evaluated with 0.2s grace
- **Then**: Returns true (grace period expired)
- **Verifies**: REQ-WS-014
- **Status**: Covered

### SCENARIO-WS-004: Manual unread not cleared when not marked unread
- **Given**: Panel is not manually marked unread
- **When**: Focus changes between panels
- **Then**: `shouldClearManualUnread` returns false
- **Verifies**: REQ-WS-014
- **Status**: Covered

### SCENARIO-WS-005: Manual unread not cleared when no previous focus within grace
- **Given**: No previous focused panel (nil), panel marked unread 0.05s ago
- **When**: `shouldClearManualUnread` is evaluated
- **Then**: Returns false
- **Verifies**: REQ-WS-014
- **Status**: Covered

### SCENARIO-WS-006: Sidebar PR ignores stale workspace-level cache without panel state
- **Given**: Workspace has workspace-level PR state but no per-panel PR/branch state
- **When**: `sidebarPullRequestsInDisplayOrder` is called
- **Then**: Returns empty (stale workspace-level cache ignored)
- **Verifies**: REQ-WS-023
- **Status**: Covered

### SCENARIO-WS-007: Sidebar PR filters branch mismatch per panel
- **Given**: Panel has branch "main" but PR references branch "feature/old"
- **When**: `sidebarPullRequestsInDisplayOrder` is called
- **Then**: Returns empty (branch mismatch filtered)
- **Verifies**: REQ-WS-023
- **Status**: Covered

### SCENARIO-WS-008: Sidebar PR prefers best state across panels
- **Given**: Two panels with same PR number, one open with passing checks, one merged
- **When**: `sidebarPullRequestsInDisplayOrder` is called
- **Then**: Returns the merged state (best/most advanced)
- **Verifies**: REQ-WS-023
- **Status**: Covered

### SCENARIO-WS-009: Selected workspace background color matches accent for dark mode
- **Given**: Dark color scheme
- **When**: `sidebarSelectedWorkspaceBackgroundNSColor(for: .dark)` is called
- **Then**: Returns accent blue (0, 145/255, 1.0, alpha 1.0)
- **Verifies**: REQ-WS-001
- **Status**: Covered

### SCENARIO-WS-010: Workspace session snapshot includes custom title and pinned state
- **Given**: A workspace with custom title "Test" and isPinned = true
- **When**: Session snapshot is taken
- **Then**: Snapshot contains customTitle: "Test", isPinned: true
- **Verifies**: REQ-WS-016
- **Status**: Covered

### SCENARIO-WS-011: Session restore rebuilds panel order and focus
- **Given**: A snapshot with two terminal panels, second selected
- **When**: Session is restored
- **Then**: Workspace has two panels in correct order, focus matches snapshot
- **Verifies**: REQ-WS-016
- **Status**: Covered

### SCENARIO-WS-012: Tab color hex normalization
- **Given**: Raw hex values with mixed case and missing/present `#` prefix
- **When**: `normalizedHex` is called
- **Then**: Returns uppercase 6-char hex with `#` prefix, or nil for invalid
- **Verifies**: REQ-WS-031
- **Status**: Missing

### SCENARIO-WS-013: Custom color palette respects maximum count
- **Given**: More than 24 custom colors are added
- **When**: Custom colors list is retrieved
- **Then**: List is capped at 24 entries
- **Verifies**: REQ-WS-031
- **Status**: Missing

### SCENARIO-WS-014: Workspace creation stress test (p95 budget)
- **Given**: 48 workspaces each with 10 tabs
- **When**: Creation and switching are profiled
- **Then**: p95 creation and switch times are within budget
- **Verifies**: REQ-WS-001, REQ-WS-004
- **Status**: Covered (stress profile test)

### SCENARIO-WS-015: Remote workspace excluded from session snapshot
- **Given**: A workspace with remote SSH configuration
- **When**: Session snapshot is taken
- **Then**: Remote workspace is not included in snapshot
- **Verifies**: REQ-WS-020
- **Status**: Covered

### SCENARIO-WS-016: Sidebar active tab indicator style migration
- **Given**: Legacy style value "washRail"
- **When**: `resolvedStyle` is called
- **Then**: Maps to `.solidFill`
- **Verifies**: REQ-WS-029
- **Status**: Missing

## Cross-Platform Notes

- `Workspace` core model (panels, titles, colors, pinning, unread) is platform-agnostic.
- `BonsplitController` integration needs platform abstraction for its view layer.
- `NSColor`-based color operations need cross-platform equivalent.
- Remote connection configuration (SSH) works cross-platform.
- `AppStorage` / `UserDefaults` need Linux equivalent.
- Window-level operations (transparent background, glass effects) are macOS-specific.
- Sidebar UI (SwiftUI) needs platform-conditional rendering for Linux.

## Implementation Status

All workspace requirements are fully implemented on macOS. Session persistence including scrollback, split layouts, and browser history is working. Remote workspace support with daemon deployment is implemented. Sidebar metadata (git, PR, status, progress, logs) is fully functional. Tab color palette with customization is complete. Some edge-case scenarios lack dedicated unit test coverage (hex normalization, custom color cap, legacy style migration).
