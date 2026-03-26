# Workspaces Design

**Last Updated**: 2026-03-26

## Architecture

Workspace is the central organizational unit in cmux, replacing traditional terminal tabs with a richer model. Each workspace is a self-contained environment with its own split pane tree, panel collection, directory context, and sidebar metadata.

```
TabManager (per window)
  |
  +-- [Workspace] (ordered list)
        |
        +-- BonsplitController (split pane tree)
        |     +-- PaneID -> [TabID] (surfaces per pane)
        |
        +-- panels: [UUID: any Panel]
        |     +-- TerminalPanel (ghostty surface)
        |     +-- BrowserPanel (WebKit)
        |     +-- MarkdownPanel (file viewer)
        |
        +-- Identity
        |     +-- id: UUID
        |     +-- title / customTitle
        |     +-- customColor (hex)
        |     +-- isPinned
        |
        +-- Directory & Git
        |     +-- currentDirectory
        |     +-- panelDirectories
        |     +-- gitBranch / panelGitBranches
        |     +-- pullRequest / panelPullRequests
        |
        +-- Sidebar Metadata
        |     +-- statusEntries
        |     +-- logEntries
        |     +-- progress
        |     +-- listeningPorts
        |
        +-- State
        |     +-- focusedPanelId (computed)
        |     +-- pinnedPanelIds
        |     +-- manualUnreadPanelIds
        |     +-- tmuxLayoutSnapshot
        |
        +-- Remote
              +-- remoteConfiguration
              +-- remoteDaemonManifest
```

## Key Components

### Workspace (final class)
- `Identifiable`, `ObservableObject` with extensive `@Published` state
- Owns `BonsplitController` for split pane management
- Manages panel lifecycle (create, close, focus, reorder)
- Provides sidebar display data (title, color, git, PR, status, logs, progress)
- Handles session snapshot/restore with split tree serialization
- Coordinates remote SSH connections

### Panel Protocol (Sources/Panels/Panel.swift)
- Protocol: `Panel: AnyObject, Identifiable, ObservableObject`
- Properties: `id`, `panelType`, `displayTitle`, `displayIcon`, `isDirty`
- Methods: `close()`, `focus()`
- Concrete types: `TerminalPanel`, `BrowserPanel`, `MarkdownPanel`

### Surface ID Mapping
- `surfaceIdToPanelId: [TabID: UUID]` maps Bonsplit tab IDs to panel UUIDs
- `panelIdFromSurfaceId()` and `surfaceIdFromPanelId()` for bidirectional lookup
- Necessary because Bonsplit uses its own `TabID` type

### WorkspaceTabColorSettings
- 16-color default palette with named entries (Red, Crimson, Orange, etc.)
- Per-color hex overrides stored in UserDefaults
- Up to 24 custom user-defined colors
- Dark mode brightening via HSB adjustment
- Thread-safe normalization and validation

### SidebarPullRequestState
- Per-panel tracking of GitHub PR state
- `sidebarPullRequestsInDisplayOrder()` resolves best PR across panels
- Filters branch mismatches and deduplicates by PR number
- Prioritizes merged > open states

### SessionWorkspaceSnapshot (Codable)
- Serializes: processTitle, customTitle, customColor, isPinned, currentDirectory
- Contains: focusedPanelId, layout (recursive split tree), panels array
- Panel snapshots include type-specific data (terminal scrollback, browser history)
- Status entries, log entries, progress, git branch

### WorkspaceRemoteConfiguration
- SSH destination, port, identity file, options
- Relay configuration (port, ID, token)
- Local socket path and terminal startup command

### WorkspaceRemoteDaemonManifest
- Describes available remote daemon binaries
- Per-entry: goOS, goArch, assetName, downloadURL, sha256
- Schema versioned for forward compatibility

### Attention Flash System
- `WorkspaceAttentionFlashReason`: navigation, notificationArrival, notificationDismiss, manualUnreadDismiss, debug
- `WorkspaceAttentionCoordinator` provides per-reason flash presentation (color, glow, duration)
- `tmuxWorkspaceFlashToken` monotonically increases to detect new flashes vs workspace switches

### Manual Unread System
- `manualUnreadPanelIds` tracks user-marked unread panels
- `manualUnreadMarkedAt` timestamps for grace interval logic
- `shouldClearManualUnread()` prevents immediate clearing when marking and focusing happen in rapid succession (0.2s grace)

## Platform Abstraction

### Platform-specific (macOS only)
- `NSColor` for color operations (hex parsing, brightening, luminance)
- `NSAppearance` for light/dark mode detection
- `UserDefaults` / `@AppStorage` for settings
- SwiftUI sidebar rendering (NavigationSplitView)
- Window glass effects and transparent backgrounds
- `NSAlert` for close confirmation dialogs

### Platform-agnostic (reusable on Linux)
- Workspace model (identity, panels, pinning, colors)
- Session snapshot serialization (Codable)
- Manual unread logic and grace intervals
- PR state resolution and branch filtering
- Tab color palette management
- Remote configuration and daemon manifest
- Attention flash state machine
- Port ordinal assignment and tracking

### Linux porting needs
- Replace NSColor with cross-platform color type
- Replace UserDefaults with file-based settings
- Replace NSAppearance with GTK theme detection
- Replace SwiftUI sidebar with GTK sidebar widget
- Replace NSAlert with platform dialog

## Data Flow

### Workspace creation
```
TabManager.addWorkspace(workingDirectory:, initialCommand:)
  -> Workspace(title: processTitle)
  -> BonsplitController(configuration: config)
  -> newTerminalSurface(inPane: rootPaneId)
  -> TerminalPanel created with GhosttyConfig
  -> surfaceIdToPanelId mapping established
```

### Panel focus flow
```
User clicks terminal / Bonsplit tab selected
  -> PanelContentView.onFocus callback
  -> Workspace.focusPanel(panelId, trigger: .terminalFirstResponder)
  -> BonsplitController.focusPane(containingPane)
  -> BonsplitController.selectTab(correspondingTabId)
  -> Terminal surface becomes first responder
  -> Manual unread cleared if applicable
```

### Session snapshot
```
App termination / periodic save
  -> Workspace.sessionSnapshot(includeScrollback:)
  -> sessionLayoutSnapshot(from: bonsplitController.treeSnapshot())
  -> recursively serialize split tree
  -> for each panel: type-specific snapshot
  -> terminal: capture scrollback text (with line limit)
  -> browser: capture URL, history, zoom, dev tools
  -> include status, log, progress, git metadata
  -> return SessionWorkspaceSnapshot (Codable)
```

### Remote connection setup
```
User initiates SSH connection (CLI or UI)
  -> Workspace.configureRemoteConnection(config)
  -> Store WorkspaceRemoteConfiguration
  -> Seed initial remote terminal session
  -> Download/deploy remote daemon binary (if needed)
  -> Establish relay connection
  -> Terminal panel runs SSH startup command
```

### Sidebar PR resolution
```
Git probe detects branch and runs `gh pr list`
  -> Store per-panel git branch and PR state
  -> sidebarPullRequestsInDisplayOrder(orderedPanelIds:)
  -> filter panels with branch mismatch
  -> deduplicate by PR number, prefer best state
  -> return ordered list for sidebar display
```

## Dependencies

### Internal
- **TabManager** (Sources/TabManager.swift): Owns and coordinates workspaces
- **BonsplitController** (vendor/bonsplit): Split pane management
- **Panel protocol** (Sources/Panels/Panel.swift): Panel type abstraction
- **TerminalPanel**, **BrowserPanel**, **MarkdownPanel**: Concrete panel types
- **GhosttyConfig** (Sources/GhosttyConfig.swift): Theme and appearance config
- **TerminalController** (Sources/TerminalController.swift): Socket command handling
- **TerminalNotificationStore**: Notification state for unread indicators

### External
- **Bonsplit** (vendor/bonsplit): Split pane tree management
- **WebKit**: Browser panel rendering
- **Sentry**: Crash reporting breadcrumbs
- **CryptoKit**: SHA256 for remote daemon checksum verification
- **Network**: Remote connection management
