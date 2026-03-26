# Tab Management Design

**Last Updated**: 2026-03-26

## Architecture

TabManager is the top-level state owner for a single cmux window. Each window has one TabManager instance registered with the AppDelegate. TabManager holds the workspace list and delegates per-workspace operations to individual Workspace objects.

```
AppDelegate
  |
  +-- NSWindow (main window)
  |     |
  |     +-- TabManager (owns workspace list)
  |           |
  |           +-- [Workspace] (ordered array)
  |           |     |
  |           |     +-- BonsplitController (split panes)
  |           |     +-- [Panel] (terminal, browser, markdown)
  |           |
  |           +-- selectedTabId (UUID)
  |           +-- Session snapshot/restore
  |           +-- Git metadata probing
  |           +-- Recently closed browser stack
```

## Key Components

### TabManager
- `ObservableObject` with `@Published var tabs: [Workspace]` and `@Published var selectedTabId: UUID?`
- Singleton per window; registered via `AppDelegate.registerMainWindow()`
- Manages workspace CRUD, selection, reordering, session persistence
- Coordinates git probing, notification routing, port ordinal assignment
- Maintains `isWorkspaceCycleHot` for rapid-switch overlay

### WorkspacePlacementSettings
- Enum-based setting for new workspace insertion position
- `insertionIndex()` computes correct position respecting pinned workspaces
- Stored in UserDefaults as `newWorkspacePlacement`

### LastSurfaceCloseShortcutSettings
- Controls Cmd+W behavior on last surface: close workspace vs keep empty
- Stored in UserDefaults as `closeWorkspaceOnLastSurfaceShortcut`

### WorkspaceAutoReorderSettings
- Controls automatic workspace promotion on notification arrival
- Default enabled; stored as `workspaceAutoReorderOnNotification`

### NotificationBurstCoalescer
- Coalesces rapid notification storms into a single callback
- Used to debounce sidebar/tab updates during notification bursts
- Configurable delay (default 1/30s)

### RecentlyClosedBrowserStack
- Bounded LIFO stack for Cmd+Shift+T browser panel restore
- Stores `ClosedBrowserPanelRestoreSnapshot` with URL, profile, history

### SessionTabManagerSnapshot
- Codable snapshot of workspace list and selected index
- Each workspace serialized as `SessionWorkspaceSnapshot`
- Remote workspaces excluded from snapshots

### Tab type alias
- `typealias Tab = Workspace` provides backwards compatibility
- Code references both `Tab` and `Workspace` interchangeably

## Platform Abstraction

### Platform-specific (macOS only)
- `window: NSWindow?` weak reference for title bar updates
- `NSAlert` confirmation dialogs for workspace close
- Keyboard shortcut integration (Cmd+W, Cmd+T, Cmd+Shift+T)
- `AppDelegate` registration and window context routing

### Platform-agnostic (reusable on Linux)
- Workspace list management (add, remove, reorder, select)
- Session snapshot serialization/deserialization
- Placement index calculation
- Port ordinal assignment
- Git probing logic (uses `Process`)
- Notification coalescing

### Linux porting needs
- Window reference abstraction (replace NSWindow)
- Dialog abstraction (replace NSAlert)
- Keyboard shortcut mapping (Ctrl vs Cmd)
- UserDefaults replacement (file-based settings)

## Data Flow

### Workspace creation
```
User action (Cmd+N, CLI, sidebar button)
  -> TabManager.addWorkspace(workingDirectory:, initialCommand:)
  -> WorkspacePlacementSettings.insertionIndex()
  -> tabs.insert(workspace, at: computedIndex)
  -> selectWorkspace(workspace)  [if select: true]
  -> Workspace.init creates BonsplitController + initial terminal panel
```

### Workspace selection
```
User clicks sidebar / Cmd+] / selectWorkspace()
  -> selectedTabId = workspace.id
  -> ContentView re-renders active workspace
  -> WorkspaceContentView receives isWorkspaceVisible: true
  -> Terminal surface gains first responder
```

### Session persistence
```
App termination / periodic save
  -> TabManager.sessionSnapshot(includeScrollback:)
  -> filter out remote workspaces
  -> serialize each workspace: title, color, pinned, panels, layout, scrollback
  -> write to Application Support

App launch
  -> read snapshot from disk
  -> TabManager.restoreSessionSnapshot()
  -> recreate workspaces with panels and split layout
  -> restore selection
```

### Child exit handling
```
ghostty child process exits
  -> TerminalController routes to Workspace
  -> Workspace.closePanel() removes panel
  -> if last panel in workspace:
       TabManager.closePanelAfterChildExited()
       -> closeWorkspace() removes from list
       -> selection stays at same index (or clamps to last)
```

## Dependencies

### Internal
- **Workspace** (Sources/Workspace.swift): Managed by TabManager
- **TerminalController** (Sources/TerminalController.swift): Socket command routing
- **AppDelegate**: Window registration, keyboard shortcut dispatch
- **ContentView** (Sources/ContentView.swift): SwiftUI sidebar and workspace rendering

### External
- **Bonsplit** (vendor/bonsplit): Split pane management within workspaces
- **Sentry**: Breadcrumb logging for workspace operations
- **UserDefaults**: Settings persistence
