# Traceability Matrix

**Last Updated**: 2026-03-26
**Status**: EXTRACTED

## Summary

| Capability | REQ Count | Spec Status | Impl Status | Test Status |
|-----------|-----------|-------------|-------------|-------------|
| terminal-core | 20 | EXTRACTED | Implemented | Partial |
| tab-management | 21 | EXTRACTED | Implemented | Partial |
| split-panes | 20 | EXTRACTED | Implemented | Partial |
| workspaces | 33 | EXTRACTED | Implemented | Partial |
| browser-panels | 19 | EXTRACTED | Implemented | Partial |
| session-persistence | 14 | EXTRACTED | Implemented | Covered |
| notifications | 17 | EXTRACTED | Implemented | Covered |
| socket-control | 16 | EXTRACTED | Implemented | Covered |
| update-system | 21 | EXTRACTED | Implemented | Partial |
| configuration | 22 | EXTRACTED | Implemented | Partial |
| keyboard-shortcuts | 21 | EXTRACTED | Implemented | Partial |
| search-find | 21 | EXTRACTED | Implemented | Partial |
| remote-daemon | 14 | EXTRACTED | Implemented | Covered |
| ssh-detection | 8 | EXTRACTED | Implemented | Covered |
| window-management | 10 | EXTRACTED | Implemented | Partial |
| sidebar | 7 | EXTRACTED | Implemented | Partial |
| applescript | 11 | EXTRACTED | Implemented | Missing |
| port-scanning | 8 | EXTRACTED | Implemented | Missing |
| analytics | 12 | EXTRACTED | Implemented | Missing |
| localization | 10 | EXTRACTED | Partial | Missing |
| cross-platform | 30 | PROPOSED | Not Started | Not Started |

**Total**: 355 requirements across 21 capabilities

## Detailed Requirements

### terminal-core

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-TC-001 | Ghostty-based terminal emulation | Implemented | Partial |
| REQ-TC-002 | Configuration loading from Ghostty config files | Implemented | Partial |
| REQ-TC-003 | Theme resolution with light/dark mode support | Implemented | Covered |
| REQ-TC-004 | Theme name candidate resolution with aliases | Implemented | Covered |
| REQ-TC-005 | Color palette configuration | Implemented | Covered |
| REQ-TC-006 | Font configuration | Implemented | Partial |
| REQ-TC-007 | Background opacity and transparency | Implemented | Partial |
| REQ-TC-008 | Clipboard handling (paste/copy) | Implemented | Covered |
| REQ-TC-009 | Shell escape for pasted file URLs | Implemented | Covered |
| REQ-TC-010 | Terminal surface registry | Implemented | Partial |
| REQ-TC-011 | Surface lifecycle safety (pointer liveness checks) | Implemented | Missing |
| REQ-TC-012 | Terminal surface portal hosting | Implemented | Partial |
| REQ-TC-013 | Config caching with color-scheme keying | Implemented | Partial |
| REQ-TC-014 | Split divider and unfocused pane appearance | Implemented | Missing |
| REQ-TC-015 | Sidebar background configuration | Implemented | Partial |
| REQ-TC-016 | Scrollback limit configuration | Implemented | Partial |
| REQ-TC-017 | Working directory configuration | Implemented | Partial |
| REQ-TC-018 | Terminal surface search | Implemented | Partial |
| REQ-TC-019 | SwiftTerm fallback terminal | Implemented | Partial |
| REQ-TC-020 | Port ordinal assignment for CMUX_PORT | Implemented | Partial |

### tab-management

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-TM-001 | Workspace list management | Implemented | Partial |
| REQ-TM-002 | Workspace selection | Implemented | Partial |
| REQ-TM-003 | Add workspace with configurable placement | Implemented | Partial |
| REQ-TM-004 | Workspace placement insertion index calculation | Implemented | Missing |
| REQ-TM-005 | Close workspace with confirmation | Implemented | Missing |
| REQ-TM-006 | Bulk workspace close | Implemented | Partial |
| REQ-TM-007 | Child exit closes workspace | Implemented | Covered |
| REQ-TM-008 | Workspace reordering | Implemented | Missing |
| REQ-TM-009 | Next/previous workspace navigation | Implemented | Missing |
| REQ-TM-010 | Surface navigation within workspace | Implemented | Partial |
| REQ-TM-011 | Session snapshot and restore | Implemented | Covered |
| REQ-TM-012 | Session restore with empty snapshot | Implemented | Covered |
| REQ-TM-013 | Remote workspaces excluded from session persistence | Implemented | Covered |
| REQ-TM-014 | Workspace auto-reorder on notification | Implemented | Partial |
| REQ-TM-015 | Last surface close behavior setting | Implemented | Partial |
| REQ-TM-016 | Window ownership | Implemented | Partial |
| REQ-TM-017 | Workspace cycle hot window | Implemented | Partial |
| REQ-TM-018 | Recently closed browser stack | Implemented | Partial |
| REQ-TM-019 | Port ordinal assignment | Implemented | Partial |
| REQ-TM-020 | Git metadata probing | Implemented | Partial |
| REQ-TM-021 | Background workspace preloading | Implemented | Partial |

### split-panes

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-SP-001 | Binary tree split layout | Implemented | Partial |
| REQ-SP-002 | Horizontal and vertical splits | Implemented | Missing |
| REQ-SP-003 | Pane focus management | Implemented | Covered |
| REQ-SP-004 | Directional focus navigation | Implemented | Partial |
| REQ-SP-005 | Pane close handling | Implemented | Partial |
| REQ-SP-006 | Tabbed surfaces within panes | Implemented | Covered |
| REQ-SP-007 | Split divider dragging | Implemented | Partial |
| REQ-SP-008 | Split zoom (maximize single pane) | Implemented | Partial |
| REQ-SP-009 | Tab drag between panes | Implemented | Partial |
| REQ-SP-010 | External tab drop (cross-workspace) | Implemented | Partial |
| REQ-SP-011 | File drop handling | Implemented | Missing |
| REQ-SP-012 | Tab close confirmation | Implemented | Partial |
| REQ-SP-013 | Unfocused pane dimming | Implemented | Partial |
| REQ-SP-014 | Split layout session persistence | Implemented | Partial |
| REQ-SP-015 | Notification badge sync across panes | Implemented | Partial |
| REQ-SP-016 | Interactive state control for inactive workspaces | Implemented | Covered |
| REQ-SP-017 | Programmatic split suppression | Implemented | Partial |
| REQ-SP-018 | BonsplitView SwiftUI integration | Implemented | Partial |
| REQ-SP-019 | Empty pane view | Implemented | Missing |
| REQ-SP-020 | Tmux pane layout overlay | Implemented | Partial |

### workspaces

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-WS-001 | Workspace identity and observable state | Implemented | Covered |
| REQ-WS-002 | Panel collection management | Implemented | Partial |
| REQ-WS-003 | Focused panel tracking | Implemented | Partial |
| REQ-WS-004 | Terminal surface creation | Implemented | Covered |
| REQ-WS-005 | Browser surface creation | Implemented | Partial |
| REQ-WS-006 | Panel close | Implemented | Partial |
| REQ-WS-007 | Split creation from panel | Implemented | Partial |
| REQ-WS-008 | Surface reordering within pane | Implemented | Partial |
| REQ-WS-009 | Surface navigation (next/previous/index/last) | Implemented | Partial |
| REQ-WS-010 | Custom workspace title | Implemented | Partial |
| REQ-WS-011 | Custom workspace color | Implemented | Partial |
| REQ-WS-012 | Workspace pinning | Implemented | Partial |
| REQ-WS-013 | Panel pinning | Implemented | Partial |
| REQ-WS-014 | Manual unread marking | Implemented | Covered |
| REQ-WS-015 | Unread indicator display logic | Implemented | Partial |
| REQ-WS-016 | Session snapshot and restore | Implemented | Covered |
| REQ-WS-017 | Session layout snapshot (split tree) | Implemented | Covered |
| REQ-WS-018 | Session panel snapshot by type | Implemented | Covered |
| REQ-WS-019 | Terminal scrollback persistence | Implemented | Partial |
| REQ-WS-020 | Remote workspace configuration | Implemented | Covered |
| REQ-WS-021 | Remote daemon manifest | Implemented | Partial |
| REQ-WS-022 | Sidebar metadata (status entries, log, progress, git) | Implemented | Partial |
| REQ-WS-023 | Panel-level git branch and PR tracking | Implemented | Covered |
| REQ-WS-024 | Listening ports tracking | Implemented | Partial |
| REQ-WS-025 | Workspace attention flash | Implemented | Partial |
| REQ-WS-026 | Tmux layout snapshot | Implemented | Partial |
| REQ-WS-027 | Workspace presentation mode | Implemented | Partial |
| REQ-WS-028 | Sidebar detail visibility settings | Implemented | Partial |
| REQ-WS-029 | Sidebar active tab indicator style | Implemented | Missing |
| REQ-WS-030 | Sidebar branch layout | Implemented | Partial |
| REQ-WS-031 | Workspace tab color palette | Implemented | Missing |
| REQ-WS-032 | Font size inheritance across panels | Implemented | Partial |
| REQ-WS-033 | Ghostty chrome synchronization | Implemented | Partial |

### browser-panels

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-BP-001 | Web content rendering via WKWebView | Implemented | Covered |
| REQ-BP-002 | Smart navigation (omnibar) | Implemented | Covered |
| REQ-BP-003 | Back/forward navigation | Implemented | Covered |
| REQ-BP-004 | Popup window support | Implemented | Covered |
| REQ-BP-005 | Insecure HTTP protection | Implemented | Covered |
| REQ-BP-006 | External URL scheme handling | Implemented | Partial |
| REQ-BP-007 | Browser profiles | Implemented | Covered |
| REQ-BP-008 | Custom user agent | Implemented | Partial |
| REQ-BP-009 | JavaScript dialog support | Implemented | Partial |
| REQ-BP-010 | File download support | Implemented | Partial |
| REQ-BP-011 | Theme integration | Implemented | Covered |
| REQ-BP-012 | Developer tools | Implemented | Covered |
| REQ-BP-013 | Context menu enhancements | Implemented | Partial |
| REQ-BP-014 | Remote loopback proxy | Implemented | Partial |
| REQ-BP-015 | Browser import hints | Implemented | Partial |
| REQ-BP-016 | Telemetry hooks (console/error capture) | Implemented | Partial |
| REQ-BP-017 | Key equivalent routing | Implemented | Covered |
| REQ-BP-018 | Focus management | Implemented | Covered |
| REQ-BP-019 | Media capture permissions | Implemented | Partial |

### session-persistence

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-SPE-001 | Snapshot schema versioning | Implemented | Covered |
| REQ-SPE-002 | Full application state capture | Implemented | Covered |
| REQ-SPE-003 | Workspace state capture | Implemented | Covered |
| REQ-SPE-004 | Panel type polymorphism | Implemented | Covered |
| REQ-SPE-005 | Recursive split layout persistence | Implemented | Covered |
| REQ-SPE-006 | Periodic autosave | Implemented | Covered |
| REQ-SPE-007 | Scrollback truncation and ANSI safety | Implemented | Covered |
| REQ-SPE-008 | Scrollback replay via temp files | Implemented | Partial |
| REQ-SPE-009 | Restore policy and guard conditions | Implemented | Covered |
| REQ-SPE-010 | Bundle-identifier-scoped storage | Implemented | Partial |
| REQ-SPE-011 | Sidebar state persistence | Implemented | Partial |
| REQ-SPE-012 | Display topology awareness | Implemented | Partial |
| REQ-SPE-013 | Resource limits | Implemented | Partial |
| REQ-SPE-014 | Atomic file writes | Implemented | Covered |

### notifications

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-NT-001 | Notification model | Implemented | Covered |
| REQ-NT-002 | In-app notification store | Implemented | Covered |
| REQ-NT-003 | Add notification with deduplication | Implemented | Covered |
| REQ-NT-004 | Read/unread state management | Implemented | Covered |
| REQ-NT-005 | Notification removal | Implemented | Covered |
| REQ-NT-006 | System notification delivery | Implemented | Partial |
| REQ-NT-007 | Notification sound configuration | Implemented | Partial |
| REQ-NT-008 | Dock badge | Implemented | Covered |
| REQ-NT-009 | Focused read indicator | Implemented | Covered |
| REQ-NT-010 | Notification authorization management | Implemented | Partial |
| REQ-NT-011 | Off-main-thread removal | Implemented | Partial |
| REQ-NT-012 | Notifications page UI | Implemented | Partial |
| REQ-NT-013 | Jump to unread | Implemented | Covered |
| REQ-NT-014 | Clear all button | Implemented | Covered |
| REQ-NT-015 | Workspace auto-reorder on notification | Implemented | Partial |
| REQ-NT-016 | Suppressed notification feedback | Implemented | Covered |
| REQ-NT-017 | Pane flash on notification | Implemented | Partial |

### socket-control

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-SC-001 | Access control modes | Implemented | Covered |
| REQ-SC-002 | Socket file permissions | Implemented | Covered |
| REQ-SC-003 | Password storage (file-based) | Implemented | Covered |
| REQ-SC-004 | Password resolution priority | Implemented | Covered |
| REQ-SC-005 | Legacy keychain migration | Implemented | Partial |
| REQ-SC-006 | Lazy keychain fallback cache | Implemented | Covered |
| REQ-SC-007 | Socket path resolution | Implemented | Covered |
| REQ-SC-008 | Tagged debug socket isolation | Implemented | Covered |
| REQ-SC-009 | User-scoped stable socket path | Implemented | Partial |
| REQ-SC-010 | Last socket path recording | Implemented | Partial |
| REQ-SC-011 | Environment variable overrides | Implemented | Covered |
| REQ-SC-012 | Mode parsing with legacy migration | Implemented | Covered |
| REQ-SC-013 | Socket path override honoring | Implemented | Partial |
| REQ-SC-014 | Untagged debug launch blocking | Implemented | Partial |
| REQ-SC-015 | CLI tool structure | Implemented | Partial |
| REQ-SC-016 | Socket path stability probing | Implemented | Partial |

### update-system

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-US-001 | Automatic Update Checks on Launch | Implemented | Partial |
| REQ-US-002 | Manual Update Check via Menu | Implemented | Covered |
| REQ-US-003 | Update State Machine | Implemented | Covered |
| REQ-US-004 | Sidebar Update Pill | Implemented | Covered |
| REQ-US-005 | Update Popover Details | Implemented | Partial |
| REQ-US-006 | Background Update Detection | Implemented | Covered |
| REQ-US-007 | Release Notes Links | Implemented | Missing |
| REQ-US-008 | Auto-Confirm Install Flow | Implemented | Partial |
| REQ-US-009 | No-Update Auto-Dismiss | Implemented | Covered |
| REQ-US-010 | Minimum Check Display Duration | Implemented | Partial |
| REQ-US-011 | Check Timeout | Implemented | Missing |
| REQ-US-012 | Update Log Store | Implemented | Partial |
| REQ-US-013 | User-Facing Error Messages | Implemented | Covered |
| REQ-US-014 | Feed URL Resolution | Implemented | Missing |
| REQ-US-015 | Sparkle Permission Suppression | Implemented | Partial |
| REQ-US-016 | Settings Migration | Implemented | Missing |
| REQ-US-017 | Session Persistence Before Relaunch | Implemented | Partial |
| REQ-US-018 | Sparkle Installation Cache Management | Implemented | Missing |
| REQ-US-019 | Localized Update Strings | Implemented | Partial |
| REQ-US-020 | Test Support Infrastructure | Implemented | Partial |
| REQ-US-021 | Auto-Install on Quit | Implemented | Partial |

### configuration

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-CF-001 | Ghostty Config File Loading | Implemented | Covered |
| REQ-CF-002 | Ghostty Config Key-Value Parsing | Implemented | Covered |
| REQ-CF-003 | Theme Resolution with Light/Dark Mode | Implemented | Covered |
| REQ-CF-004 | Theme File Search Paths | Implemented | Covered |
| REQ-CF-005 | Theme Name Candidates with Builtin Stripping | Implemented | Covered |
| REQ-CF-006 | Config Cache by Color Scheme | Implemented | Partial |
| REQ-CF-007 | Sidebar Background from Config | Implemented | Partial |
| REQ-CF-008 | cmux.json Command Definitions | Implemented | Covered |
| REQ-CF-009 | Workspace Definitions in cmux.json | Implemented | Covered |
| REQ-CF-010 | Surface Definitions | Implemented | Covered |
| REQ-CF-011 | Shell Command Definitions | Implemented | Missing |
| REQ-CF-012 | Command Confirmation Dialog | Implemented | Partial |
| REQ-CF-013 | Directory Trust System | Implemented | Missing |
| REQ-CF-014 | Local/Global Config Precedence | Implemented | Missing |
| REQ-CF-015 | Config File Watching | Implemented | Missing |
| REQ-CF-016 | CWD Resolution | Implemented | Covered |
| REQ-CF-017 | Workspace Restart Behavior | Implemented | Partial |
| REQ-CF-018 | Config Validation on Decode | Implemented | Covered |
| REQ-CF-019 | Split Position Clamping | Implemented | Covered |
| REQ-CF-020 | Debug Bundle Config Path Resolution | Implemented | Partial |
| REQ-CF-021 | Directory Tracking via Tab Selection | Implemented | Missing |
| REQ-CF-022 | Command Source Path Tracking | Implemented | Partial |

### keyboard-shortcuts

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-KS-001 | Action Registry | Implemented | Covered |
| REQ-KS-002 | Supported Actions | Implemented | Covered |
| REQ-KS-003 | Default Shortcut Definitions | Implemented | Covered |
| REQ-KS-004 | UserDefaults Persistence | Implemented | Partial |
| REQ-KS-005 | Shortcut Change Notifications | Implemented | Missing |
| REQ-KS-006 | Reset Individual and All Shortcuts | Implemented | Covered |
| REQ-KS-007 | StoredShortcut Data Model | Implemented | Partial |
| REQ-KS-008 | Key Display Formatting | Implemented | Missing |
| REQ-KS-009 | Numbered Digit Matching | Implemented | Missing |
| REQ-KS-010 | Shortcut Recorder Widget | Implemented | Partial |
| REQ-KS-011 | Event-to-StoredShortcut Conversion | Implemented | Missing |
| REQ-KS-012 | Keyboard Layout Character Resolution | Implemented | Covered |
| REQ-KS-013 | Normalized Characters for Event Matching | Implemented | Covered |
| REQ-KS-014 | Command-Aware Layout Support | Implemented | Partial |
| REQ-KS-015 | AppDelegate Shortcut Routing | Implemented | Covered |
| REQ-KS-016 | Event Window Context for Multi-Window | Implemented | Covered |
| REQ-KS-017 | Full-Screen Toggle Shortcut | Implemented | Covered |
| REQ-KS-018 | Split Shortcut Transient Focus Guard | Implemented | Covered |
| REQ-KS-019 | Menu Key Equivalent Synchronization | Implemented | Partial |
| REQ-KS-020 | Backwards-Compatible API | Implemented | Partial |
| REQ-KS-021 | Debug Input Source Override | Implemented | Covered |

### search-find

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-SF-001 | Terminal Find Overlay | Implemented | Missing |
| REQ-SF-002 | Terminal Find Text Field | Implemented | Missing |
| REQ-SF-003 | Terminal Find Navigation | Implemented | Missing |
| REQ-SF-004 | Terminal Find Match Count Display | Implemented | Missing |
| REQ-SF-005 | Terminal Find Escape Behavior | Implemented | Missing |
| REQ-SF-006 | Terminal Find Focus Management | Implemented | Missing |
| REQ-SF-007 | Terminal Find Overlay Corner Snapping | Implemented | Missing |
| REQ-SF-008 | Terminal Find IME Compatibility | Implemented | Missing |
| REQ-SF-009 | Browser Find Overlay | Implemented | Missing |
| REQ-SF-010 | Browser Find JavaScript Engine | Implemented | Partial |
| REQ-SF-011 | Browser Find Navigation Scripts | Implemented | Missing |
| REQ-SF-012 | Browser Find Clear Script | Implemented | Missing |
| REQ-SF-013 | Browser Find JavaScript String Escaping | Implemented | Covered |
| REQ-SF-014 | Browser Find Visibility Filtering | Implemented | Missing |
| REQ-SF-015 | Browser Find Escape Behavior | Implemented | Missing |
| REQ-SF-016 | Browser Find Focus Management | Implemented | Missing |
| REQ-SF-017 | Browser Find Overlay Corner Snapping | Implemented | Missing |
| REQ-SF-018 | Shared Search Button Style | Implemented | Missing |
| REQ-SF-019 | Accessibility Identifiers | Implemented | Partial |
| REQ-SF-020 | Browser Find Empty Query Handling | Implemented | Covered |
| REQ-SF-021 | Browser Find Match Count Display | Implemented | Partial |

### remote-daemon

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-RD-001 | JSON-RPC Server Over Stdio | Implemented | Covered |
| REQ-RD-002 | Hello Handshake | Implemented | Covered |
| REQ-RD-003 | Proxy Stream Open/Close/Write | Implemented | Covered |
| REQ-RD-004 | Proxy Stream Subscribe (Push Events) | Implemented | Covered |
| REQ-RD-005 | Session Resize Coordinator | Implemented | Covered |
| REQ-RD-006 | Session Size Persistence on Last Detach | Implemented | Covered |
| REQ-RD-007 | CLI Relay (Busybox Mode) | Implemented | Covered |
| REQ-RD-008 | Relay Authentication | Implemented | Covered |
| REQ-RD-009 | Socket Address Discovery | Implemented | Covered |
| REQ-RD-010 | Environment Variable Fallbacks | Implemented | Covered |
| REQ-RD-011 | Oversized Frame Protection | Implemented | Covered |
| REQ-RD-012 | Artifact Trust and Versioning | Implemented | Partial |
| REQ-RD-013 | Browser Subcommand Relay | Implemented | Covered |
| REQ-RD-014 | Raw RPC Passthrough | Implemented | Covered |

### ssh-detection

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-SSH-001 | Foreground SSH Process Detection | Implemented | Covered |
| REQ-SSH-002 | SSH Command-Line Parsing | Implemented | Covered |
| REQ-SSH-003 | SSH Option Key Extraction and Filtering | Implemented | Covered |
| REQ-SSH-004 | Login Name Resolution | Implemented | Covered |
| REQ-SSH-005 | SCP File Upload to Remote | Implemented | Covered |
| REQ-SSH-006 | IPv6 Literal Bracketing for SCP | Implemented | Covered |
| REQ-SSH-007 | Process Argument Introspection via sysctl | Implemented | Missing |
| REQ-SSH-008 | Zsh Bootstrap for Remote Sessions | Implemented | Covered |

### window-management

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-WM-001 | Window Accessor (SwiftUI-to-NSWindow Bridge) | Implemented | Covered |
| REQ-WM-002 | Window Decorations Controller | Implemented | Missing |
| REQ-WM-003 | Window Toolbar Controller | Implemented | Missing |
| REQ-WM-004 | Titlebar Drag Handle | Implemented | Covered |
| REQ-WM-005 | Titlebar Double-Click Action | Implemented | Covered |
| REQ-WM-006 | Window Drag Suppression | Implemented | Covered |
| REQ-WM-007 | Re-entrancy Guard for Hit Testing | Implemented | Covered |
| REQ-WM-008 | Terminal Window Portal (AppKit Hosting) | Implemented | Covered |
| REQ-WM-009 | Browser Window Portal (WebView Hosting) | Implemented | Missing |
| REQ-WM-010 | Temporary Window Movability | Implemented | Covered |

### sidebar

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-SB-001 | Sidebar Selection State | Implemented | Missing |
| REQ-SB-002 | Sidebar Width Policy | Implemented | Covered |
| REQ-SB-003 | Sidebar Active Foreground Color | Implemented | Covered |
| REQ-SB-004 | Sidebar Branch Layout Settings | Implemented | Covered |
| REQ-SB-005 | Sidebar Panel Ordering | Implemented | Covered |
| REQ-SB-006 | Sidebar Resize Interaction | Implemented | Partial |
| REQ-SB-007 | Sidebar Help Menu | Implemented | Partial |

### applescript

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-AS-001 | Scriptable Object Model | Implemented | Missing |
| REQ-AS-002 | Window Commands | Implemented | Missing |
| REQ-AS-003 | Tab (Workspace) Commands | Implemented | Missing |
| REQ-AS-004 | Terminal Commands | Implemented | Missing |
| REQ-AS-005 | Perform Action Command | Implemented | Missing |
| REQ-AS-006 | Input Text Command | Implemented | Missing |
| REQ-AS-007 | AppleScript Enable/Disable Gate | Implemented | Missing |
| REQ-AS-008 | Scripting Dictionary (SDEF) | Implemented | Missing |
| REQ-AS-009 | Terminal Enumeration Order | Implemented | Missing |
| REQ-AS-010 | Working Directory from Panel Directories | Implemented | Missing |
| REQ-AS-011 | Localized Error Messages | Implemented | Missing |

### port-scanning

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-PS-001 | TTY Registration and Unregistration | Implemented | Missing |
| REQ-PS-002 | Kick-Coalesce-Burst Scanning | Implemented | Missing |
| REQ-PS-003 | Batched Process Scan | Implemented | Missing |
| REQ-PS-004 | Batched Port Detection via lsof | Implemented | Missing |
| REQ-PS-005 | Per-Panel Port Delivery | Implemented | Missing |
| REQ-PS-006 | Singleton Scanner | Implemented | Missing |
| REQ-PS-007 | Thread Safety | Implemented | Missing |
| REQ-PS-008 | Empty Scan Clears Ports | Implemented | Missing |

### analytics

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-AN-001 | PostHog Daily Active Tracking | Implemented | Missing |
| REQ-AN-002 | PostHog Hourly Active Tracking | Implemented | Missing |
| REQ-AN-003 | Combined Active Tracking | Implemented | Missing |
| REQ-AN-004 | Active Check Timer | Implemented | Missing |
| REQ-AN-005 | Super Properties | Implemented | Missing |
| REQ-AN-006 | Telemetry Consent Gate | Implemented | Missing |
| REQ-AN-007 | Debug Build Isolation | Implemented | Missing |
| REQ-AN-008 | Anonymous Distinct ID | Implemented | Missing |
| REQ-AN-009 | Sentry Breadcrumbs | Implemented | Missing |
| REQ-AN-010 | Sentry Warning and Error Capture | Implemented | Missing |
| REQ-AN-011 | Thread Safety | Implemented | Missing |
| REQ-AN-012 | Public API Key Embedding | Implemented | Missing |

### localization

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-L10N-001 | All UI strings use localized API | Implemented | Missing |
| REQ-L10N-002 | String catalog as single source of truth | Implemented | Missing |
| REQ-L10N-003 | Info.plist string localization | Implemented | Missing |
| REQ-L10N-004 | Japanese language support | Implemented | Missing |
| REQ-L10N-005 | Extended language support for system strings | Implemented | Missing |
| REQ-L10N-006 | README documentation translations | Implemented | Missing |
| REQ-L10N-007 | No hardcoded English in UI paths | Partial | Missing |
| REQ-L10N-008 | RTL language support | Partial | Missing |
| REQ-L10N-009 | Linux localization backend | Proposed | Not Started |
| REQ-L10N-010 | New string addition workflow | Implemented | Missing |

### cross-platform

| REQ ID | Description | Impl Status | Test Status |
|--------|-------------|-------------|-------------|
| REQ-XP-001 | Platform abstraction layer exists | Proposed | Not Started |
| REQ-XP-002 | PAL protocol definitions | Proposed | Not Started |
| REQ-XP-003 | Compile-time platform selection | Proposed | Not Started |
| REQ-XP-010 | Swift Package Manager build on Linux | Proposed | Not Started |
| REQ-XP-011 | Linux CI pipeline | Proposed | Not Started |
| REQ-XP-012 | GhosttyKit xcframework replaced on Linux | Proposed | Not Started |
| REQ-XP-013 | Bonsplit cross-platform or replacement | Proposed | Not Started |
| REQ-XP-014 | Linux packaging | Proposed | Not Started |
| REQ-XP-020 | GTK4 UI backend | Proposed | Not Started |
| REQ-XP-021 | Terminal surface rendering on Linux | Proposed | Not Started |
| REQ-XP-022 | WebKitGTK for browser panels | Proposed | Not Started |
| REQ-XP-023 | System tray and notifications on Linux | Proposed | Not Started |
| REQ-XP-024 | Keyboard shortcut handling on Linux | Proposed | Not Started |
| REQ-XP-025 | Clipboard and drag-and-drop on Linux | Proposed | Not Started |
| REQ-XP-030 | Terminal core feature parity | Proposed | Not Started |
| REQ-XP-031 | Workspace and tab management parity | Proposed | Not Started |
| REQ-XP-032 | Socket control parity | Proposed | Not Started |
| REQ-XP-033 | Session persistence parity | Proposed | Not Started |
| REQ-XP-034 | Remote daemon parity | Proposed | Not Started |
| REQ-XP-035 | Configuration file parity | Proposed | Not Started |
| REQ-XP-036 | Shell integration parity | Proposed | Not Started |
| REQ-XP-040 | AppleScript support is macOS-only | Implemented | Not Started |
| REQ-XP-041 | Sparkle update system is macOS-only | Implemented | Not Started |
| REQ-XP-042 | Finder services are macOS-only | Implemented | Not Started |
| REQ-XP-043 | Touchbar support is macOS-only | Implemented | Not Started |
| REQ-XP-050 | Input latency parity | Proposed | Not Started |
| REQ-XP-051 | Memory usage parity | Proposed | Not Started |
| REQ-XP-052 | Startup time parity | Proposed | Not Started |
| REQ-XP-060 | Wayland support | Proposed | Not Started |
| REQ-XP-061 | X11 support | Proposed | Not Started |

## Coverage Statistics

| Metric | Count | Percentage |
|--------|-------|------------|
| Total REQs | 355 | 100% |
| Implemented | 321 | 90.4% |
| Partial Implementation | 4 | 1.1% |
| Proposed / Not Started | 30 | 8.5% |
| Tests: Covered | ~120 | ~33.8% |
| Tests: Partial | ~95 | ~26.8% |
| Tests: Missing | ~110 | ~31.0% |
| Tests: Not Started | 30 | 8.5% |

## Key Gaps

1. **No tests**: applescript (11 REQs), port-scanning (8 REQs), analytics (12 REQs), localization (10 REQs)
2. **Mostly untested**: search-find terminal-side (8 REQs with Missing test status)
3. **Not started**: cross-platform (30 REQs, all Proposed)
4. **Partial implementation**: localization RTL support (REQ-L10N-008), linter enforcement (REQ-L10N-007)
