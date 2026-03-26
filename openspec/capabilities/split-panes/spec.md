# Split Panes Specification

**Status**: EXTRACTED
**Last Updated**: 2026-03-26

## Overview

Split panes provide the ability to divide a workspace into multiple resizable panes arranged in a binary tree structure. Each pane can contain multiple tabbed surfaces. The implementation uses Bonsplit, a vendored split-pane library, with cmux-specific integration for terminal panels, browser panels, and workspace coordination.

## Requirements

### REQ-SP-001: Binary tree split layout
- **Description**: Each workspace contains one `BonsplitController` that manages a binary tree of panes. Panes can be split horizontally or vertically, creating nested split hierarchies. The tree structure is captured via `ExternalTreeNode` (either `.pane` or `.split` with two children).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-SP-002: Horizontal and vertical splits
- **Description**: `Workspace.newTerminalSplit(from:orientation:insertFirst:focus:)` creates a new split from an existing panel. Supports both `.horizontal` and `.vertical` orientations. The `insertFirst` parameter controls whether the new pane appears before or after the source.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-SP-003: Pane focus management
- **Description**: `BonsplitController.focusPane()` sets the focused pane. `BonsplitController.focusedPaneId` tracks the currently focused pane. Focus is synchronized with AppKit first responder via `FocusPanelTrigger.terminalFirstResponder`.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-SP-004: Directional focus navigation
- **Description**: `Workspace.moveFocus(direction:)` moves focus between panes using cardinal directions (up, down, left, right). Unfocuses the current panel before navigating.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-SP-005: Pane close handling
- **Description**: When a pane is closed (`splitTabBar(_:didClosePane:)`), the split tree collapses. The remaining sibling takes the full space. Bonsplit notifies the workspace delegate of pane close events.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-SP-006: Tabbed surfaces within panes
- **Description**: Each pane can contain multiple tabs (surfaces). `BonsplitController.tabs(inPane:)` returns the tab list. `BonsplitController.selectedTab(inPane:)` returns the active tab. Tab selection, closing, and reordering are delegated to Bonsplit.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-SP-007: Split divider dragging
- **Description**: Dividers between panes are draggable for resizing. Divider positions are stored as fractions in the split tree nodes and persisted in session snapshots.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-SP-008: Split zoom (maximize single pane)
- **Description**: `BonsplitController.zoomedPaneId` tracks whether a single pane is zoomed to fill the workspace. When zoomed, the Bonsplit subtree is recreated with an identity key change to prevent stale pane chrome.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-SP-009: Tab drag between panes
- **Description**: Tabs can be dragged between panes within the same workspace. `splitTabBar(_:didMoveTab:fromPane:toPane:)` handles the drop. Custom UTTypes (`com.splittabbar.tabtransfer`) are declared in Info.plist for drag-and-drop. Drag operations are restricted to within the app (no external drag).
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-SP-010: External tab drop (cross-workspace)
- **Description**: `handleExternalTabDrop()` handles tab drops from other workspaces or windows. This enables moving panels between workspaces via drag.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-SP-011: File drop handling
- **Description**: `BonsplitController.onFileDrop` callback routes Finder file drops to the correct terminal panel. The workspace resolves the target panel from the pane's selected tab.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-SP-012: Tab close confirmation
- **Description**: `splitTabBar(_:shouldCloseTab:inPane:)` is called before closing a tab. The workspace can veto the close (e.g., for unsaved state or pinned panels).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-SP-013: Unfocused pane dimming
- **Description**: When a workspace has multiple panes, unfocused panes show a semi-transparent overlay. Opacity is controlled by `GhosttyConfig.unfocusedSplitOpacity` (clamped 0.15-1.0). Overlay color comes from `unfocusedSplitFill` or falls back to background color.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-SP-014: Split layout session persistence
- **Description**: Split tree structure, divider positions, and per-pane tab order are serialized in `SessionWorkspaceLayoutSnapshot`. Restore recreates the split hierarchy and populates panes with panels from snapshots.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-SP-015: Notification badge sync across panes
- **Description**: `WorkspaceContentView.syncBonsplitNotificationBadges()` iterates all panes and tabs to sync notification badge visibility, pinned state, and panel kind with the Bonsplit tab model.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-SP-016: Interactive state control for inactive workspaces
- **Description**: `BonsplitController.isInteractive` is set to false for inactive workspaces (kept alive in ZStack). This prevents stale AppKit views from intercepting drags intended for the active workspace.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-SP-017: Programmatic split suppression
- **Description**: `isProgrammaticSplit` flag suppresses auto-creation of terminal panels in `didSplitPane` callback during programmatic operations (session restore, CLI-initiated splits).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-SP-018: BonsplitView SwiftUI integration
- **Description**: `BonsplitView` is the SwiftUI component that renders the split tree. It receives content closures for rendering each tab and empty panes. The view is identified by `splitZoomRenderIdentity` to force recreation on zoom state changes.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0 (critical)

### REQ-SP-019: Empty pane view
- **Description**: `EmptyPanelView` is shown for panes with no surfaces. It displays action buttons to create a new Terminal or Browser surface, with keyboard shortcut hints.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1 (important)

### REQ-SP-020: Tmux pane layout overlay
- **Description**: When tmux integration is active, `TmuxWorkspacePaneOverlayView` renders unread indicator rings and focus flash animations over tmux pane boundaries using the reported tmux pane layout.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P2 (nice-to-have)

## Scenarios

### SCENARIO-SP-001: Panel visible when selected in pane
- **Given**: A workspace is visible and a panel is selected in its pane
- **When**: `panelVisibleInUI` is evaluated
- **Then**: Returns true
- **Verifies**: REQ-SP-006
- **Status**: Covered

### SCENARIO-SP-002: Panel visible when focused during transient selection gap
- **Given**: A workspace is visible, panel is focused but transiently not selected (reparenting)
- **When**: `panelVisibleInUI` is evaluated
- **Then**: Returns true (focused overrides transient deselection)
- **Verifies**: REQ-SP-003
- **Status**: Covered

### SCENARIO-SP-003: Panel not visible in hidden workspace
- **Given**: A workspace is not visible
- **When**: `panelVisibleInUI` is evaluated for any panel
- **Then**: Returns false regardless of selection/focus state
- **Verifies**: REQ-SP-006
- **Status**: Covered

### SCENARIO-SP-004: Panel not visible when neither selected nor focused
- **Given**: A workspace is visible, panel is neither selected nor focused
- **When**: `panelVisibleInUI` is evaluated
- **Then**: Returns false
- **Verifies**: REQ-SP-006
- **Status**: Covered

### SCENARIO-SP-005: Background primed workspace stays mounted but not panel-visible
- **Given**: A workspace is being primed in the background (not selected, not retiring)
- **When**: Mounted workspace presentation is resolved
- **Then**: `isRenderedVisible` is false, `isPanelVisible` is false, `renderOpacity` is 0.001
- **Verifies**: REQ-SP-016
- **Status**: Covered

### SCENARIO-SP-006: Retiring workspace stays panel-visible during handoff
- **Given**: A workspace is retiring (being replaced by new selection)
- **When**: Mounted workspace presentation is resolved
- **Then**: `isRenderedVisible` and `isPanelVisible` are both true
- **Verifies**: REQ-SP-016
- **Status**: Covered

### SCENARIO-SP-007: Split creates new pane with terminal
- **Given**: A workspace with a single pane and terminal panel
- **When**: `newTerminalSplit(from:orientation:.vertical)` is called
- **Then**: Two panes exist in a vertical split, each with a terminal surface
- **Verifies**: REQ-SP-002
- **Status**: Missing

### SCENARIO-SP-008: Split layout persists and restores
- **Given**: A workspace with a vertical split (two panes, each with panels)
- **When**: Session snapshot is taken and restored
- **Then**: Restored workspace has the same split orientation and panel arrangement
- **Verifies**: REQ-SP-014
- **Status**: Partial (covered by session snapshot tests)

### SCENARIO-SP-009: Empty pane shows action buttons
- **Given**: A pane with no surfaces
- **When**: The pane is rendered
- **Then**: EmptyPanelView is shown with Terminal and Browser creation buttons
- **Verifies**: REQ-SP-019
- **Status**: Missing

### SCENARIO-SP-010: File drop routed to correct terminal panel
- **Given**: A workspace with two panes, file dropped onto the second pane
- **When**: `onFileDrop` callback fires
- **Then**: URLs are forwarded to the terminal panel in the second pane's selected tab
- **Verifies**: REQ-SP-011
- **Status**: Missing

## Cross-Platform Notes

- Bonsplit is a Swift-based library using SwiftUI and AppKit. For Linux, the split tree model can be reused but the view layer needs a GTK or platform-native equivalent.
- Drag-and-drop (UTType declarations, NSPasteboardItem) is macOS-specific. Linux needs equivalent DnD protocol support.
- `NSView` hit testing and first responder management are AppKit concepts. Linux needs equivalent focus routing.
- Split divider rendering and interaction is AppKit-based in Bonsplit.
- The binary tree data model (`ExternalTreeNode`, `ExternalSplitNode`, `ExternalPaneNode`) is platform-agnostic.

## Implementation Status

Split pane functionality is fully implemented on macOS via the Bonsplit library. The Bonsplit submodule source is vendored at `vendor/bonsplit/` but is compiled as a separate module. Session persistence of split layouts works. Cross-platform support requires reimplementing the Bonsplit view layer for Linux.
