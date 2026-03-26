# Terminal Core Specification

**Status**: EXTRACTED
**Last Updated**: 2026-03-26

## Overview

Terminal core provides the Ghostty-based terminal emulation surface, configuration loading, theming, clipboard handling, and the lifecycle management of terminal surfaces within cmux workspaces.

## Requirements

### REQ-TC-001: Ghostty-based terminal emulation
- **Description**: Terminal surfaces use libghostty (GhosttyKit.xcframework) for terminal emulation, rendering via Metal/IOSurface. Each terminal is represented by a `TerminalSurface` that owns a `ghostty_surface_t` lifecycle.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-TC-002: Configuration loading from Ghostty config files
- **Description**: `GhosttyConfig` loads settings from Ghostty's standard config paths (`~/.config/ghostty/config`, `~/Library/Application Support/com.mitchellh.ghostty/config`) and cmux-specific config paths under Application Support. Config files use key=value format with `#` comments.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-TC-003: Theme resolution with light/dark mode support
- **Description**: Themes support paired light/dark values via `light:ThemeName,dark:ThemeName` syntax. The system resolves theme names based on the current macOS appearance (aqua vs darkAqua). Themes are loaded from multiple search paths including `GHOSTTY_RESOURCES_DIR`, app bundle, `XDG_DATA_DIRS`, and standard Ghostty locations.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-TC-004: Theme name candidate resolution with aliases
- **Description**: Theme names support `builtin` prefix stripping and compatibility aliases (e.g., "Solarized Light" maps to "iTerm2 Solarized Light"). Multiple candidate names are tried in order when searching for theme files.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-TC-005: Color palette configuration
- **Description**: Supports full 16-color ANSI palette via `palette` config entries (format: `palette = N=#RRGGBB`), plus foreground, background, cursor, cursor-text, selection-background, and selection-foreground colors.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-TC-006: Font configuration
- **Description**: Font family and size are configurable via `font-family` and `font-size` config keys. Runtime font size (zoom) is inherited across splits and new surfaces via `cmuxInheritedSurfaceConfig`.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-TC-007: Background opacity and transparency
- **Description**: Background opacity is configurable via `background-opacity`. Windows use transparent backgrounds when opacity < 1.0 or when behind-window blur is enabled. Runtime opacity is resolved from `GhosttyApp.shared.defaultBackgroundOpacity`.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-TC-008: Clipboard handling (paste/copy)
- **Description**: `GhosttyPasteboardHelper` handles clipboard operations for standard and selection pasteboards. Paste resolves URLs (shell-escaped file paths), plain text, HTML (with attributed string fallback), RTF, and RTFD. Image-only HTML clipboard falls back to temporary image file paths. Copy writes plain text to the appropriate pasteboard.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-TC-009: Shell escape for pasted file URLs
- **Description**: File URLs pasted into the terminal are shell-escaped (spaces, special characters, parentheses). Multi-line strings are single-quoted. Multiple file URLs are space-joined.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-TC-010: Terminal surface registry
- **Description**: `TerminalSurfaceRegistry` maintains a weak-referenced set of all live terminal surfaces and maps runtime `ghostty_surface_t` pointers to owner UUIDs. Thread-safe via NSLock.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-TC-011: Surface lifecycle safety (pointer liveness checks)
- **Description**: Before accessing native Ghostty C APIs, surfaces are checked via `cmuxSurfacePointerAppearsLive` (malloc zone validation) to prevent use-after-free crashes. Stale pointers are quarantined.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-TC-012: Terminal surface portal hosting
- **Description**: Each `TerminalSurface` is hosted in a `GhosttySurfaceScrollView` (AppKit NSView) that manages the Metal-rendered surface, notification rings, focus flash animations, and search overlay. The view is bridged to SwiftUI via `GhosttyTerminalView` (NSViewRepresentable).
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-TC-013: Config caching with color-scheme keying
- **Description**: `GhosttyConfig.load()` caches parsed configs by color scheme preference (light/dark). Cache is invalidated on `ghosttyConfigDidReload` notification. Thread-safe via NSLock.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-TC-014: Split divider and unfocused pane appearance
- **Description**: Config supports `unfocused-split-opacity` (clamped 0.15-1.0), `unfocused-split-fill`, and `split-divider-color`. Unfocused pane overlay opacity is derived as `1 - unfocusedSplitOpacity`. Divider color falls back to darkened background.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-TC-015: Sidebar background configuration
- **Description**: `sidebar-background` config key supports paired light/dark hex values. Resolved color is stored to UserDefaults for sidebar tinting. `sidebar-tint-opacity` controls blend amount.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2 (nice-to-have)

### REQ-TC-016: Scrollback limit configuration
- **Description**: `scrollback-limit` config key sets terminal scrollback buffer size (default 10000 lines).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-TC-017: Working directory configuration
- **Description**: `working-directory` config key sets the initial working directory for new terminal surfaces. Falls back to user home directory.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-TC-018: Terminal surface search
- **Description**: Terminal surfaces support incremental text search via `TerminalSurface.SearchState` with needle, selected match index, and total match count. Search overlay is mounted from `GhosttySurfaceScrollView`.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-TC-019: SwiftTerm fallback terminal
- **Description**: A `TerminalView.swift` provides a SwiftTerm-based fallback terminal (`SwiftTermView`) for basic terminal rendering without Ghostty. This applies Ghostty config colors and palette to SwiftTerm's `LocalProcessTerminalView`.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2 (nice-to-have)

### REQ-TC-020: Port ordinal assignment for CMUX_PORT
- **Description**: Each terminal surface receives a port ordinal for `CMUX_PORT` range assignment. Base port and range size are configurable via UserDefaults (`cmuxPortBase`, `cmuxPortRange`).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

## Scenarios

### SCENARIO-TC-001: Light/dark theme resolution for paired themes
- **Given**: A theme config value of `light:Builtin Solarized Light,dark:Builtin Solarized Dark`
- **When**: Theme name is resolved with light color scheme preference
- **Then**: Returns "Builtin Solarized Light"
- **Verifies**: REQ-TC-003
- **Status**: Covered

### SCENARIO-TC-002: Dark theme resolution for paired themes
- **Given**: A theme config value of `light:Builtin Solarized Light,dark:Builtin Solarized Dark`
- **When**: Theme name is resolved with dark color scheme preference
- **Then**: Returns "Builtin Solarized Dark"
- **Verifies**: REQ-TC-003
- **Status**: Covered

### SCENARIO-TC-003: Theme name candidates include builtin aliases
- **Given**: A theme name "Builtin Solarized Light"
- **When**: Theme name candidates are generated
- **Then**: Candidates include "Builtin Solarized Light", "Solarized Light", and "iTerm2 Solarized Light"
- **Verifies**: REQ-TC-004
- **Status**: Covered

### SCENARIO-TC-004: Theme search paths include XDG data dirs
- **Given**: `XDG_DATA_DIRS` is set to `/tmp/cmux-theme-a:/tmp/cmux-theme-b`
- **When**: Theme search paths are generated for "Solarized Light"
- **Then**: Paths include both XDG dirs with `ghostty/themes/Solarized Light` appended
- **Verifies**: REQ-TC-003
- **Status**: Covered

### SCENARIO-TC-005: HTML-only clipboard extracts plain text
- **Given**: Pasteboard contains HTML `<p>Hello <strong>world</strong></p>` with no plain text type
- **When**: String contents are read from pasteboard
- **Then**: Returns "Hello world"
- **Verifies**: REQ-TC-008
- **Status**: Covered

### SCENARIO-TC-006: Image-only HTML clipboard falls back to image path
- **Given**: Pasteboard contains HTML with only an img tag and PNG image data
- **When**: String contents are read from pasteboard
- **Then**: Returns nil (no text); image path is available as PNG file
- **Verifies**: REQ-TC-008
- **Status**: Covered

### SCENARIO-TC-007: File URL paste is shell-escaped
- **Given**: A file URL with spaces and special characters
- **When**: `escapeForShell` is called
- **Then**: Spaces, parentheses, quotes, and other shell metacharacters are backslash-escaped
- **Verifies**: REQ-TC-009
- **Status**: Covered

### SCENARIO-TC-008: Config parsing applies color values
- **Given**: A config file with `background = #1a1b26` and `foreground = #c0caf5`
- **When**: Config is parsed
- **Then**: `backgroundColor` and `foregroundColor` are set to the specified hex values
- **Verifies**: REQ-TC-005
- **Status**: Covered

### SCENARIO-TC-009: Config loading resolves paired theme by color scheme
- **Given**: A theme config with `light:LightTheme,dark:DarkTheme` and theme files on disk
- **When**: Config is loaded with dark color scheme
- **Then**: Dark theme file's colors are applied
- **Verifies**: REQ-TC-003
- **Status**: Covered

### SCENARIO-TC-010: Config cache is invalidated on reload notification
- **Given**: A cached config exists
- **When**: `ghosttyConfigDidReload` notification fires
- **Then**: Cache is cleared and next `load()` reads from disk
- **Verifies**: REQ-TC-013
- **Status**: Partial

### SCENARIO-TC-011: Unfocused split overlay opacity derivation
- **Given**: `unfocused-split-opacity` is set to 0.7
- **When**: Overlay opacity is computed
- **Then**: `unfocusedSplitOverlayOpacity` equals 0.3 (1 - 0.7)
- **Verifies**: REQ-TC-014
- **Status**: Missing

### SCENARIO-TC-012: Surface pointer liveness rejects freed memory
- **Given**: A `ghostty_surface_t` pointer to freed memory
- **When**: `cmuxSurfacePointerAppearsLive` is called
- **Then**: Returns false
- **Verifies**: REQ-TC-011
- **Status**: Missing

## Cross-Platform Notes

- `GhosttyConfig` parsing logic (key=value, theme resolution, color parsing) is platform-agnostic and can be reused on Linux. Config search paths need Linux equivalents (`~/.config/ghostty/config`, XDG paths already supported).
- `GhosttyPasteboardHelper` is macOS-only (NSPasteboard). Linux will need a clipboard abstraction (X11/Wayland clipboard).
- `GhosttyTerminalView` (NSViewRepresentable) and `GhosttySurfaceScrollView` (NSView) are AppKit-specific. Linux will need GTK or custom rendering equivalents.
- `NSColor` hex parsing needs a cross-platform color type (or platform-conditional compilation).
- Metal rendering is macOS-only; Linux Ghostty uses OpenGL/Vulkan.
- `TerminalSurfaceRegistry` and surface lifecycle management are platform-agnostic.

## Implementation Status

All core requirements are implemented on macOS. The SwiftTerm fallback (REQ-TC-019) exists but is secondary to the Ghostty-based rendering. Cross-platform abstractions for clipboard, rendering, and AppKit views are not yet implemented. Config parsing and theme resolution are ready for cross-platform use with minimal changes.
