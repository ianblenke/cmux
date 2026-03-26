# Configuration Specification

**Status**: EXTRACTED
**Last Updated**: 2026-03-26

## Overview

Configuration system providing two layers: Ghostty-compatible terminal config (theme, font, colors, splits) loaded from standard Ghostty config paths, and cmux-specific workspace/command definitions loaded from `cmux.json` files with local-overrides-global precedence and file watching.

## Requirements

### REQ-CF-001: Ghostty Config File Loading
- **Description**: Terminal configuration is loaded from standard Ghostty config paths in order: `~/.config/ghostty/config`, `~/.config/ghostty/config.ghostty`, `~/Library/Application Support/com.mitchellh.ghostty/config`, `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`, then cmux-specific Application Support paths. Later files override earlier ones.
- **Platform**: macOS-only (paths are macOS-specific; Linux would use XDG)
- **Status**: Implemented
- **Priority**: P0

### REQ-CF-002: Ghostty Config Key-Value Parsing
- **Description**: Config files use `key = value` format with `#` comments. Supported keys: `font-family`, `font-size`, `theme`, `working-directory`, `scrollback-limit`, `background`, `background-opacity`, `foreground`, `cursor-color`, `cursor-text`, `selection-background`, `selection-foreground`, `palette` (indexed 0-15), `unfocused-split-opacity`, `unfocused-split-fill`, `split-divider-color`, `sidebar-background`, `sidebar-tint-opacity`.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-CF-003: Theme Resolution with Light/Dark Mode
- **Description**: The `theme` config value supports paired syntax: `light:ThemeName,dark:ThemeName`. The system resolves to the appropriate theme based on the current macOS appearance (`NSApp.effectiveAppearance`). Falls back to the first unqualified theme name if no matching mode entry exists.
- **Platform**: macOS-only (appearance detection)
- **Status**: Implemented
- **Priority**: P0

### REQ-CF-004: Theme File Search Paths
- **Description**: Themes are searched in order: `GHOSTTY_RESOURCES_DIR/themes/`, app bundle resources, `XDG_DATA_DIRS` ghostty theme dirs, `/Applications/Ghostty.app/Contents/Resources/ghostty/themes/`, `~/.config/ghostty/themes/`, `~/Library/Application Support/com.mitchellh.ghostty/themes/`. Compatibility aliases map between "Solarized Light"/"iTerm2 Solarized Light" and "Solarized Dark"/"iTerm2 Solarized Dark".
- **Platform**: all (paths vary by platform)
- **Status**: Implemented
- **Priority**: P1

### REQ-CF-005: Theme Name Candidates with Builtin Stripping
- **Description**: Theme names prefixed with "builtin " or suffixed with "(builtin)" are stripped to produce fallback candidates. Multiple candidate names are tried in order.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-CF-006: Config Cache by Color Scheme
- **Description**: Loaded Ghostty configs are cached per color scheme preference (light/dark) using a thread-safe lock. Cache can be invalidated via `invalidateLoadCache()`.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-CF-007: Sidebar Background from Config
- **Description**: The `sidebar-background` config key supports hex colors and theme-qualified values (light/dark). Resolved colors are stored as `sidebarBackgroundLight`/`sidebarBackgroundDark` and persisted to UserDefaults for sidebar theming.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2

### REQ-CF-008: cmux.json Command Definitions
- **Description**: `cmux.json` files define commands as a JSON object with a `commands` array. Each command has a `name` (required, non-blank), optional `description`, `keywords`, `restart` behavior, and exactly one of `workspace` or `command`.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-CF-009: Workspace Definitions in cmux.json
- **Description**: Workspace commands define `name`, `cwd`, `color` (hex #RRGGBB), and an optional `layout` tree. Layout trees use `pane` nodes (with surfaces array) and `split` nodes (with direction, optional split ratio, exactly 2 children).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-CF-010: Surface Definitions
- **Description**: Surfaces within panes have a `type` (terminal or browser), optional `name`, `command`, `cwd`, `env` dictionary, `url`, and `focus` flag. Panes must contain at least one surface.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-CF-011: Shell Command Definitions
- **Description**: Shell commands (`command` field) are sent as terminal input to the focused terminal panel. Dangerous Unicode characters (zero-width joiners, bidi overrides, BOM) are stripped before display and execution.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-CF-012: Command Confirmation Dialog
- **Description**: Commands with `confirm: true` show a confirmation dialog before execution, displaying the sanitized command text. The dialog includes an "Always trust commands from this folder" checkbox.
- **Platform**: macOS-only (NSAlert)
- **Status**: Implemented
- **Priority**: P1

### REQ-CF-013: Directory Trust System
- **Description**: Trusted directories skip the confirmation dialog for `confirm: true` commands. Trust is stored in `~/Library/Application Support/cmux/trusted-directories.json`. The global config (`~/.config/cmux/cmux.json`) is always trusted. Trust keys resolve to git repo roots when inside a repo, otherwise to the cmux.json parent directory.
- **Platform**: macOS-only (paths)
- **Status**: Implemented
- **Priority**: P1

### REQ-CF-014: Local/Global Config Precedence
- **Description**: Local `cmux.json` (found by walking up from the current workspace directory) takes precedence over the global config (`~/.config/cmux/cmux.json`). Commands with the same name in the local config shadow global ones.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-CF-015: Config File Watching
- **Description**: Both local and global `cmux.json` files are watched for changes using `DispatchSource` file system object sources. Changes trigger automatic reload. Deleted/renamed files trigger reattach attempts (up to 5 retries at 0.5s intervals). Directory-level watchers detect file creation.
- **Platform**: macOS-only (DispatchSource with O_EVTONLY)
- **Status**: Implemented
- **Priority**: P1

### REQ-CF-016: CWD Resolution
- **Description**: Workspace `cwd` values are resolved relative to the base working directory. `nil`, empty, or `.` returns the base. `~` and `~/path` expand to home directory. Absolute paths are returned as-is. Relative paths are joined to the base.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-CF-017: Workspace Restart Behavior
- **Description**: When a workspace command targets an existing workspace (matched by name), the `restart` field controls behavior: `ignore` selects the existing workspace, `recreate` closes and recreates it, `confirm` shows a dialog asking the user.
- **Platform**: all (dialog is macOS NSAlert)
- **Status**: Implemented
- **Priority**: P1

### REQ-CF-018: Config Validation on Decode
- **Description**: JSON decoding validates: blank names rejected, blank commands rejected, must have exactly one of `workspace` or `command`, split nodes require exactly 2 children, panes require at least 1 surface, layout nodes must have either `pane` or `direction` (not both), colors must be valid 6-digit hex.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-CF-019: Split Position Clamping
- **Description**: Split ratios are clamped to [0.1, 0.9] range. Default is 0.5 when not specified.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-CF-020: Debug Bundle Config Path Resolution
- **Description**: Debug/dev bundle identifiers fall back to the release bundle's config paths if the current bundle has no config files. This allows dev builds to share the release build's Ghostty configuration.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2

### REQ-CF-021: Directory Tracking via Tab Selection
- **Description**: The `CmuxConfigStore` observes the selected tab's `currentDirectory` publisher. When the workspace changes directories, the local config path is re-resolved and file watchers are reattached.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-CF-022: Command Source Path Tracking
- **Description**: Each loaded command is tracked with its source file path (`commandSourcePaths`), enabling the confirmation dialog to identify which config file a command came from.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P2

## Scenarios

### SCENARIO-CF-001: Parse Simple Ghostty Config
- **Given**: A Ghostty config file with `font-family = JetBrains Mono` and `font-size = 14`
- **When**: The config is loaded
- **Then**: `fontFamily` is "JetBrains Mono" and `fontSize` is 14
- **Verifies**: REQ-CF-002
- **Status**: Covered

### SCENARIO-CF-002: Resolve Paired Theme for Dark Mode
- **Given**: Theme value is "light:Solarized Light,dark:Solarized Dark"
- **When**: System appearance is dark
- **Then**: Resolved theme name is "Solarized Dark"
- **Verifies**: REQ-CF-003
- **Status**: Covered

### SCENARIO-CF-003: Decode Workspace Command with Layout
- **Given**: A `cmux.json` with a workspace command containing a horizontal split layout
- **When**: The JSON is decoded
- **Then**: The layout tree has a split node with horizontal direction, 2 children, and the specified split ratio
- **Verifies**: REQ-CF-009
- **Status**: Covered

### SCENARIO-CF-004: Decode Nested Split Layout
- **Given**: A `cmux.json` with a workspace having horizontal split, second child is a vertical split with a browser surface
- **When**: The JSON is decoded
- **Then**: The nested structure is correctly represented with proper surface types and URLs
- **Verifies**: REQ-CF-009, REQ-CF-010
- **Status**: Covered

### SCENARIO-CF-005: Reject Invalid Layout Nodes
- **Given**: A `cmux.json` with a layout node containing both `pane` and `direction` keys
- **When**: The JSON is decoded
- **Then**: Decoding throws an error
- **Verifies**: REQ-CF-018
- **Status**: Covered

### SCENARIO-CF-006: Reject Split with Wrong Children Count
- **Given**: A `cmux.json` with a split node having 1 or 3 children
- **When**: The JSON is decoded
- **Then**: Decoding throws an error
- **Verifies**: REQ-CF-018
- **Status**: Covered

### SCENARIO-CF-007: Reject Empty Pane
- **Given**: A `cmux.json` with a pane node having an empty surfaces array
- **When**: The JSON is decoded
- **Then**: Decoding throws an error
- **Verifies**: REQ-CF-018
- **Status**: Covered

### SCENARIO-CF-008: Reject Blank Command Name
- **Given**: A `cmux.json` with a command whose name is empty or whitespace-only
- **When**: The JSON is decoded
- **Then**: Decoding throws an error
- **Verifies**: REQ-CF-018
- **Status**: Covered

### SCENARIO-CF-009: Reject Command with Both Workspace and Command
- **Given**: A `cmux.json` with a command defining both `workspace` and `command`
- **When**: The JSON is decoded
- **Then**: Decoding throws an error
- **Verifies**: REQ-CF-018
- **Status**: Covered

### SCENARIO-CF-010: Resolve CWD - Tilde Expansion
- **Given**: A workspace CWD of "~/Documents/work" with base "/Users/test/project"
- **When**: CWD is resolved
- **Then**: Result is the home directory path + "Documents/work"
- **Verifies**: REQ-CF-016
- **Status**: Covered

### SCENARIO-CF-011: Resolve CWD - Relative Path
- **Given**: A workspace CWD of "backend/src" with base "/Users/test/project"
- **When**: CWD is resolved
- **Then**: Result is "/Users/test/project/backend/src"
- **Verifies**: REQ-CF-016
- **Status**: Covered

### SCENARIO-CF-012: Resolve CWD - Nil or Empty
- **Given**: A workspace CWD of nil, empty, or "."
- **When**: CWD is resolved
- **Then**: Result is the base directory
- **Verifies**: REQ-CF-016
- **Status**: Covered

### SCENARIO-CF-013: Split Position Clamping
- **Given**: Split ratios of 0.01, 0.99, -1.0, 2.0, nil
- **When**: Clamped split position is computed
- **Then**: Results are 0.1, 0.9, 0.1, 0.9, 0.5 respectively
- **Verifies**: REQ-CF-019
- **Status**: Covered

### SCENARIO-CF-014: Command ID Deterministic Generation
- **Given**: A command named "Run tests"
- **When**: The `id` property is accessed
- **Then**: Result is "cmux.config.command.Run%20tests" and is stable across accesses
- **Verifies**: REQ-CF-008
- **Status**: Covered

### SCENARIO-CF-015: Layout Encoding Round-Trip
- **Given**: A pane node or split node
- **When**: Encoded to JSON and decoded back
- **Then**: The structure is preserved
- **Verifies**: REQ-CF-009
- **Status**: Covered

### SCENARIO-CF-016: Theme Search Includes XDG_DATA_DIRS
- **Given**: XDG_DATA_DIRS is set to "/tmp/cmux-theme-a:/tmp/cmux-theme-b"
- **When**: Theme search paths are computed for "Solarized Light"
- **Then**: Both XDG paths include ghostty theme subdirectories
- **Verifies**: REQ-CF-004
- **Status**: Covered

### SCENARIO-CF-017: Builtin Theme Name Stripping
- **Given**: Theme name "Builtin Solarized Light"
- **When**: Candidates are generated
- **Then**: Candidates include "Builtin Solarized Light", "Solarized Light", and "iTerm2 Solarized Light"
- **Verifies**: REQ-CF-005
- **Status**: Covered

### SCENARIO-CF-018: Directory Trust - Global Config Always Trusted
- **Given**: A config path matching the global config path
- **When**: Trust is checked
- **Then**: Returns true without checking the trust store
- **Verifies**: REQ-CF-013
- **Status**: Missing (no isolated test)

### SCENARIO-CF-019: Directory Trust - Git Root Resolution
- **Given**: A cmux.json inside a git repository
- **When**: Trust is granted
- **Then**: The trust key is the git repo root, covering all subdirectories
- **Verifies**: REQ-CF-013
- **Status**: Missing (no isolated test)

### SCENARIO-CF-020: Local Config Overrides Global
- **Given**: Both local and global cmux.json define a command named "build"
- **When**: Commands are loaded
- **Then**: The local version takes precedence; only one "build" command appears
- **Verifies**: REQ-CF-014
- **Status**: Missing (no isolated test; logic is in CmuxConfigStore.loadAll)

### SCENARIO-CF-021: Config File Watch Reloads on Change
- **Given**: A cmux.json file is being watched
- **When**: The file is modified
- **Then**: Commands are reloaded automatically
- **Verifies**: REQ-CF-015
- **Status**: Missing (requires filesystem integration test)

### SCENARIO-CF-022: Dangerous Unicode Stripped from Shell Commands
- **Given**: A shell command containing zero-width joiners and bidi override characters
- **When**: The command is executed
- **Then**: Dangerous characters are removed before sending to the terminal
- **Verifies**: REQ-CF-011
- **Status**: Missing (no isolated test for sanitize function)

## Cross-Platform Notes

- Ghostty config file paths are macOS-specific (`~/Library/Application Support/`). Linux should use `$XDG_CONFIG_HOME/ghostty/config` and `$XDG_DATA_HOME/ghostty/themes/`.
- `cmux.json` paths are portable; the global path `~/.config/cmux/cmux.json` works on both platforms.
- File watching uses `DispatchSource.makeFileSystemObjectSource` with `O_EVTONLY`, which is macOS/BSD-specific. Linux would use `inotify`.
- Confirmation dialogs use `NSAlert`; Linux would need a GTK/Qt dialog or terminal prompt.
- Color parsing (`NSColor(hex:)`) is AppKit-specific; needs a platform-agnostic color type.
- `CmuxDirectoryTrust` stores data in `~/Library/Application Support/cmux/`; Linux would use `$XDG_DATA_HOME/cmux/`.

## Implementation Status

| Component | File | Status |
|-----------|------|--------|
| GhosttyConfig (parsing, theme, cache) | Sources/GhosttyConfig.swift | Complete |
| CmuxConfigFile / CmuxCommandDefinition | Sources/CmuxConfig.swift | Complete |
| CmuxConfigStore (loading, watching) | Sources/CmuxConfig.swift | Complete |
| CmuxConfigExecutor | Sources/CmuxConfigExecutor.swift | Complete |
| CmuxDirectoryTrust | Sources/CmuxDirectoryTrust.swift | Complete |
| Layout types (CmuxLayoutNode, etc.) | Sources/CmuxConfig.swift | Complete |
