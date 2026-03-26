# AppleScript Specification

**Status**: EXTRACTED
**Last Updated**: 2026-03-26

## Overview

Provides AppleScript (OSA) automation support for cmux, exposing windows, tabs (workspaces), and terminals as scriptable objects with commands for creation, navigation, text input, and Ghostty action execution.

## Requirements

### REQ-AS-001: Scriptable Object Model
- **Description**: Expose a three-level scripting hierarchy: `application` -> `window` (ScriptWindow) -> `tab` (ScriptTab) -> `terminal` (ScriptTerminal). Each object has a stable UUID-based `id` property, a `name`/`title` property, and is accessible by unique ID.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-AS-002: Window Commands
- **Description**: Support `new window`, `activate window` (bring to front), and `close window` AppleScript commands. `front window` property returns the frontmost window.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-AS-003: Tab (Workspace) Commands
- **Description**: Support `new tab` (optionally in a specific window), `select tab`, and `close tab` commands. Tabs expose `index` (1-based), `selected` boolean, and `focused terminal` properties.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-AS-004: Terminal Commands
- **Description**: Support `split` (with direction: right/left/down/up), `focus` (brings window to front and selects workspace), `close`, and `input text` commands on terminal objects. Terminals expose `title` and `working directory` properties.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-AS-005: Perform Action Command
- **Description**: `perform action <string> on <terminal>` executes an arbitrary Ghostty binding action string on the specified terminal, returning a boolean success indicator.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-AS-006: Input Text Command
- **Description**: `input text <string> to <terminal>` sends text to a terminal as if it were pasted. Implemented as a custom `NSScriptCommand` subclass (`CmuxScriptInputTextCommand`).
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-AS-007: AppleScript Enable/Disable Gate
- **Description**: All scripting operations check `NSApp.isAppleScriptEnabled` before proceeding. Currently hardcoded to `true` pending upstream Ghostty fork alignment. When disabled, commands return `errAEEventNotPermitted`.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-AS-008: Scripting Dictionary (SDEF)
- **Description**: `Resources/cmux.sdef` defines the AppleScript dictionary with the cmux Suite containing all scriptable classes, properties, commands, and enumerations. Includes Standard Suite (count, exists, quit).
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-AS-009: Terminal Enumeration Order
- **Description**: Terminals are enumerated via `scriptingTerminalPanels()` which returns panels in sidebar order first, then any remaining panels sorted by UUID. This ensures consistent ordering for AppleScript iteration.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2

### REQ-AS-010: Working Directory from Panel Directories
- **Description**: `ScriptTerminal.workingDirectory` reads from `Workspace.panelDirectories` (updated via OSC 7 / shell integration) rather than `TerminalPanel.directory` which is not kept up to date.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-AS-011: Localized Error Messages
- **Description**: All AppleScript error messages use `String(localized:defaultValue:)` for localization support.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2

## Scenarios

### SCENARIO-AS-001: List Windows via AppleScript
- **Given**: cmux is running with two windows open
- **When**: `tell application "cmux" to get every window` is executed
- **Then**: Returns two window objects with unique IDs
- **Verifies**: REQ-AS-001, REQ-AS-002
- **Status**: Missing (E2E)

### SCENARIO-AS-002: Create New Window
- **Given**: cmux is running
- **When**: `tell application "cmux" to new window` is executed
- **Then**: A new window is created and returned as a ScriptWindow
- **Verifies**: REQ-AS-002
- **Status**: Missing (E2E)

### SCENARIO-AS-003: Create New Tab in Window
- **Given**: A cmux window exists
- **When**: `tell application "cmux" to new tab in <window>` is executed
- **Then**: A new workspace is created in the specified window
- **Verifies**: REQ-AS-003
- **Status**: Missing (E2E)

### SCENARIO-AS-004: Split Terminal
- **Given**: A terminal exists in a workspace
- **When**: `split <terminal> direction right` is executed
- **Then**: A new terminal is created to the right of the original
- **Verifies**: REQ-AS-004
- **Status**: Missing (E2E)

### SCENARIO-AS-005: Input Text to Terminal
- **Given**: A terminal is available
- **When**: `input text "ls -la" to <terminal>` is executed
- **Then**: The text is sent to the terminal as if pasted
- **Verifies**: REQ-AS-006
- **Status**: Missing (E2E)

### SCENARIO-AS-006: Perform Action on Terminal
- **Given**: A terminal is available
- **When**: `perform action "copy_to_clipboard" on <terminal>` is executed
- **Then**: The Ghostty action is performed and true is returned
- **Verifies**: REQ-AS-005
- **Status**: Missing (E2E)

### SCENARIO-AS-007: Close Terminal Cascades to Window
- **Given**: A window with a single workspace containing a single terminal
- **When**: `close <terminal>` is executed
- **Then**: The window is closed (since it was the last terminal in the last workspace)
- **Verifies**: REQ-AS-004
- **Status**: Missing (E2E)

### SCENARIO-AS-008: Disabled AppleScript Rejects Commands
- **Given**: AppleScript is disabled
- **When**: Any scripting command is executed
- **Then**: Returns `errAEEventNotPermitted` error
- **Verifies**: REQ-AS-007
- **Status**: Missing (E2E)

## Cross-Platform Notes

- AppleScript is inherently macOS-only. There is no equivalent on Linux.
- The socket-based CLI and JSON-RPC API (see remote-daemon capability) serve as the cross-platform automation interface.
- On Linux, automation would be via the socket API, DBus, or similar IPC mechanisms.
- The scriptable object model (window -> workspace -> terminal hierarchy) is a useful abstraction that informs the cross-platform API design.

## Implementation Status

| Requirement | Status | Test Coverage |
|-------------|--------|--------------|
| REQ-AS-001 | Implemented | No automated tests |
| REQ-AS-002 | Implemented | No automated tests |
| REQ-AS-003 | Implemented | No automated tests |
| REQ-AS-004 | Implemented | No automated tests |
| REQ-AS-005 | Implemented | No automated tests |
| REQ-AS-006 | Implemented | No automated tests |
| REQ-AS-007 | Implemented | No automated tests |
| REQ-AS-008 | Implemented | No automated tests |
| REQ-AS-009 | Implemented | No automated tests |
| REQ-AS-010 | Implemented | No automated tests |
| REQ-AS-011 | Implemented | No automated tests |
