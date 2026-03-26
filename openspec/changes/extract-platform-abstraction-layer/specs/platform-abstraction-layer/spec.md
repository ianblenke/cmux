## ADDED Requirements

### Requirement: PAL protocol suite exists
The system SHALL define a set of Swift protocols in `Sources/PAL/` that abstract all platform-specific operations needed by the core logic layer. The protocol suite SHALL include: `PlatformAppLifecycle`, `PlatformWindow`, `PlatformSurface`, `PlatformSplitContainer`, `PlatformWebView`, `PlatformClipboard`, `PlatformNotification`, `PlatformMenuBar`, `PlatformKeyboard`, `PlatformDragDrop`, `PlatformUpdateChecker`, `PlatformFileDialog`, `PlatformAppearance`.

#### Scenario: PAL protocols compile independently
- **WHEN** the `cmux-pal` SPM target is built in isolation
- **THEN** it compiles successfully with only Foundation imports (no AppKit, SwiftUI, Cocoa, WebKit)

#### Scenario: PAL protocols are sufficient for core logic
- **WHEN** the `cmux-core` SPM target is built
- **THEN** it compiles successfully importing only Foundation and `cmux-pal` (no platform framework imports)

### Requirement: Core logic layer has no platform imports
The `Sources/Core/` directory SHALL contain all platform-agnostic logic: workspace model, tab management, config parsing, socket control, session persistence, notification store, port scanning, SSH detection. No file in `Sources/Core/` SHALL import AppKit, SwiftUI, Cocoa, WebKit, Sparkle, or any macOS-specific framework.

#### Scenario: Core directory import audit
- **WHEN** all files in `Sources/Core/` are scanned for import statements
- **THEN** no file contains `import AppKit`, `import SwiftUI`, `import Cocoa`, `import WebKit`, or `import Sparkle`

### Requirement: macOS backend implements PAL protocols
The `Sources/macOS/` directory SHALL contain macOS-specific implementations conforming to all PAL protocols. Each implementation SHALL wrap existing AppKit/SwiftUI code without behavioral changes.

#### Scenario: macOS backend compiles
- **WHEN** the `cmux-macos` SPM target is built on macOS
- **THEN** it compiles successfully and all PAL protocol conformances are satisfied

#### Scenario: Existing tests pass after extraction
- **WHEN** the full test suite (46 unit + UI tests) is run after the PAL extraction
- **THEN** all tests pass with zero failures and zero behavioral changes

### Requirement: Platform type aliases
The PAL SHALL provide `PlatformTypes.swift` with cross-platform type aliases for basic geometry and color types (`PlatformRect`, `PlatformSize`, `PlatformPoint`, `PlatformColor`, `PlatformFont`, `PlatformImage`). On macOS, these alias to NS types. On Linux, they alias to Foundation types or custom lightweight structs.

#### Scenario: Type aliases resolve on macOS
- **WHEN** code references `PlatformRect` on macOS
- **THEN** it resolves to `NSRect` and is fully interoperable with AppKit APIs

### Requirement: Platform path conventions
The PAL SHALL provide `PlatformPaths` with cross-platform path resolution for config directory, data directory, runtime directory, and socket path. On macOS, paths use `~/Library/Application Support/cmux`. On Linux, paths follow XDG Base Directory specification.

#### Scenario: Config path resolves correctly on macOS
- **WHEN** `PlatformPaths.configDir` is accessed on macOS
- **THEN** it returns `~/Library/Application Support/cmux`

#### Scenario: Config path follows XDG on Linux
- **WHEN** `PlatformPaths.configDir` is accessed on Linux with `XDG_CONFIG_HOME=/custom`
- **THEN** it returns `/custom/cmux`

### Requirement: SPM target structure
The `Package.swift` SHALL define three targets: `cmux-core` (shared logic, depends on `cmux-pal`), `cmux-pal` (protocol definitions, Foundation only), and `cmux-macos` (macOS backend, depends on `cmux-core` + `cmux-pal` + system frameworks). Target dependencies SHALL enforce that core cannot import platform frameworks.

#### Scenario: SPM targets build successfully
- **WHEN** `swift build` is run on macOS
- **THEN** all three targets compile without errors

### Requirement: Xcode project compatibility
The `GhosttyTabs.xcodeproj` SHALL continue to build the macOS app after the directory reorganization. File references SHALL be updated to match the new `Sources/{Core,PAL,macOS}/` layout.

#### Scenario: Xcode build succeeds
- **WHEN** `xcodebuild -scheme cmux -configuration Debug build` is run
- **THEN** the build succeeds and produces a working `.app` bundle
