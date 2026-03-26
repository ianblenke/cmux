# Split Panes Design

**Last Updated**: 2026-03-26

## Architecture

Split panes use a binary tree model managed by Bonsplit, a vendored library. Each Workspace owns one BonsplitController. The controller manages the tree structure, pane focus, tab lists within panes, and delegates UI events back to the Workspace.

```
Workspace
  |
  +-- BonsplitController
        |
        +-- Binary Tree
        |     |
        |     +-- SplitNode (orientation, dividerPosition)
        |     |     |
        |     |     +-- PaneNode (tabs: [Tab], selectedTabId)
        |     |     +-- PaneNode or SplitNode (recursive)
        |     |
        |     +-- (or single PaneNode for unsplit workspace)
        |
        +-- focusedPaneId
        +-- zoomedPaneId
        +-- isInteractive
        +-- configuration (appearance, chrome colors)
```

## Key Components

### BonsplitController
- Manages the split tree model (binary tree of panes)
- Provides APIs: `allPaneIds`, `tabs(inPane:)`, `selectedTab(inPane:)`, `focusPane()`, `reorderTab()`, `selectTab()`
- Delegates events to Workspace via `BonsplitControllerDelegate` protocol
- Supports zoom mode (single pane fills workspace)
- Manages interactive state for inactive workspace isolation

### BonsplitView (SwiftUI)
- Renders the split tree as nested views with draggable dividers
- Content closure receives `(Tab, PaneID)` for rendering each tab
- Empty pane closure renders `EmptyPanelView`
- Uses `.internalOnlyTabDrag()` modifier to restrict drag to within app
- Identified by `splitZoomRenderIdentity` for zoom state transitions

### ExternalTreeNode
- Platform-agnostic representation of the split tree
- `.pane(ExternalPaneNode)`: leaf with tabs and selected tab
- `.split(ExternalSplitNode)`: internal node with orientation, divider position, two children
- Used for tree snapshot, session persistence, and layout queries

### PanelContentView
- Wraps a Panel (terminal/browser/markdown) within a Bonsplit pane
- Manages: focus state, visibility, portal priority, unfocused overlay, notification ring
- Bridges between Bonsplit's tab model and Workspace's panel model

### EmptyPanelView
- Shown when a pane has no tabs/panels
- Offers "Terminal" and "Browser" action buttons with keyboard shortcut hints
- Calls `workspace.newTerminalSurface(inPane:)` or `workspace.newBrowserSurface(inPane:)`

### WorkspaceContentView
- Top-level SwiftUI view for a workspace
- Creates `BonsplitView` with content and empty-pane closures
- Manages theme refresh, notification badge sync, tmux overlay
- Handles minimal mode (titlebar-less) and standard mode layout
- Wires up file drop handling via `bonsplitController.onFileDrop`

### TmuxWorkspacePaneOverlayView
- Canvas-based overlay for tmux pane boundary visualization
- Renders unread indicator rings and focus flash animations
- Uses `TimelineView(.animation)` for flash opacity animation

## Platform Abstraction

### Platform-specific (macOS only)
- BonsplitView rendering (SwiftUI + AppKit hybrid)
- Drag-and-drop (UTType declarations, NSPasteboardItem)
- Divider interaction (AppKit mouse events)
- Portal hosting (NSView hierarchy management)
- Hit testing and first responder routing

### Platform-agnostic (reusable on Linux)
- Binary tree model (ExternalTreeNode, split/pane nodes)
- Tree snapshot and restoration
- Session layout serialization (SessionWorkspaceLayoutSnapshot)
- Pane focus tracking (focusedPaneId)
- Tab ordering within panes
- Notification badge state
- Tmux pane layout geometry calculations

### Linux porting needs
- Reimplement BonsplitView for GTK or platform-native toolkit
- Replace NSView-based divider interaction with platform equivalent
- Replace drag-and-drop with platform DnD protocol
- Replace portal hosting with platform window embedding
- Keep the BonsplitController model layer intact

## Data Flow

### Split creation
```
User action (Cmd+D, CLI command)
  -> Workspace.newTerminalSplit(from: panelId, orientation: .vertical)
  -> find source pane containing panelId
  -> isProgrammaticSplit = true (suppress auto-creation)
  -> BonsplitController.splitPane(paneId, orientation)
  -> create new TerminalSurface in new pane
  -> isProgrammaticSplit = false
  -> focus new pane if requested
```

### Focus navigation
```
User action (Cmd+Option+Arrow)
  -> Workspace.moveFocus(direction: .right)
  -> unfocus current panel
  -> BonsplitController resolves target pane in direction
  -> focusPane(targetPaneId)
  -> Workspace.focusPanel() makes terminal first responder
```

### Pane close
```
User closes last tab in pane (or pane explicitly closed)
  -> BonsplitController collapses split node
  -> splitTabBar(_:didClosePane:) delegate callback
  -> sibling pane takes full space
  -> focus moves to remaining pane
```

### Session restore of split layout
```
SessionWorkspaceLayoutSnapshot (recursive tree)
  -> .split(orientation, dividerPosition, first, second)
  -> Workspace creates anchor panel in root pane
  -> newTerminalSplit() creates second pane
  -> recursively restore sub-trees
  -> apply divider positions from snapshot
  -> restore tab order and selection per pane
```

### Notification badge sync
```
TerminalNotificationStore changes / manualUnreadPanelIds changes
  -> WorkspaceContentView.syncBonsplitNotificationBadges()
  -> iterate all panes and tabs
  -> compare expected badge/pinned/kind with current Bonsplit tab state
  -> BonsplitController.updateTab() for mismatches
```

## Dependencies

### Internal
- **Workspace** (Sources/Workspace.swift): Owns BonsplitController, handles panel lifecycle
- **Panel protocol** (Sources/Panels/Panel.swift): Panels rendered in panes
- **GhosttyConfig**: Provides split appearance (divider color, unfocused opacity)
- **TerminalNotificationStore**: Drives notification badge state

### External
- **Bonsplit** (vendor/bonsplit): Core split-pane library (SwiftUI + AppKit)
- **UniformTypeIdentifiers**: Custom UTTypes for drag-and-drop
