## 1. PAL Protocol Definitions

- [x] 1.1 Create `Sources/PAL/` directory and `PlatformTypes.swift` with cross-platform type aliases (PlatformRect, PlatformSize, PlatformPoint, PlatformColor, PlatformFont, PlatformImage)
- [x] 1.2 Create `PlatformPaths.swift` with cross-platform path conventions (configDir, dataDir, runtimeDir, socketPath) using XDG on Linux, Application Support on macOS
- [x] 1.3 Create `PlatformAppLifecycle.swift` protocol (run, quit, isActive, registerURLScheme)
- [x] 1.4 Create `PlatformWindow.swift` protocol (title, frame, fullScreen, makeKeyAndVisible, close, sidebar, toolbar)
- [x] 1.5 Create `PlatformSurface.swift` protocol (nativeView, focus, resize, sendInput, onTitleChange, onBell, onClose)
- [x] 1.6 Create `PlatformSplitContainer.swift` protocol (split, removeSurface, moveDivider, surfaces)
- [x] 1.7 Create `PlatformWebView.swift` protocol (load, evaluateJavaScript, onNavigate, onTitleChange)
- [x] 1.8 Create `PlatformClipboard.swift` protocol (copy, paste, copyImage)
- [x] 1.9 Create `PlatformNotification.swift` protocol (post, requestPermission)
- [x] 1.10 Create `PlatformMenuBar.swift` protocol (setMenus, updateMenuItem)
- [x] 1.11 Create `PlatformKeyboard.swift` protocol (resolveCharacter, currentModifiers)
- [x] 1.12 Create `PlatformDragDrop.swift` protocol (registerDragTypes, performDrag)
- [x] 1.13 Create `PlatformUpdateChecker.swift` protocol (checkForUpdates, updateAvailable, isSupported)
- [x] 1.14 Create `PlatformFileDialog.swift` protocol (openFile, saveFile)
- [x] 1.15 Create `PlatformAppearance.swift` protocol (isDarkMode, accentColor, onAppearanceChange)
- [x] 1.16 Verify `cmux-pal` SPM target compiles with Foundation-only imports

## 2. Core Logic Extraction — Pure Models

- [x] 2.1 Create `Sources/Core/` directory
- [ ] 2.2 Extract `CmuxConfig.swift` core logic to `Sources/Core/` — needs major split (AppKit NSColor/NSString refs)
- [ ] 2.3 Extract `CmuxConfigExecutor.swift` core logic to `Sources/Core/` — needs major split (NSAlert UI)
- [ ] 2.4 Extract `GhosttyConfig.swift` core logic to `Sources/Core/` — needs major split (NSColor, NSApp, UserDefaults)
- [x] 2.5 Extract `SessionPersistence.swift` models to `Sources/Core/SessionPersistenceModels.swift` — pure Codable types + policy logic
- [ ] 2.6 Extract `TerminalNotificationStore.swift` model logic to `Sources/Core/` — needs major split (UNUserNotificationCenter, NSSound)
- [ ] 2.7 Extract `SidebarSelectionState.swift` model logic to `Sources/Core/CoreTypes.swift` — CoreSidebarSelection enum extracted
- [x] 2.8 Extract `SocketControlSettings.swift` mode enum to `Sources/Core/CoreTypes.swift` — CoreSocketControlMode extracted
- [x] 2.9 Extract `CmuxDirectoryTrust.swift` to `Sources/Core/DirectoryTrust.swift` — platform-agnostic reimplementation
- [x] 2.10 Verify `cmux-core` target compiles importing only Foundation + cmux-pal

## 3. Core Logic Extraction — Services

- [ ] 3.1 Extract `PortScanner.swift` to `Sources/Core/` — needs minor edits (Foundation/Darwin only but uses DispatchQueue coalescing)
- [ ] 3.2 Extract `TerminalSSHSessionDetector.swift` to `Sources/Core/` — needs PAL abstraction (sysctl on macOS, /proc on Linux)
- [x] 3.3 Copy `RemoteRelayZshBootstrap.swift` to `Sources/Core/` — pure Foundation string generation
- [ ] 3.4 Move `KeyboardShortcutSettings.swift` model layer to `Sources/Core/` — shortcut storage and action registry; keyboard layout resolution stays in macOS layer
- [ ] 3.5 Move `TerminalImageTransfer.swift` to `Sources/Core/` if platform-agnostic, or split model/platform portions

## 4. Core Logic Extraction — Managers

- [ ] 4.1 Extract `TabManager.swift` core logic to `Sources/Core/` — workspace list management, ordering, selection. Keep SwiftUI @Published observation in macOS wrapper
- [ ] 4.2 Extract `Workspace.swift` model logic to `Sources/Core/` — workspace identity, panel management, metadata. Surface creation delegates to PAL
- [ ] 4.3 Extract panel protocol and model types (`Panel.swift`, `TerminalPanel.swift`, `BrowserPanel.swift`, `MarkdownPanel.swift`) to `Sources/Core/` where platform-agnostic
- [ ] 4.4 Verify Core target compiles with all extracted managers

## 5. macOS Backend Wrappers

- [ ] 5.1 Create `Sources/macOS/` directory
- [ ] 5.2 Create `MacOSClipboard.swift` conforming to `PlatformClipboard` wrapping NSPasteboard
- [ ] 5.3 Create `MacOSNotification.swift` conforming to `PlatformNotification` wrapping UNUserNotificationCenter
- [ ] 5.4 Create `MacOSAppearance.swift` conforming to `PlatformAppearance` wrapping NSApplication.effectiveAppearance
- [ ] 5.5 Create `MacOSUpdateChecker.swift` conforming to `PlatformUpdateChecker` wrapping Sparkle
- [ ] 5.6 Create `MacOSFileDialog.swift` conforming to `PlatformFileDialog` wrapping NSOpenPanel/NSSavePanel
- [ ] 5.7 Move existing SwiftUI/AppKit view files to `Sources/macOS/` (ContentView, WorkspaceContentView, GhosttyTerminalView, TerminalWindowPortal, BrowserWindowPortal, WindowAccessor, WindowDecorationsController, WindowToolbarController, WindowDragHandleView)
- [ ] 5.8 Move existing panel view files to `Sources/macOS/` (BrowserPanelView, TerminalPanelView, PanelContentView, MarkdownPanelView, CmuxWebView, BrowserPopupWindowController)
- [ ] 5.9 Move existing app lifecycle files to `Sources/macOS/` (cmuxApp.swift, AppDelegate.swift, AppleScriptSupport.swift)
- [ ] 5.10 Move Update/ directory to `Sources/macOS/Update/` (all 12 update files are Sparkle/macOS-specific)
- [ ] 5.11 Move Find/ overlay views to `Sources/macOS/Find/` (SurfaceSearchOverlay, BrowserSearchOverlay — JS generation in BrowserFindJavaScript stays in Core)
- [ ] 5.12 Move analytics files to `Sources/macOS/` (PostHogAnalytics.swift, SentryHelper.swift)
- [ ] 5.13 Move remaining macOS-specific files (NotificationsPage.swift, UITestRecorder.swift, Backport.swift, KeyboardLayout.swift)

## 6. Build System Updates

- [ ] 6.1 Update `Package.swift` with three targets: `cmux-pal` (Sources/PAL), `cmux-core` (Sources/Core, depends on cmux-pal), `cmux-macos` (Sources/macOS, depends on cmux-core + cmux-pal)
- [ ] 6.2 Update `GhosttyTabs.xcodeproj` file references to match new directory structure (Sources/Core, Sources/PAL, Sources/macOS groups)
- [ ] 6.3 Verify Xcode build succeeds: `xcodebuild -scheme cmux -configuration Debug build`
- [ ] 6.4 Verify SPM build succeeds: `swift build` on macOS

## 7. Validation

- [ ] 7.1 Run all unit tests: verify 30 cmuxTests pass
- [ ] 7.2 Run all UI tests: verify 16 cmuxUITests pass
- [ ] 7.3 Audit `Sources/Core/` — confirm zero AppKit/SwiftUI/Cocoa/WebKit imports via grep
- [ ] 7.4 Audit `Sources/PAL/` — confirm only Foundation imports
- [ ] 7.5 Build tagged debug app via `reload.sh --tag pal-extract` and verify basic functionality (create workspace, type in terminal, split pane, open browser, notifications)
- [ ] 7.6 Update `openspec/capabilities/cross-platform/spec.md` — mark REQ-XP-001, REQ-XP-002, REQ-XP-003 as Implemented
- [ ] 7.7 Update `_bmad/traceability.md` — update PAL-related REQ statuses
