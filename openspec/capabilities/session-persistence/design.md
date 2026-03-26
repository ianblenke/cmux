# Session Persistence Design

**Last Updated**: 2026-03-26

## Architecture

Session persistence follows a snapshot-restore pattern. The application periodically serializes its entire state into a `Codable` model hierarchy and writes it as JSON to disk. On launch, the snapshot is loaded and the application reconstructs windows, workspaces, and panels from it.

All persistence logic lives in a single file: `Sources/SessionPersistence.swift`.

The design separates concerns into four enums:
1. **SessionSnapshotSchema** — Version constant
2. **SessionPersistencePolicy** — Limits, defaults, truncation logic
3. **SessionRestorePolicy** — Guard conditions for whether to attempt restore
4. **SessionPersistenceStore** — File I/O (save/load/remove)
5. **SessionScrollbackReplayStore** — Scrollback temp file generation

## Key Components

### Snapshot Model Hierarchy

```
AppSessionSnapshot
  ├── version: Int
  ├── createdAt: TimeInterval
  └── windows: [SessionWindowSnapshot]
        ├── frame: SessionRectSnapshot?
        ├── display: SessionDisplaySnapshot?
        ├── sidebar: SessionSidebarSnapshot
        └── tabManager: SessionTabManagerSnapshot
              ├── selectedWorkspaceIndex: Int?
              └── workspaces: [SessionWorkspaceSnapshot]
                    ├── processTitle, customTitle, customColor
                    ├── isPinned, currentDirectory
                    ├── focusedPanelId: UUID?
                    ├── layout: SessionWorkspaceLayoutSnapshot (recursive)
                    │     ├── .pane(SessionPaneLayoutSnapshot)
                    │     └── .split(SessionSplitLayoutSnapshot)
                    ├── panels: [SessionPanelSnapshot]
                    │     ├── terminal: SessionTerminalPanelSnapshot?
                    │     ├── browser: SessionBrowserPanelSnapshot?
                    │     └── markdown: SessionMarkdownPanelSnapshot?
                    ├── statusEntries, logEntries, progress
                    └── gitBranch: SessionGitBranchSnapshot?
```

### SessionPersistencePolicy

Centralized constants and validation:
- Sidebar width: 180-600, default 200
- Window size minimums: 300x200
- Autosave interval: 8 seconds
- Resource limits: 12 windows, 128 workspaces/window, 512 panels/workspace
- Scrollback: 4000 lines / 400K characters max
- ANSI-safe truncation: scans backward for incomplete CSI sequences

### SessionRestorePolicy

Guards against restore in inappropriate contexts:
- `CMUX_DISABLE_SESSION_RESTORE=1` env var
- XCTest environments (6 different detection heuristics)
- `CMUX_UI_TEST_MODE=1` or any `CMUX_UI_TEST_*` env var
- Explicit launch arguments (excluding `-psn_` macOS process serial number)

### SessionPersistenceStore

File I/O with safety:
- **save**: Creates directory, encodes JSON with sorted keys, byte-compares with existing, atomic write
- **load**: Reads file, decodes, validates version and non-empty windows
- **removeSnapshot**: Deletes the file
- **defaultSnapshotFileURL**: Bundle-ID-scoped path under Application Support

### SessionScrollbackReplayStore

Generates temporary files for restored terminal scrollback:
- Normalizes scrollback (whitespace check, truncation, ANSI safety)
- Writes to `$TMPDIR/cmux-session-scrollback/{uuid}.txt`
- Returns environment dict with `CMUX_RESTORE_SCROLLBACK_FILE` key

## Platform Abstraction

The snapshot models are fully platform-independent (`Codable` + `Sendable` structs/enums). Platform-specific concerns:

| Concern | macOS | Linux |
|---------|-------|-------|
| Storage path | `~/Library/Application Support/cmux/` | `$XDG_DATA_HOME/cmux/` or `~/.local/share/cmux/` |
| Bundle ID | `Bundle.main.bundleIdentifier` | Application constant |
| Display ID | `CGDirectDisplayID` (UInt32) | X11 screen / Wayland output |
| Temp directory | `NSTemporaryDirectory()` | `$XDG_RUNTIME_DIR` or `/tmp` |

Abstraction approach: Create a `SessionStoragePaths` protocol with platform implementations for resolving snapshot file URL, temp directory, and display identity.

## Data Flow

### Save Flow
```
Timer (8s) / App lifecycle event
    |
    v
AppDelegate.captureSessionSnapshot()
    |
    +--> For each window: capture frame, display, sidebar
    +--> For each workspace: capture title, layout tree, panels
    |     +--> Terminal panels: capture working dir, scrollback (with truncation)
    |     +--> Browser panels: capture URL, profile, zoom, history
    |     +--> Markdown panels: capture file path
    |
    v
AppSessionSnapshot (Codable)
    |
    v
SessionPersistenceStore.save()
    |
    +--> Encode JSON (sorted keys)
    +--> Compare bytes with existing file
    +--> Skip if identical, else atomic write
```

### Restore Flow
```
App launch
    |
    v
SessionRestorePolicy.shouldAttemptRestore()
    |
    +--> false --> Fresh session (new window)
    +--> true  --> SessionPersistenceStore.load()
                      |
                      +--> nil --> Fresh session
                      +--> snapshot --> Reconstruct
                            |
                            +--> Create windows with frames
                            +--> For each workspace: rebuild layout tree
                            |     +--> Terminal: spawn shell + scrollback replay
                            |     +--> Browser: navigate to saved URL
                            |     +--> Markdown: open file
                            +--> Restore sidebar, selection, focus
```

## Dependencies

- **Foundation** — Codable, FileManager, JSONEncoder/Decoder, URL, Data
- **CoreGraphics** — CGRect for frame snapshots
- **Bonsplit** — SplitOrientation, SidebarSelection, Workspace model
