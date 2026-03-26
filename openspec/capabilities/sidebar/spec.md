# Sidebar Specification

**Status**: EXTRACTED
**Last Updated**: 2026-03-26

## Overview

The sidebar provides workspace navigation, panel ordering, and selection state management. It supports resizable width, configurable layout (vertical/horizontal branch display), and appearance customization tied to the system theme.

## Requirements

### REQ-SB-001: Sidebar Selection State
- **Description**: `SidebarSelectionState` is an `ObservableObject` that publishes a `SidebarSelection` enum value. It runs on the `@MainActor` and is the single source of truth for which sidebar section is currently selected.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-SB-002: Sidebar Width Policy
- **Description**: The sidebar width is clamped within bounds but allows narrow widths below the legacy minimum. `ContentView.clampedSidebarWidth` enforces the policy.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-SB-003: Sidebar Active Foreground Color
- **Description**: The active tab foreground color adapts to system appearance: black (with configurable opacity) in light mode, white (with configurable opacity) in dark mode.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2

### REQ-SB-004: Sidebar Branch Layout Settings
- **Description**: Users can toggle between vertical and horizontal branch layout for the sidebar. The preference persists via UserDefaults. Default is vertical layout.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2

### REQ-SB-005: Sidebar Panel Ordering
- **Description**: Panels in the sidebar are ordered according to `sidebarOrderedPanelIds()` on the workspace, supporting drag-and-drop reordering.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-SB-006: Sidebar Resize Interaction
- **Description**: The sidebar can be resized by dragging its edge. The resize interaction is implemented as a UI-level gesture.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-SB-007: Sidebar Help Menu
- **Description**: The sidebar includes a help/context menu accessible via the UI.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2

## Scenarios

### SCENARIO-SB-001: Light Appearance Uses Black Foreground
- **Given**: The system appearance is light (Aqua)
- **When**: `sidebarActiveForegroundNSColor(opacity: 0.8)` is called
- **Then**: Returns black with alpha 0.8
- **Verifies**: REQ-SB-003
- **Status**: Covered

### SCENARIO-SB-002: Dark Appearance Uses White Foreground
- **Given**: The system appearance is dark (DarkAqua)
- **When**: `sidebarActiveForegroundNSColor(opacity: 0.65)` is called
- **Then**: Returns white with alpha 0.65
- **Verifies**: REQ-SB-003
- **Status**: Covered

### SCENARIO-SB-003: Default Branch Layout Is Vertical
- **Given**: A fresh UserDefaults suite with no saved preferences
- **When**: `SidebarBranchLayoutSettings.usesVerticalLayout` is queried
- **Then**: Returns true
- **Verifies**: REQ-SB-004
- **Status**: Covered

### SCENARIO-SB-004: Narrow Sidebar Width Allowed
- **Given**: A sidebar width of 184 with a maximum window width of 600
- **When**: `ContentView.clampedSidebarWidth(184, maximumWidth: 600)` is called
- **Then**: Returns 184 (not clamped to a legacy minimum)
- **Verifies**: REQ-SB-002
- **Status**: Covered

### SCENARIO-SB-005: Sidebar Resize via Drag
- **Given**: The sidebar is displayed at its default width
- **When**: The user drags the sidebar edge
- **Then**: The sidebar width updates in real time within clamped bounds
- **Verifies**: REQ-SB-006
- **Status**: Partial (UI test exists)

### SCENARIO-SB-006: Sidebar Help Menu Opens
- **Given**: The sidebar is visible
- **When**: The user activates the help menu
- **Then**: The help/context menu is displayed
- **Verifies**: REQ-SB-007
- **Status**: Partial (UI test exists)

## Cross-Platform Notes

- Sidebar rendering is SwiftUI + AppKit (macOS-only). Linux will need a GTK or custom sidebar implementation.
- `SidebarSelectionState` as an ObservableObject pattern can be reused if SwiftUI is available on Linux, otherwise needs a platform-specific state management approach.
- The width clamping logic is pure arithmetic and is cross-platform.
- Branch layout settings can use platform-appropriate persistence (UserDefaults on macOS, GSettings/dconf on Linux).

## Implementation Status

| Requirement | Status | Test Coverage |
|-------------|--------|--------------|
| REQ-SB-001 | Implemented | (trivial, no dedicated test) |
| REQ-SB-002 | Implemented | SidebarWidthPolicyTests |
| REQ-SB-003 | Implemented | SidebarOrderingTests |
| REQ-SB-004 | Implemented | SidebarOrderingTests |
| REQ-SB-005 | Implemented | SidebarOrderingTests |
| REQ-SB-006 | Implemented | SidebarResizeUITests |
| REQ-SB-007 | Implemented | SidebarHelpMenuUITests |
