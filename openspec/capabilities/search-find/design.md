# Search / Find Design

**Last Updated**: 2026-03-26

## Architecture

The search/find system has two parallel implementations sharing visual design and interaction patterns:

1. **Terminal Find** -- Overlay on terminal surfaces, delegates search/navigation to Ghostty's native search API via action strings.
2. **Browser Find** -- Overlay on browser panels, executes JavaScript in WKWebView to highlight and navigate DOM text matches.

Both share the same floating bar design, corner-snapping behavior, and search button style.

## Key Components

### SurfaceSearchOverlay (Terminal Find)
- SwiftUI view taking `tabId`, `surfaceId`, `searchState`, and callback closures
- `searchState: TerminalSurface.SearchState` -- published `needle`, `selected`, `total`
- Text field: `SearchTextFieldRepresentable` wrapping `SearchNativeTextField` (AppKit)
- Navigation: `onNavigateSearch("navigate_search:next")` / `onNavigateSearch("navigate_search:previous")`
- Escape handling in `doCommandBy`: empty needle -> `onClose()`, non-empty -> `onMoveFocusToTerminal()`
- IME guard: `hasMarkedText()` check before intercepting Escape/Return
- Focus: notification-based via `.ghosttySearchFocus`, deduplication checks, async `makeFirstResponder`
- Corner snapping: `Corner` enum (4 positions), drag gesture with closest-corner calculation, animated snap
- Mounted from `GhosttySurfaceScrollView` in the AppKit portal layer (NOT from SwiftUI panel containers per layering contract)

### SearchNativeTextField
- `NSTextField` subclass with stripped chrome (no border, no bezel, no background, no focus ring)
- Single-line mode
- Delegates focus/editing events to coordinator

### SearchTextFieldRepresentable
- `NSViewRepresentable` bridging `SearchNativeTextField` to SwiftUI
- Coordinator implements `NSTextFieldDelegate`
- `controlTextDidChange` -- sync text to binding
- `controlTextDidBeginEditing` / `controlTextDidEndEditing` -- sync focus state
- `control(_:textView:doCommandBy:)` -- intercept Escape (`cancelOperation`) and Return (`insertNewline`)
- Escape suppression: calls `GhosttySurfaceScrollView.beginFindEscapeSuppression()` to prevent Ghostty from consuming the Escape
- Notification observer for `.ghosttySearchFocus` -- programmatic focus from AppKit level
- Programmatic text sync guarded by `isProgrammaticMutation` flag to avoid feedback loops
- IME text sync: skips updates during `hasMarkedText()` to avoid disrupting composition

### BrowserSearchOverlay (Browser Find)
- Visually identical to terminal find overlay
- `searchState: BrowserSearchState` -- published `needle`, `selected`, `total`
- Callbacks: `onNext()`, `onPrevious()`, `onClose()`
- Focus uses `browserSearchFocus` notification with panel UUID matching
- Focus generation counter for stale request detection
- After focus, cursor positioned at end of text

### BrowserFindJavaScript
- Static enum providing JS generation functions
- `searchScript(query:)` -- full search with highlight injection:
  - Clears previous highlights
  - TreeWalker on `document.body` for SHOW_TEXT nodes
  - Visibility filter: skips SCRIPT/STYLE/NOSCRIPT/TEMPLATE/IFRAME/SVG, `aria-hidden`, `display:none`, `visibility:hidden`
  - Case-insensitive substring matching
  - Creates `<mark class="__cmux-find">` wrappers via DocumentFragment
  - First match gets `.__cmux-find-current` class + `scrollIntoView`
  - Injects `<style id="__cmux-find-style">` for highlight colors (yellow default, orange current)
  - Stores matches array and index on `window.__cmuxFindMatches` / `window.__cmuxFindIndex`
- `nextScript()` / `previousScript()` -- advance/retreat with wraparound
  - Check `isConnected` for DOM mutation safety
  - Toggle `.current` class, scroll into view
- `clearScript()` -- remove all marks, restore text nodes, normalize parents, remove style
- `jsStringEscape(_:)` -- escapes for JS string literal embedding (handles `\`, `"`, `\n`, `\r`, `\t`, `\0`, U+2028, U+2029)

### SearchButtonStyle
- Shared `ButtonStyle` for next/previous/close buttons
- Hover tracking with `onHover`
- Three visual states: default (secondary), hovered (primary opacity 0.1), pressed (primary opacity 0.2)
- Rounded rectangle background with 6pt corner radius
- `.backport.pointerStyle(.link)` for cursor change

## Platform Abstraction

### Portable
- `BrowserFindJavaScript` -- all JS generation is pure Swift string manipulation
- `jsStringEscape()` -- portable escaping logic
- Corner snapping geometry calculations
- Match count display logic
- Search state models (needle, selected, total)

### macOS-Specific
- `SearchNativeTextField` / `BrowserSearchNativeTextField` -- NSTextField subclasses
- `NSViewRepresentable` bridging
- Focus management via `NSWindow.makeFirstResponder` and `NSNotification`
- `GhosttySurfaceScrollView.beginFindEscapeSuppression()` -- Ghostty escape handling
- `NSEvent.currentEvent?.modifierFlags` for shift detection on Return
- SwiftUI `.safeHelp()` for tooltips

### Linux Adaptation
- Replace NSTextField with GTK Entry or equivalent
- Replace NSViewRepresentable with native widget embedding
- Replace notification-based focus with direct widget focus calls
- Replace `makeFirstResponder` with GTK `grab_focus`
- JavaScript injection works identically via WebKitGTK's `run_javascript`
- Terminal search uses the same libghostty find API (cross-platform)

## Data Flow

### Terminal Find
```
User presses Cmd+F
  -> TerminalSurface activates search mode
  -> SurfaceSearchOverlay appears in terminal view
  -> isSearchFieldFocused = true -> NSTextField becomes first responder

User types query
  -> NSTextFieldDelegate.controlTextDidChange
    -> searchState.needle updated
    -> Ghostty performs incremental search
    -> searchState.selected / searchState.total update
    -> Match count display updates ("N/M")

User presses Return
  -> doCommandBy(insertNewline:)
    -> isShift check via NSApp.currentEvent
    -> onNavigateSearch("navigate_search:next" or "navigate_search:previous")
    -> Ghostty navigates to match

User presses Escape (non-empty needle)
  -> doCommandBy(cancelOperation:)
    -> GhosttySurfaceScrollView.beginFindEscapeSuppression()
    -> onMoveFocusToTerminal() -- terminal regains focus, bar stays

User presses Escape (empty needle)
  -> doCommandBy(cancelOperation:)
    -> onClose() -- overlay removed
```

### Browser Find
```
User presses Cmd+F in browser panel
  -> BrowserSearchOverlay appears
  -> isSearchFieldFocused = true -> NSTextField becomes first responder

User types query
  -> NSTextFieldDelegate.controlTextDidChange
    -> searchState.needle updated
    -> BrowserFindJavaScript.searchScript(query:) generated
    -> WKWebView.evaluateJavaScript(script)
    -> Parse JSON result {"total":N,"current":0}
    -> Update searchState.total, searchState.selected

User presses Return
  -> doCommandBy(insertNewline:)
    -> isShift? onPrevious() : onNext()
    -> BrowserFindJavaScript.nextScript() or previousScript()
    -> WKWebView.evaluateJavaScript(script)
    -> Parse JSON result -> update state

User presses Escape
  -> doCommandBy(cancelOperation:)
    -> onClose()
    -> BrowserFindJavaScript.clearScript() executed
    -> WKWebView.evaluateJavaScript(clearScript)
    -> Overlay removed, DOM restored
```

## Dependencies

| Dependency | Purpose | Platform |
|------------|---------|----------|
| SwiftUI | Overlay views, geometry, animations | macOS (Linux via alternative) |
| AppKit (NSTextField, NSWindow, NSEvent) | Native text field, focus management | macOS |
| Bonsplit (GhosttySurfaceScrollView) | Escape suppression, portal hosting | macOS |
| WebKit (WKWebView) | JavaScript execution for browser find | macOS |
| Foundation (NotificationCenter, UUID) | Focus notifications, panel identification | all |
| libghostty | Terminal search API (navigate_search actions) | all |
