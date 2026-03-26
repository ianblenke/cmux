# Keyboard Shortcuts Design

**Last Updated**: 2026-03-26

## Architecture

The keyboard shortcut system is structured in three layers:

1. **Data Layer** -- `KeyboardShortcutSettings` enum and `StoredShortcut` struct define actions, defaults, persistence, and the shortcut data model.
2. **Input Resolution Layer** -- `KeyboardLayout` provides keyboard-layout-aware character resolution using Carbon APIs, enabling shortcuts to work across all input methods.
3. **Routing Layer** -- `AppDelegate` intercepts key events, resolves them against registered actions using layout-aware matching, and dispatches actions to the correct window/tab manager context.

## Key Components

### KeyboardShortcutSettings
- Static enum (namespace) containing the `Action` enum and all shortcut management APIs
- `Action` enum: 30+ cases with `rawValue`, `label` (localized), `defaultsKey`, `defaultShortcut`
- `shortcut(for:)` / `setShortcut(_:for:)` / `resetShortcut(for:)` / `resetAll()` -- CRUD operations
- Change notification: `cmux.keyboardShortcutSettingsDidChange` with optional action in userInfo
- `usesNumberedDigitMatching` -- identifies actions where any digit 1-9 is normalized to "1"
- Backwards-compatible convenience methods for gradual migration

### StoredShortcut
- Codable struct: `key` (String), `command`/`shift`/`option`/`control` (Bool)
- Display: `displayString` concatenates modifier symbols + key display
- Modifier symbols: `^` (control), `a` (option), `^` (shift), `^` (command)
- Special key display: Tab="TAB", Return="↩", arrows use Unicode
- Conversion: `from(event:)` extracts from NSEvent using keyCode-first mapping for symbol keys
- KeyCode mapping covers: arrows, tab, return, brackets, minus, equals, comma, period, slash, semicolon, quote, grave, backslash
- Menu integration: `menuItemKeyEquivalent` produces strings compatible with NSMenuItem
- SwiftUI integration: `keyEquivalent` and `eventModifiers` for SwiftUI keyboard shortcuts

### KeyboardShortcutRecorder
- SwiftUI view wrapping an `NSViewRepresentable` (`ShortcutRecorderNSButton`)
- Click to enter recording mode, displays "Press shortcut..."
- Captures key events via `NSEvent.addLocalMonitorForEvents(matching: .keyDown)`
- Escape cancels recording
- Events without modifiers are rejected
- `transformRecordedShortcut` callback allows per-action validation (e.g., digit normalization)
- Window resign auto-stops recording

### KeyboardLayout
- Static class wrapping Carbon Text Input Source APIs
- `character(forKeyCode:modifierFlags:)`:
  1. Try `TISCopyCurrentKeyboardInputSource` -> `UCKeyTranslate`
  2. If result is non-ASCII, fall back to `TISCopyCurrentASCIICapableKeyboardInputSource`
  3. Modifier translation handles shift and command for command-aware layouts
- `normalizedCharacters(for:)`:
  1. Check `event.charactersIgnoringModifiers` -- if ASCII, return as-is
  2. Otherwise, use `character(forKeyCode:)` for layout resolution
  3. Final fallback: return the raw characters
- `id` property: returns current input source ID string
- DEBUG override: `debugInputSourceIdOverride` for testing

### AppDelegate Shortcut Routing
- `performKeyEquivalent` and local event monitor intercept key events
- Event matching: extract characters via `KeyboardLayout.normalizedCharacters`, compare against registered shortcuts
- Window context: use `event.windowNumber` to find the correct `TabManager`, not the currently focused window
- Full-screen toggle: dedicated `Cmd+Ctrl+F` handler matching by both characters and keyCode
- Split suppression guard: checks hosted view geometry to avoid accidental splits during transitions

## Platform Abstraction

### Portable
- `Action` enum definitions, labels, defaults keys, default shortcuts
- `StoredShortcut` struct (Codable, display logic)
- UserDefaults persistence pattern
- Change notification mechanism (can be mapped to any pub/sub)
- Digit normalization logic

### macOS-Specific
- `KeyboardLayout` -- Carbon TIS/UCKey APIs
- `StoredShortcut.from(event:)` -- NSEvent key handling
- `KeyboardShortcutRecorder` -- NSEvent monitoring, NSButton subclass
- AppDelegate event interception -- `performKeyEquivalent`, `NSEvent.addLocalMonitorForEvents`
- Menu key equivalent sync -- NSMenuItem integration

### Linux Adaptation
- Replace Carbon TIS APIs with `xkbcommon` for keymap resolution
- Replace NSEvent handling with GDK or libinput event processing
- Replace NSButton recorder with GTK widget
- Replace `performKeyEquivalent` with GTK/Wayland key event interception
- Map `StoredShortcut` to GDK accelerator strings for menu display

## Data Flow

```
Key Event arrives
  -> AppDelegate.performKeyEquivalent(with:) or local event monitor
    -> KeyboardLayout.normalizedCharacters(for: event)
      -> event.charactersIgnoringModifiers (if ASCII, done)
      -> TISCopyCurrentKeyboardInputSource -> UCKeyTranslate
      -> (if non-ASCII) TISCopyCurrentASCIICapableKeyboardInputSource -> UCKeyTranslate
    -> Match against registered shortcuts
      -> For each Action, compare key + modifiers
      -> Special case: numbered digit actions match any 1-9
    -> Determine target window from event.windowNumber
      -> tabManagerFor(windowId:) lookup
    -> Dispatch action to target tab manager

Shortcut Recording
  -> User clicks recorder button
    -> Enter recording mode: NSEvent.addLocalMonitorForEvents(.keyDown)
    -> Capture event -> StoredShortcut.from(event:)
      -> keyCode mapping for symbols
      -> charactersIgnoringModifiers for letters/numbers
      -> Require at least one modifier
    -> transformRecordedShortcut (per-action validation)
    -> KeyboardShortcutSettings.setShortcut(_:for:)
      -> JSON encode -> UserDefaults
      -> Post didChangeNotification
        -> Menu items update key equivalents
```

## Dependencies

| Dependency | Purpose | Platform |
|------------|---------|----------|
| AppKit (NSEvent, NSMenuItem) | Event capture, menu sync | macOS |
| Carbon (TIS, UCKeyTranslate) | Keyboard layout resolution | macOS |
| SwiftUI (KeyEquivalent, EventModifiers) | SwiftUI keyboard shortcut integration | macOS |
| Foundation (UserDefaults, NotificationCenter, JSONEncoder/Decoder) | Persistence, notifications | all |
