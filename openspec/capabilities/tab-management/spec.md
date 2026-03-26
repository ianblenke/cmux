# Tab Management Specification

**Status**: EXTRACTED
**Last Updated**: 2026-03-26

## Overview

Tab management provides the `TabManager` class that owns the ordered list of workspaces within a window, handles workspace selection, creation, reordering, closing, session persistence, and coordinates workspace-level operations like git metadata probing and notification routing.

## Requirements

### REQ-TM-001: Workspace list management
- **Description**: `TabManager` maintains an ordered `@Published var tabs: [Workspace]` array. A new TabManager is initialized with one default workspace. The list always contains at least one workspace (closing the last workspace is prevented).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-TM-002: Workspace selection
- **Description**: `selectedTabId` tracks the currently active workspace UUID. `selectWorkspace()` sets the selection and triggers workspace switch animations. `selectedWorkspace` computed property returns the active Workspace instance.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-TM-003: Add workspace with configurable placement
- **Description**: `addWorkspace()` creates a new workspace with optional working directory, initial command, and environment. Placement is configurable via `WorkspacePlacementSettings`: top (after pinned), after current, or end. Returns the new Workspace for further configuration.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-TM-004: Workspace placement insertion index calculation
- **Description**: `WorkspacePlacementSettings.insertionIndex()` computes correct insertion position considering pinned workspace count, selected index, and placement preference. Pinned workspaces always stay grouped at the top.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-TM-005: Close workspace with confirmation
- **Description**: `closeWorkspace()` removes a workspace from the list. `closeWorkspaceWithConfirmation()` shows a dialog if the workspace is pinned or has running processes. Closing the last workspace is blocked. Selection moves to the adjacent workspace after close.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-TM-006: Bulk workspace close
- **Description**: `closeWorkspacesWithConfirmation()` handles closing multiple workspaces (e.g., "close others"). Shows a summary dialog listing workspace titles. Respects `allowPinned` flag.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-TM-007: Child exit closes workspace
- **Description**: `closePanelAfterChildExited()` handles the case where a terminal's child process exits. If it was the last panel in the workspace, the workspace is closed and selection stays at the same index.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-TM-008: Workspace reordering
- **Description**: `reorderWorkspace(tabId:toIndex:)` moves a workspace to a target index. Also supports `reorderWorkspace(tabId:before:)` and `reorderWorkspace(tabId:after:)` for relative positioning. Returns false if the tab is not found.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-TM-009: Next/previous workspace navigation
- **Description**: `selectNextTab()` and `selectPreviousTab()` cycle through workspaces with wraparound. Navigation activates the workspace cycle "hot window" for visual feedback.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-TM-010: Surface navigation within workspace
- **Description**: `selectNextSurface()`, `selectPreviousSurface()`, `selectSurface(at:)`, and `selectLastSurface()` delegate to the selected workspace to cycle through surfaces (panels) in the focused pane.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-TM-011: Session snapshot and restore
- **Description**: `sessionSnapshot(includeScrollback:)` serializes workspace list, selection, and per-workspace state to `SessionTabManagerSnapshot`. `restoreSessionSnapshot()` rebuilds workspace list from snapshot. Remote workspaces are excluded from snapshots.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-TM-012: Session restore with empty snapshot
- **Description**: When restoring an empty snapshot (zero workspaces), TabManager creates a single fallback workspace to maintain the minimum-one-workspace invariant.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-TM-013: Remote workspaces excluded from session persistence
- **Description**: Workspaces with active remote connections (`isRemoteWorkspace`) are filtered out of session snapshots since the remote processes are gone after restart.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-TM-014: Workspace auto-reorder on notification
- **Description**: When `WorkspaceAutoReorderSettings.isEnabled`, workspaces receiving notifications can be automatically promoted in the sidebar order.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P2 (nice-to-have)

### REQ-TM-015: Last surface close behavior setting
- **Description**: `LastSurfaceCloseShortcutSettings.closesWorkspace()` controls whether Cmd+W on the last surface in a workspace closes the entire workspace (default true) or keeps the workspace with an empty pane.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-TM-016: Window ownership
- **Description**: `TabManager.window` is a weak reference to the owning `NSWindow`, set by `AppDelegate.registerMainWindow()`. Used for window title updates and focus management.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-TM-017: Workspace cycle hot window
- **Description**: `isWorkspaceCycleHot` is set during rapid next/previous cycling to show an overlay workspace switcher. Deactivates after a delay.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-TM-018: Recently closed browser stack
- **Description**: `RecentlyClosedBrowserStack` maintains a bounded LIFO stack of closed browser panel snapshots for Cmd+Shift+T restore. Capacity is configurable.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-TM-019: Port ordinal assignment
- **Description**: `TabManager` maintains a static monotonically increasing `nextPortOrdinal` counter so port ranges don't overlap across multiple windows.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-TM-020: Git metadata probing
- **Description**: `TabManager` probes workspaces for git branch, dirty status, and GitHub pull request information. Results feed the sidebar display. Probes are keyed by `(workspaceId, panelId)` to handle multi-panel workspaces.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-TM-021: Background workspace preloading
- **Description**: `pendingBackgroundWorkspaceLoadIds` tracks workspaces being primed in the background for faster switching. Background-loaded workspaces are mounted but not visible.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P2 (nice-to-have)

## Scenarios

### SCENARIO-TM-001: Child exit on last panel closes workspace and maintains selection index
- **Given**: Three workspaces exist, the second is selected with one panel
- **When**: `closePanelAfterChildExited` is called for the second workspace's panel
- **Then**: The second workspace is removed; selection moves to the third workspace (same index)
- **Verifies**: REQ-TM-007
- **Status**: Covered

### SCENARIO-TM-002: Session snapshot serializes and restores workspace list
- **Given**: Two workspaces with custom titles, second selected
- **When**: Session snapshot is taken and restored to a new TabManager
- **Then**: Restored TabManager has two workspaces with matching titles; second is selected
- **Verifies**: REQ-TM-011
- **Status**: Covered

### SCENARIO-TM-003: Restore empty session snapshot creates fallback workspace
- **Given**: An empty session snapshot (zero workspaces)
- **When**: `restoreSessionSnapshot` is called
- **Then**: TabManager has exactly one workspace with a non-nil selection
- **Verifies**: REQ-TM-012
- **Status**: Covered

### SCENARIO-TM-004: Remote workspaces excluded from session snapshot
- **Given**: A TabManager with one local and one remote workspace
- **When**: Session snapshot is taken
- **Then**: Snapshot contains only the local workspace; selected index is nil
- **Verifies**: REQ-TM-013
- **Status**: Covered

### SCENARIO-TM-005: Next workspace wraps around
- **Given**: Three workspaces, last one selected
- **When**: `selectNextTab()` is called
- **Then**: Selection wraps to the first workspace
- **Verifies**: REQ-TM-009
- **Status**: Missing

### SCENARIO-TM-006: Previous workspace wraps around
- **Given**: Three workspaces, first one selected
- **When**: `selectPreviousTab()` is called
- **Then**: Selection wraps to the last workspace
- **Verifies**: REQ-TM-009
- **Status**: Missing

### SCENARIO-TM-007: Insertion index for "after current" placement
- **Given**: 5 workspaces, index 2 selected, no pinned workspaces
- **When**: Insertion index is computed for `.afterCurrent`
- **Then**: Returns 3
- **Verifies**: REQ-TM-004
- **Status**: Missing

### SCENARIO-TM-008: Insertion index for "top" placement respects pinned count
- **Given**: 5 workspaces, 2 pinned
- **When**: Insertion index is computed for `.top`
- **Then**: Returns 2 (after pinned group)
- **Verifies**: REQ-TM-004
- **Status**: Missing

### SCENARIO-TM-009: Close last workspace is blocked
- **Given**: A TabManager with exactly one workspace
- **When**: `closeWorkspace()` is called
- **Then**: The workspace is not removed; tabs still has count 1
- **Verifies**: REQ-TM-005
- **Status**: Missing

### SCENARIO-TM-010: Workspace reorder by index
- **Given**: Three workspaces [A, B, C]
- **When**: B is reordered to index 0
- **Then**: Order becomes [B, A, C]
- **Verifies**: REQ-TM-008
- **Status**: Missing

## Cross-Platform Notes

- `TabManager` core logic (workspace list, selection, reorder, session persistence) is platform-agnostic.
- `window` property and `NSWindow` integration are macOS-specific; Linux will need a window abstraction.
- Git probing uses `Process` which works on both macOS and Linux.
- `UserDefaults` settings storage needs a cross-platform equivalent on Linux (e.g., file-based prefs).
- Keyboard shortcuts (Cmd+W, Cmd+Shift+T) need platform-specific key mapping.

## Implementation Status

All core TabManager operations are fully implemented on macOS. Session persistence is working including scrollback preservation. Git metadata probing and PR sidebar display are implemented. Several behavioral scenarios lack dedicated unit test coverage (wraparound navigation, placement index, close-last prevention).
