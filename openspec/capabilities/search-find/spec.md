# Search / Find Specification

**Status**: EXTRACTED
**Last Updated**: 2026-03-26

## Overview

In-surface find functionality for both terminal and browser panels. Terminal find uses Ghostty's native search API. Browser find uses injected JavaScript to highlight matches in the DOM via TreeWalker text node scanning.

## Requirements

### REQ-SF-001: Terminal Find Overlay
- **Description**: A floating search bar overlay appears over terminal surfaces when find is activated. The bar contains a text field, next/previous buttons, a match count indicator, and a close button.
- **Platform**: macOS-only (AppKit NSTextField, SwiftUI overlay)
- **Status**: Implemented
- **Priority**: P0

### REQ-SF-002: Terminal Find Text Field
- **Description**: The find text field is an AppKit `NSTextField` (not a SwiftUI TextField) to avoid SwiftUI/AppKit first-responder focus mismatches. It strips visual chrome (no border, no bezel, no background) so SwiftUI handles the surrounding appearance.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-SF-003: Terminal Find Navigation
- **Description**: Return navigates to the next match. Shift+Return navigates to the previous match. The overlay sends `navigate_search:next` or `navigate_search:previous` actions to the terminal surface.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SF-004: Terminal Find Match Count Display
- **Description**: The overlay displays the current match index and total count in the format "N/M" (1-indexed). When no match is selected but matches exist, displays "-/M". The count reads from `TerminalSurface.SearchState` (published `selected` and `total` properties).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SF-005: Terminal Find Escape Behavior
- **Description**: Pressing Escape in the find field: if the needle is empty, closes the overlay. If the needle is non-empty, moves focus back to the terminal without closing. CJK IME composition in progress is not intercepted (Escape during `hasMarkedText()` is passed through).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SF-006: Terminal Find Focus Management
- **Description**: The find field uses a notification-based focus system (`ghosttySearchFocus` notification). When a `TerminalSurface` posts this notification, the matching search field's coordinator calls `window.makeFirstResponder`. Focus requests are guarded by `canApplyFocusRequest()` and deduplicated to avoid restarting editing sessions.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-SF-007: Terminal Find Overlay Corner Snapping
- **Description**: The search overlay can be dragged to any of the four corners of the terminal surface (topLeft, topRight, bottomLeft, bottomRight). It defaults to topRight. On drag end, it animates to the nearest corner.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P2

### REQ-SF-008: Terminal Find IME Compatibility
- **Description**: During CJK IME composition (`hasMarkedText()`), the overlay does not intercept Escape or Return key commands. Text sync skips programmatic mutations during active composition to avoid disrupting the IME session.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-SF-009: Browser Find Overlay
- **Description**: A floating search bar overlay for browser (WKWebView) panels, visually identical to the terminal find bar. Contains text field, next/previous/close buttons, and match count.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-SF-010: Browser Find JavaScript Engine
- **Description**: Browser find uses JavaScript injected into the WKWebView. `BrowserFindJavaScript.searchScript(query:)` returns JS that:
  1. Removes previous highlights
  2. Walks all visible text nodes using TreeWalker
  3. Performs case-insensitive substring matching
  4. Wraps matches with `<mark class="__cmux-find">` elements
  5. Marks the current match with `.current` class
  6. Scrolls the current match into view
  7. Injects highlight styles (yellow background, orange for current)
  8. Returns JSON `{"total":N,"current":0}`
- **Platform**: all (JavaScript is platform-agnostic)
- **Status**: Implemented
- **Priority**: P0

### REQ-SF-011: Browser Find Navigation Scripts
- **Description**: `nextScript()` advances to the next match (wrapping around). `previousScript()` goes to the previous match (wrapping around). Both update the `.__cmux-find-current` class, scroll into view, and return `{"total":N,"current":M}`. Disconnected DOM nodes are detected and handled gracefully (matches array cleared).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SF-012: Browser Find Clear Script
- **Description**: `clearScript()` removes all `<mark.__cmux-find>` elements, replacing them with their text content and normalizing the parent nodes. The injected style element is also removed.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SF-013: Browser Find JavaScript String Escaping
- **Description**: `jsStringEscape(_:)` escapes Swift strings for safe embedding in JS double-quoted string literals. Handles: backslash, double quote, newline, carriage return, tab, null byte, Unicode line separator (U+2028), paragraph separator (U+2029).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SF-014: Browser Find Visibility Filtering
- **Description**: The JavaScript search skips text nodes inside SCRIPT, STYLE, NOSCRIPT, TEMPLATE, IFRAME, SVG elements, nodes with `aria-hidden="true"`, and nodes with `display:none` or `visibility:hidden` computed styles.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-SF-015: Browser Find Escape Behavior
- **Description**: Pressing Escape in the browser find field closes the overlay. CJK IME composition is not intercepted.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SF-016: Browser Find Focus Management
- **Description**: The browser find field uses a `browserSearchFocus` notification for focus restoration. Focus requests include a generation counter and `canApplyFocusRequest(generation)` guard. After focusing, the cursor is positioned at the end of the text.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-SF-017: Browser Find Overlay Corner Snapping
- **Description**: Same drag-to-corner behavior as the terminal find overlay. Defaults to topRight, snaps to nearest corner on drag end with animation.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P2

### REQ-SF-018: Shared Search Button Style
- **Description**: Both terminal and browser find bars share `SearchButtonStyle`, providing hover and press feedback with rounded rectangle backgrounds and cursor style changes.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2

### REQ-SF-019: Accessibility Identifiers
- **Description**: Terminal find text field has accessibility identifier "TerminalFindSearchTextField". Browser find text field has "BrowserFindSearchTextField". The update pill has "UpdatePill" (separate capability but shares the pattern).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-SF-020: Browser Find Empty Query Handling
- **Description**: When the search query is empty, the search script returns `{"total":0,"current":0}` immediately without modifying the DOM.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-SF-021: Browser Find Match Count Display
- **Description**: The browser overlay displays match counts as "N/M" when a match is selected, "-/M" when matches exist but none is selected, and "0/0" when total is zero.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

## Scenarios

### SCENARIO-SF-001: Terminal Find - Enter Query and Navigate
- **Given**: A terminal surface is focused and the find overlay is open
- **When**: User types "error" and presses Return
- **Then**: The terminal highlights the next occurrence of "error" and the match count updates
- **Verifies**: REQ-SF-001, REQ-SF-003, REQ-SF-004
- **Status**: Missing (requires E2E test with running terminal)

### SCENARIO-SF-002: Terminal Find - Escape with Empty Needle
- **Given**: The find overlay is open with an empty text field
- **When**: User presses Escape
- **Then**: The find overlay closes
- **Verifies**: REQ-SF-005
- **Status**: Missing

### SCENARIO-SF-003: Terminal Find - Escape with Non-Empty Needle
- **Given**: The find overlay is open with "error" in the text field
- **When**: User presses Escape
- **Then**: Focus moves back to the terminal; the overlay remains open
- **Verifies**: REQ-SF-005
- **Status**: Missing

### SCENARIO-SF-004: Terminal Find - Drag to Corner
- **Given**: The find overlay is at the top-right corner
- **When**: User drags it toward the bottom-left
- **Then**: On release, the overlay animates to the bottom-left corner
- **Verifies**: REQ-SF-007
- **Status**: Missing

### SCENARIO-SF-005: Browser Find - Search Script Highlights Matches
- **Given**: A web page with text containing "hello" in 3 locations
- **When**: `searchScript(query: "hello")` is executed
- **Then**: Returns `{"total":3,"current":0}`, 3 `<mark>` elements are created, the first has class `__cmux-find-current`
- **Verifies**: REQ-SF-010
- **Status**: Partial (JS generation tested, DOM execution not tested in unit tests)

### SCENARIO-SF-006: Browser Find - Next Match Navigation
- **Given**: 3 matches exist, current is at index 0
- **When**: `nextScript()` is executed
- **Then**: Current advances to index 1, returns `{"total":3,"current":1}`
- **Verifies**: REQ-SF-011
- **Status**: Missing (JS tested for structure, not execution)

### SCENARIO-SF-007: Browser Find - Previous Match Wraps Around
- **Given**: 3 matches exist, current is at index 0
- **When**: `previousScript()` is executed
- **Then**: Current wraps to index 2, returns `{"total":3,"current":2}`
- **Verifies**: REQ-SF-011
- **Status**: Missing

### SCENARIO-SF-008: Browser Find - Clear Script Restores DOM
- **Given**: Matches are highlighted in the DOM
- **When**: `clearScript()` is executed
- **Then**: All `<mark>` elements are removed, text nodes are restored and normalized, style element is removed
- **Verifies**: REQ-SF-012
- **Status**: Missing (JS tested for structure)

### SCENARIO-SF-009: JavaScript String Escaping - Double Quotes
- **Given**: A string containing double quotes: `say "hello"`
- **When**: `jsStringEscape()` is called
- **Then**: Output is `say \"hello\"`
- **Verifies**: REQ-SF-013
- **Status**: Covered

### SCENARIO-SF-010: JavaScript String Escaping - Backslashes
- **Given**: A string containing backslashes: `path\to\file`
- **When**: `jsStringEscape()` is called
- **Then**: Output is `path\\to\\file`
- **Verifies**: REQ-SF-013
- **Status**: Covered

### SCENARIO-SF-011: JavaScript String Escaping - Control Characters
- **Given**: Strings with newlines, carriage returns, tabs, null bytes
- **When**: `jsStringEscape()` is called
- **Then**: Each is escaped to its JS escape sequence
- **Verifies**: REQ-SF-013
- **Status**: Covered

### SCENARIO-SF-012: JavaScript String Escaping - Unicode Separators
- **Given**: Strings with U+2028 (line separator) and U+2029 (paragraph separator)
- **When**: `jsStringEscape()` is called
- **Then**: Output contains `\u2028` and `\u2029` escape sequences
- **Verifies**: REQ-SF-013
- **Status**: Covered

### SCENARIO-SF-013: JavaScript String Escaping - Plain and CJK Text
- **Given**: Plain ASCII text and Japanese text
- **When**: `jsStringEscape()` is called
- **Then**: Both pass through unchanged
- **Verifies**: REQ-SF-013
- **Status**: Covered

### SCENARIO-SF-014: Search Script Escaping Integration
- **Given**: A query containing double quotes: `test"injection`
- **When**: `searchScript()` is called
- **Then**: The query is properly escaped in the output JS, not creating a string injection
- **Verifies**: REQ-SF-010, REQ-SF-013
- **Status**: Covered

### SCENARIO-SF-015: Empty Query Returns Zero Matches
- **Given**: An empty search query
- **When**: `searchScript(query: "")` is called
- **Then**: The script returns early with `{total: 0, current: 0}`
- **Verifies**: REQ-SF-020
- **Status**: Covered

### SCENARIO-SF-016: Browser Find - Hidden Elements Skipped
- **Given**: A page with text in a `display:none` container and an `aria-hidden="true"` element
- **When**: Search is executed
- **Then**: Text inside hidden elements is not matched
- **Verifies**: REQ-SF-014
- **Status**: Missing (requires WebView integration test)

### SCENARIO-SF-017: Browser Find - Disconnected Node Handling
- **Given**: Matches were found, then the DOM was mutated (e.g., SPA navigation)
- **When**: `nextScript()` is called and a match element is disconnected
- **Then**: The matches array is cleared, returns `{total: 0, current: 0}`
- **Verifies**: REQ-SF-011
- **Status**: Missing

### SCENARIO-SF-018: Terminal Find - CJK IME Compatibility
- **Given**: A CJK input method is composing text in the find field
- **When**: Escape is pressed during composition
- **Then**: The escape is passed through to the IME, not intercepted by the find bar
- **Verifies**: REQ-SF-008
- **Status**: Missing

## Cross-Platform Notes

- Terminal find overlay UI uses SwiftUI + AppKit NSTextField. Linux would need GTK/Qt equivalents.
- `SurfaceSearchOverlay` uses `NSView` ancestor traversal and `GhosttySurfaceScrollView`-specific escape suppression. These are macOS-specific.
- Browser find JavaScript (`BrowserFindJavaScript`) is fully platform-agnostic.
- `BrowserSearchOverlay` uses AppKit NSTextField like the terminal overlay.
- Focus management via `NSWindow.makeFirstResponder` and `NSNotification` is macOS-specific.
- The `SearchButtonStyle` uses `.backport.pointerStyle(.link)` which may need platform adaptation.
- Match count display logic and corner snapping geometry are platform-agnostic.

## Implementation Status

| Component | File | Status |
|-----------|------|--------|
| SurfaceSearchOverlay (terminal find UI) | Sources/Find/SurfaceSearchOverlay.swift | Complete |
| SearchNativeTextField (AppKit text field) | Sources/Find/SurfaceSearchOverlay.swift | Complete |
| SearchTextFieldRepresentable (bridging) | Sources/Find/SurfaceSearchOverlay.swift | Complete |
| SearchButtonStyle (shared) | Sources/Find/SurfaceSearchOverlay.swift | Complete |
| BrowserSearchOverlay (browser find UI) | Sources/Find/BrowserSearchOverlay.swift | Complete |
| BrowserSearchNativeTextField | Sources/Find/BrowserSearchOverlay.swift | Complete |
| BrowserSearchTextFieldRepresentable | Sources/Find/BrowserSearchOverlay.swift | Complete |
| BrowserFindJavaScript (JS generation) | Sources/Find/BrowserFindJavaScript.swift | Complete |
