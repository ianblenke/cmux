# Sidebar Design

**Last Updated**: 2026-03-26

## Architecture

The sidebar is a SwiftUI view hierarchy managing workspace navigation and panel selection. It integrates with the AppKit window system through `SidebarState` and `SidebarSelectionState` observable objects.

## Key Components

### SidebarSelectionState
- `@MainActor` `ObservableObject` publishing a `SidebarSelection` enum
- Single source of truth for the currently selected sidebar section
- Registered per-window alongside the `TabManager` and `SidebarState`

### SidebarState
- Manages sidebar visibility, width, and interaction state
- Persists width preferences
- Coordinates with window drag suppression during tab reorder

### ContentView (sidebar width clamping)
- `clampedSidebarWidth(_:maximumWidth:)` static method
- Allows narrow widths below historical minimums for compact layouts
- Maximum bounded by window width

### Sidebar Active Foreground Color
- `sidebarActiveForegroundNSColor(opacity:appAppearance:)` free function
- Returns black or white at specified opacity based on light/dark appearance
- Used for active tab indicator text

### SidebarBranchLayoutSettings
- UserDefaults-backed toggle for vertical vs. horizontal panel tree layout
- Static query method `usesVerticalLayout(defaults:)`

## Platform Abstraction

| Aspect | macOS (current) | Linux (planned) |
|--------|----------------|-----------------|
| UI Framework | SwiftUI + AppKit | GTK / custom |
| State Management | ObservableObject | Signal/reactive pattern |
| Persistence | UserDefaults | GSettings / config file |
| Color Theming | NSAppearance | GTK theme detection |
| Drag-and-Drop | NSView DnD + UTType | GDK DnD |

## Data Flow

```
User selects sidebar section
  -> SidebarSelectionState.selection = .tabs / .notifications / etc.
  -> SwiftUI re-renders sidebar content

User drags sidebar edge
  -> Gesture updates SidebarState.width
  -> ContentView.clampedSidebarWidth enforces bounds
  -> Layout updates in real time

User drags tab in sidebar
  -> beginWindowDragSuppression (prevents window move)
  -> Tab reorder via Workspace.reorderPanels
  -> endWindowDragSuppression on drop
```

## Dependencies

- SwiftUI (view hierarchy, ObservableObject)
- AppKit (NSAppearance for theme detection, NSView for drag-and-drop)
- Bonsplit (panel tree management)
- UserDefaults (preference persistence)
