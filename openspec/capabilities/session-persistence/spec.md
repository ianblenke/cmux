# Session Persistence Specification

**Status**: EXTRACTED
**Last Updated**: 2026-03-26

## Overview

Session persistence saves and restores the complete cmux application state (windows, workspaces, panels, split layouts, sidebar configuration, and terminal scrollback) across application restarts using JSON snapshots stored in the Application Support directory.

## Requirements

### REQ-SPE-001: Snapshot schema versioning
- **Description**: All snapshots include a `version` field (`SessionSnapshotSchema.currentVersion = 1`). Load rejects snapshots with mismatched versions to prevent data corruption from schema changes.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SPE-002: Full application state capture
- **Description**: `AppSessionSnapshot` captures an array of `SessionWindowSnapshot`, each containing window frame, display info, tab manager state (selected workspace index, workspace array), and sidebar state (visibility, selection, width).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SPE-003: Workspace state capture
- **Description**: Each `SessionWorkspaceSnapshot` captures process title, custom title, custom color, pinned state, current directory, focused panel ID, recursive split layout tree, panel array, status/log/progress entries, and git branch info.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SPE-004: Panel type polymorphism
- **Description**: `SessionPanelSnapshot` supports terminal (`SessionTerminalPanelSnapshot` with working directory and scrollback), browser (`SessionBrowserPanelSnapshot` with URL, profile, zoom, dev tools, history), and markdown (`SessionMarkdownPanelSnapshot` with file path) panel types.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SPE-005: Recursive split layout persistence
- **Description**: `SessionWorkspaceLayoutSnapshot` is an indirect enum supporting `.pane` (leaf with panel IDs and selected panel) and `.split` (orientation, divider position, first/second children) for arbitrary nesting.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SPE-006: Periodic autosave
- **Description**: Snapshots are automatically saved every 8 seconds (`SessionPersistencePolicy.autosaveInterval`). Saves are skipped when the encoded data is identical to the existing file (byte comparison before write).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SPE-007: Scrollback truncation and ANSI safety
- **Description**: Terminal scrollback is capped at 4000 lines / 400,000 characters. Truncation uses `ansiSafeTruncationStart` to avoid splitting mid-CSI escape sequence. Replay text is wrapped in ANSI reset sequences.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-SPE-008: Scrollback replay via temp files
- **Description**: `SessionScrollbackReplayStore` writes scrollback text to temporary files in `cmux-session-scrollback/` and passes the path via `CMUX_RESTORE_SCROLLBACK_FILE` environment variable to restored terminal processes.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-SPE-009: Restore policy and guard conditions
- **Description**: `SessionRestorePolicy.shouldAttemptRestore` returns false when `CMUX_DISABLE_SESSION_RESTORE=1`, when running under automated tests (XCTest, CMUX_UI_TEST_MODE), or when explicit launch arguments are present (excluding `-psn_` prefixed args).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SPE-010: Bundle-identifier-scoped storage
- **Description**: Snapshot file path is scoped by bundle identifier: `~/Library/Application Support/cmux/session-{bundleId}.json`. Bundle ID is sanitized to `[A-Za-z0-9._-]`. Falls back to `com.cmuxterm.app` if empty.
- **Platform**: macOS-only (path convention)
- **Status**: Implemented
- **Priority**: P0

### REQ-SPE-011: Sidebar state persistence
- **Description**: `SessionSidebarSnapshot` captures visibility, selection (tabs or notifications), and width. Width is sanitized to [180, 600] range with 200 default.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-SPE-012: Display topology awareness
- **Description**: `SessionDisplaySnapshot` captures display ID, frame, and visible frame for each window's screen. Used to restore windows to correct displays after reconnecting monitors.
- **Platform**: macOS-only (display ID is CGDirectDisplay)
- **Status**: Implemented
- **Priority**: P2

### REQ-SPE-013: Resource limits
- **Description**: Policy enforces maximum 12 windows, 128 workspaces per window, 512 panels per workspace to prevent degenerate snapshots.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-SPE-014: Atomic file writes
- **Description**: Snapshot saves use `.atomic` write option to prevent partial writes from corrupting the session file on crash or power loss.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

## Scenarios

### SCENARIO-SPE-001: Save and load round-trip
- **Given**: A snapshot with one window containing workspaces
- **When**: Saved to a file and loaded back
- **Then**: Version, window count, frame coordinates, sidebar selection, and display ID all match
- **Verifies**: REQ-SPE-001, REQ-SPE-002, REQ-SPE-014
- **Status**: Covered

### SCENARIO-SPE-002: Custom color preservation
- **Given**: A workspace with custom color "#C0392B"
- **When**: Saved and loaded
- **Then**: The custom color string is preserved exactly
- **Verifies**: REQ-SPE-003
- **Status**: Covered

### SCENARIO-SPE-003: Identical data skip
- **Given**: A snapshot was already saved
- **When**: The same snapshot is saved again
- **Then**: The file is not rewritten (inode unchanged)
- **Verifies**: REQ-SPE-006
- **Status**: Covered

### SCENARIO-SPE-004: Markdown panel round-trip
- **Given**: A workspace with a markdown panel at a specific file path
- **When**: Session snapshot is taken and restored
- **Then**: Restored panel has the correct file path, custom title, and workspace title
- **Verifies**: REQ-SPE-004
- **Status**: Covered

### SCENARIO-SPE-005: Scrollback ANSI-safe truncation
- **Given**: Scrollback text with a CSI escape spanning the truncation boundary
- **When**: `truncatedScrollback` is called
- **Then**: The truncation point advances past the incomplete CSI sequence
- **Verifies**: REQ-SPE-007
- **Status**: Covered

### SCENARIO-SPE-006: Restore disabled under test environment
- **Given**: `CMUX_UI_TEST_MODE=1` is set
- **When**: `shouldAttemptRestore` is called
- **Then**: Returns false
- **Verifies**: REQ-SPE-009
- **Status**: Covered

### SCENARIO-SPE-007: Version mismatch rejection
- **Given**: A snapshot with version 0
- **When**: Loaded
- **Then**: Returns nil (version != currentVersion)
- **Verifies**: REQ-SPE-001
- **Status**: Covered

## Cross-Platform Notes

- **File paths**: `~/Library/Application Support/` is macOS-specific. Linux should use `~/.local/share/cmux/` or `$XDG_DATA_HOME/cmux/`.
- **Bundle identifier**: Linux apps don't have bundle identifiers. Use an application name constant or config-derived identifier.
- **Display topology**: `CGDirectDisplayID` is macOS-only. Linux equivalent is X11 screen/output or Wayland output names.
- **Temp directory**: `FileManager.default.temporaryDirectory` maps to `/tmp` on both platforms, but Linux may prefer `$XDG_RUNTIME_DIR`.
- All snapshot models (`Codable` structs/enums) are platform-independent and can be shared directly.

## Implementation Status

| Requirement | Status | Notes |
|-------------|--------|-------|
| REQ-SPE-001 | Implemented | currentVersion = 1 |
| REQ-SPE-002 | Implemented | AppSessionSnapshot |
| REQ-SPE-003 | Implemented | SessionWorkspaceSnapshot |
| REQ-SPE-004 | Implemented | terminal/browser/markdown variants |
| REQ-SPE-005 | Implemented | indirect enum Codable |
| REQ-SPE-006 | Implemented | 8s interval + byte-compare skip |
| REQ-SPE-007 | Implemented | ansiSafeTruncationStart |
| REQ-SPE-008 | Implemented | SessionScrollbackReplayStore |
| REQ-SPE-009 | Implemented | SessionRestorePolicy |
| REQ-SPE-010 | Implemented | defaultSnapshotFileURL |
| REQ-SPE-011 | Implemented | SessionSidebarSnapshot |
| REQ-SPE-012 | Implemented | SessionDisplaySnapshot |
| REQ-SPE-013 | Implemented | max 12/128/512 limits |
| REQ-SPE-014 | Implemented | .atomic write option |
