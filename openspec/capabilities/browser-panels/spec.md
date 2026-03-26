# Browser Panels Specification

**Status**: EXTRACTED
**Last Updated**: 2026-03-26

## Overview

Browser panels provide an embedded WKWebView-based browser within cmux workspaces, enabling web content alongside terminal sessions with full navigation, search, profiles, popup windows, developer tools, bookmark import, and remote loopback proxy support for SSH-tunneled localhost access.

## Requirements

### REQ-BP-001: Web content rendering via WKWebView
- **Description**: Each browser panel hosts a `CmuxWebView` (WKWebView subclass) that renders web pages with back/forward navigation gestures, configurable page zoom, and theme-aware background colors.
- **Platform**: macOS-only (WKWebView is AppKit-bound; Linux requires alternative)
- **Status**: Implemented
- **Priority**: P0

### REQ-BP-002: Smart navigation (omnibar)
- **Description**: The `navigateSmart` function interprets user input as either a URL (when it looks like one) or a search query (delegated to the configured search engine). Supports Google, DuckDuckGo, Bing, Kagi, and Startpage with optional search suggestions.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-BP-003: Back/forward navigation
- **Description**: `goBack()` and `goForward()` navigate the WKWebView history. Session persistence captures back/forward history URL strings for restore.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-BP-004: Popup window support
- **Description**: `window.open()` calls create `BrowserPopupWindowController` instances hosted in standalone `NSPanel` windows. Popups share the opener's cookie/storage scope via shared `WKProcessPool` and `WKWebsiteDataStore`. Nested popups are capped at depth 3 (`maxNestingDepth`).
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-BP-005: Insecure HTTP protection
- **Description**: Plain HTTP navigations trigger a 3-button alert (Open in Default Browser / Proceed in cmux / Cancel) with an "Always allow this host" suppression checkbox. Per-host allowlist persisted via `BrowserInsecureHTTPSettings`. Applies to both main panels and popup windows.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-BP-006: External URL scheme handling
- **Description**: Non-web URL schemes (mailto:, tel:, etc.) are detected by `browserShouldOpenURLExternally` and handed off to the system default handler via `NSWorkspace.shared.open`.
- **Platform**: macOS-only (Linux: xdg-open equivalent)
- **Status**: Implemented
- **Priority**: P1

### REQ-BP-007: Browser profiles
- **Description**: `BrowserProfileStore` manages named browser profiles with isolated data stores. Profiles are Codable definitions with UUID, display name, creation date, and built-in default flag. Profiles have slugs for CLI targeting. Last-used profile ID is tracked.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-BP-008: Custom user agent
- **Description**: Browser panels use a Safari-compatible user agent string (`BrowserUserAgentSettings.safariUserAgent`) to improve site compatibility versus the default WKWebView UA.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-BP-009: JavaScript dialog support
- **Description**: `alert()`, `confirm()`, and `prompt()` JavaScript dialogs are rendered as native NSAlert sheets (both in main panels and popups). File upload panels (`<input type="file">`) use NSOpenPanel.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-BP-010: File download support
- **Description**: Content-Disposition attachment headers and non-renderable MIME types trigger WKDownload with a `BrowserDownloadDelegate`. Downloads work in both main panels and popup windows.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-BP-011: Theme integration
- **Description**: Browser chrome background color matches the Ghostty terminal theme via `GhosttyBackgroundTheme`. Supports system/light/dark theme override (`BrowserThemeSettings`). Omnibar pill background slightly darkens the theme color for contrast.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P2

### REQ-BP-012: Developer tools
- **Description**: WKWebView inspector is enabled (`isInspectable = true` on macOS 13.3+). Developer tools visibility is persisted in session snapshots. Configurable toolbar icon and color for the dev tools button.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2

### REQ-BP-013: Context menu enhancements
- **Description**: "Open Link in New Tab" context menu opens the URL as a new browser surface in the opener's workspace (not as a popup). Image copy uses multi-type pasteboard (PNG + TIFF + source URL). Middle-click intent tracking handles WebKit button number inconsistencies.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2

### REQ-BP-014: Remote loopback proxy
- **Description**: Browser panels support proxying localhost URLs through SSH tunnels for remote workspace access. Uses `cmux-loopback.localtest.me` as alias host. Supports configurable proxy endpoints.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-BP-015: Browser import hints
- **Description**: Configurable import hint UI (inline strip, floating card, toolbar chip, or settings-only) prompts users to import bookmarks/data from other browsers. Dismissible with user preference persistence.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P2

### REQ-BP-016: Telemetry hooks (console/error capture)
- **Description**: JavaScript user scripts capture `console.log/info/warn/error/debug` output and window error/unhandledrejection events into `__cmuxConsoleLog` and `__cmuxErrorLog` arrays (512-entry ring buffers) for agent/automation inspection.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-BP-017: Key equivalent routing
- **Description**: `CmuxWebView` overrides `performKeyEquivalent` to route Command-key shortcuts (Cmd+N, Cmd+W, tab switching, split commands) through the app menu before WebKit consumes them. Return/Enter always bypasses to WebKit for form submission.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-BP-018: Focus management
- **Description**: `CmuxWebView` blocks background pane autofocus via `allowsFirstResponderAcquisition` flag. Pointer-driven focus is temporarily permitted via `withPointerFocusAllowance` for explicit mouse clicks. First-click focus configurable via `PaneFirstClickFocusSettings`.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-BP-019: Media capture permissions
- **Description**: Media capture permission requests (camera/microphone) are forwarded to the system prompt (`WKPermissionDecision.prompt`) rather than auto-denied.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2

## Scenarios

### SCENARIO-BP-001: Navigate to URL
- **Given**: A browser panel is active
- **When**: User enters "https://example.com" in the omnibar
- **Then**: The WKWebView navigates to the URL
- **Verifies**: REQ-BP-001, REQ-BP-002
- **Status**: Covered

### SCENARIO-BP-002: Search query navigation
- **Given**: A browser panel is active with Google as the default search engine
- **When**: User enters "hello world" in the omnibar
- **Then**: The WKWebView navigates to Google search for "hello world"
- **Verifies**: REQ-BP-002
- **Status**: Covered

### SCENARIO-BP-003: Popup window creation
- **Given**: A browser panel is loaded with a page that calls `window.open()`
- **When**: The scripted popup request fires
- **Then**: A `BrowserPopupWindowController` opens with shared cookie scope and the popup is capped at nesting depth 3
- **Verifies**: REQ-BP-004
- **Status**: Covered

### SCENARIO-BP-004: Insecure HTTP navigation
- **Given**: A browser panel navigates to an HTTP URL not in the allowlist
- **When**: The navigation policy fires
- **Then**: A 3-button alert appears offering to open externally, proceed, or cancel
- **Verifies**: REQ-BP-005
- **Status**: Covered

### SCENARIO-BP-005: Cmd+W closes popup not parent tab
- **Given**: A popup window is focused
- **When**: User presses Cmd+W
- **Then**: Only the popup panel closes; the parent browser tab remains open
- **Verifies**: REQ-BP-017
- **Status**: Covered

### SCENARIO-BP-006: Chrome background matches terminal theme
- **Given**: The Ghostty theme has a custom background color
- **When**: A browser panel renders
- **Then**: The chrome background color matches the theme; omnibar pill is slightly darkened
- **Verifies**: REQ-BP-011
- **Status**: Covered

### SCENARIO-BP-007: Background pane cannot steal focus
- **Given**: A browser panel is in a non-focused split pane
- **When**: A web page triggers autofocus
- **Then**: `becomeFirstResponder` returns false due to `allowsFirstResponderAcquisition` being off
- **Verifies**: REQ-BP-018
- **Status**: Covered

### SCENARIO-BP-008: Session restore preserves browser state
- **Given**: A browser panel has a URL, zoom level, and history
- **When**: The session is saved and restored
- **Then**: `SessionBrowserPanelSnapshot` preserves URL, profile ID, zoom, dev tools state, and back/forward history
- **Verifies**: REQ-BP-003, REQ-BP-007, REQ-BP-012
- **Status**: Covered

## Cross-Platform Notes

- **WKWebView** is macOS/iOS only. Linux port requires an alternative (WebKitGTK, Chromium Embedded Framework, or Servo).
- **NSPanel/NSAlert** popup and dialog UI must be replaced with GTK or platform-agnostic equivalents.
- **NSWorkspace.shared.open** for external URLs maps to `xdg-open` on Linux.
- **NSPasteboard** image copy logic requires Linux clipboard API (wl-copy/xclip).
- **Key equivalent routing** through `performKeyEquivalent` is AppKit-specific; Linux needs equivalent keyboard shortcut interception at the window manager level.
- Core logic (URL parsing, search engine selection, profile management, insecure HTTP policy, telemetry hooks) is platform-independent and should be extracted into a shared module.

## Implementation Status

| Requirement | Status | Notes |
|-------------|--------|-------|
| REQ-BP-001 | Implemented | CmuxWebView in BrowserPanel.swift |
| REQ-BP-002 | Implemented | navigateSmart + BrowserSearchEngine |
| REQ-BP-003 | Implemented | goBack/goForward + session snapshot |
| REQ-BP-004 | Implemented | BrowserPopupWindowController |
| REQ-BP-005 | Implemented | BrowserInsecureHTTPSettings |
| REQ-BP-006 | Implemented | browserShouldOpenURLExternally |
| REQ-BP-007 | Implemented | BrowserProfileStore |
| REQ-BP-008 | Implemented | BrowserUserAgentSettings |
| REQ-BP-009 | Implemented | PopupUIDelegate JS dialogs |
| REQ-BP-010 | Implemented | BrowserDownloadDelegate |
| REQ-BP-011 | Implemented | GhosttyBackgroundTheme |
| REQ-BP-012 | Implemented | isInspectable + session persist |
| REQ-BP-013 | Implemented | CmuxWebView context menu |
| REQ-BP-014 | Implemented | Remote loopback proxy |
| REQ-BP-015 | Implemented | BrowserImportHintSettings |
| REQ-BP-016 | Implemented | telemetryHookBootstrapScriptSource |
| REQ-BP-017 | Implemented | CmuxWebView.performKeyEquivalent |
| REQ-BP-018 | Implemented | allowsFirstResponderAcquisition |
| REQ-BP-019 | Implemented | WKPermissionDecision.prompt |
