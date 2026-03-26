# AppleScript Design

**Last Updated**: 2026-03-26

## Architecture

AppleScript support is implemented through Cocoa Scripting, using an SDEF (scripting definition) file and NSScriptCommand subclasses. The scripting layer wraps the same `TabManager` / `Workspace` / `TerminalPanel` model objects used by the UI.

## Key Components

### SDEF (cmux.sdef)
- Defines the cmux Suite with classes: `application`, `window`, `tab`, `terminal`
- Defines commands: `new window`, `new tab`, `activate window`, `close window`, `select tab`, `close tab`, `split`, `focus`, `close`, `input text`, `perform action`
- Defines enumeration: `split direction` (right, left, down, up)
- Includes Standard Suite: `count`, `exists`, `quit`

### ScriptWindow
- Wraps a window by UUID
- Properties: `id`, `title`, `tabs`, `selectedTab`, `terminals`
- Commands: `activate window`, `close window`
- Object specifier: unique ID under `scriptWindows` key on NSApplication

### ScriptTab
- Wraps a workspace by (windowId, tabId)
- Properties: `id`, `title`, `index` (1-based), `selected`, `focusedTerminal`, `terminals`
- Commands: `select tab`, `close tab`
- Object specifier: unique ID under `tabs` key on parent ScriptWindow

### ScriptTerminal
- Wraps a terminal panel by (workspaceId, terminalId)
- Properties: `id`, `title`, `workingDirectory`
- Commands: `split` (with direction), `focus`, `close`
- Object specifier: unique ID under `terminals` key on NSApplication (global lookup)

### ScriptInputTextCommand
- Custom `NSScriptCommand` subclass for `input text` command
- Extracts text from `directParameter` and terminal from `evaluatedArguments`
- Calls `terminal.sendText(text)` on the resolved `TerminalPanel`

### AppleScript Gate
- `NSApp.isAppleScriptEnabled` checked before every scripting operation
- `NSApp.validateScript(command:)` sets error code and returns false if disabled
- Currently hardcoded to `true`; will respect Ghostty config once fork is updated

## Platform Abstraction

AppleScript has no cross-platform equivalent. The automation surface is provided on other platforms by:

| macOS | Cross-Platform |
|-------|---------------|
| AppleScript (SDEF + NSScriptCommand) | Socket API (v1 text + v2 JSON-RPC) |
| osascript CLI | `cmux` CLI relay |
| NSApplication scripting extensions | DBus (Linux), socket commands |

The scriptable object hierarchy mirrors the socket API's resource model:
- `window` -> window commands (list, focus, close)
- `tab` -> workspace commands (list, create, select, close)
- `terminal` -> surface/pane commands (list, create, split, send, close)

## Data Flow

```
osascript / Shortcuts / Automator
  -> macOS Scripting Bridge
    -> SDEF-defined command routing
      -> NSApplication extension methods (handleNewWindowScriptCommand, etc.)
        -> AppDelegate.shared -> TabManager -> Workspace -> TerminalPanel
          -> UI state mutation on @MainActor
```

## Dependencies

- AppKit (NSApplication scripting, NSScriptCommand, NSScriptObjectSpecifier)
- Foundation (NSScriptCommand subclass for input text)
- TabManager, Workspace, TerminalPanel (core model)
- AppDelegate (window registration and lookup)
