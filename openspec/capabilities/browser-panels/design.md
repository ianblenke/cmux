# Browser Panels Design

**Last Updated**: 2026-03-26

## Architecture

Browser panels are integrated into the cmux workspace model as a `Panel` type alongside terminal panels and markdown panels. Each browser panel owns a `CmuxWebView` (WKWebView subclass) and manages navigation, security policies, popup lifecycle, and session persistence.

The browser subsystem is organized across four primary source files:
- `BrowserPanel.swift` — Core panel class, navigation, profiles, search, security, proxy, telemetry hooks
- `BrowserPanelView.swift` — SwiftUI/AppKit view layer, toolbar, dev tools UI, theme integration
- `CmuxWebView.swift` — WKWebView subclass for key routing, focus management, context menus, image copy
- `BrowserPopupWindowController.swift` — Standalone NSPanel for `window.open()` popups

## Key Components

### BrowserPanel
- Conforms to `Panel` protocol and `ObservableObject`
- Owns the `CmuxWebView` instance and manages its lifecycle
- Handles smart navigation (URL vs search query detection)
- Manages remote loopback proxy for SSH-tunneled localhost access
- Injects telemetry user scripts for console/error capture
- Tracks popup controllers for deterministic cleanup on tab close

### CmuxWebView
- Overrides `performKeyEquivalent` to route Command shortcuts to app menu before WebKit
- Manages `allowsFirstResponderAcquisition` to prevent background pane autofocus
- Provides `withPointerFocusAllowance` for explicit mouse click focus
- Tracks middle-click intent with debounce for navigation delegate accuracy
- Custom context menu with image copy (PNG/TIFF/URL pasteboard types)

### BrowserPopupWindowController
- Self-retaining via `objc_setAssociatedObject` on its NSPanel
- Shares opener's `WKProcessPool` and `WKWebsiteDataStore` for cookie/session continuity
- Supports nested popups up to depth 3
- URL label for phishing protection
- Full parity with main browser for JS dialogs, insecure HTTP prompts, and downloads

### BrowserProfileStore
- Singleton managing `BrowserProfileDefinition` instances
- Each profile has UUID, display name, slug, creation date
- Built-in default profile with hardcoded UUID
- Profiles are Codable, persisted via UserDefaults
- Profile ID carried through session snapshots for restore

### Settings & Policy Enums
- `BrowserSearchEngine` — Search provider with URL template
- `BrowserSearchSettings` — Default engine and suggestions toggle
- `BrowserThemeSettings` — System/light/dark mode with legacy migration
- `BrowserInsecureHTTPSettings` — Per-host HTTP allowlist
- `BrowserImportHintSettings` — Import prompt variant and dismissal state
- `BrowserUserAgentSettings` — Safari-compatible UA string

## Platform Abstraction

Current implementation is tightly coupled to AppKit/WebKit:
- `WKWebView` for rendering
- `NSPanel` for popups
- `NSAlert` for dialogs
- `NSPasteboard` for clipboard
- `NSWorkspace` for external URL opening

For Linux cross-platform support, the following abstraction layers are needed:

1. **WebEngine protocol** — Abstract interface over WKWebView/WebKitGTK with methods: `navigate(to:)`, `goBack()`, `goForward()`, `reload()`, `evaluateJavaScript(_:)`, `pageZoom`
2. **PopupHost protocol** — Abstract popup window creation and lifecycle
3. **DialogPresenter protocol** — Alert/confirm/prompt/file-open dialogs
4. **ClipboardWriter protocol** — Multi-type pasteboard writing
5. **SystemOpener protocol** — External URL/file opening

Platform-independent logic to extract:
- URL parsing and smart navigation decision
- Search engine URL construction
- Insecure HTTP policy evaluation
- Profile definition model and persistence
- Telemetry hook JavaScript source
- Session snapshot models

## Data Flow

```
User Input (omnibar/click)
    |
    v
BrowserPanel.navigateSmart() / navigate(to:)
    |
    +--> URL validation & insecure HTTP check
    |       |
    |       +--> Allow --> WKWebView.load(URLRequest)
    |       +--> Block  --> NSAlert (3-button)
    |
    +--> Search query --> BrowserSearchEngine.searchURL() --> WKWebView.load()

WKWebView navigation delegate
    |
    +--> External scheme --> NSWorkspace.open()
    +--> window.open()  --> BrowserPopupWindowController
    +--> Download       --> BrowserDownloadDelegate
    +--> Normal page    --> Render

Session save (periodic 8s autosave)
    |
    v
BrowserPanel --> SessionBrowserPanelSnapshot
    (URL, profile, zoom, devtools, history)
```

## Dependencies

- **WebKit** — WKWebView, WKWebViewConfiguration, WKProcessPool, WKWebsiteDataStore
- **AppKit** — NSPanel, NSAlert, NSPasteboard, NSWorkspace, NSOpenPanel
- **Bonsplit** — Panel protocol, workspace/pane model, split layout
- **CryptoKit / CommonCrypto** — Used in BrowserPanel.swift (import suggests hash-based operations)
- **Network / CFNetwork** — Proxy endpoint support
- **SQLite3** — Likely used for bookmark/history storage
- **Security** — Certificate/authentication challenge handling
- **UniformTypeIdentifiers** — Image type detection for pasteboard copy
