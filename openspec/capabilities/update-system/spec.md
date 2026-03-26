# Update System Specification

**Status**: EXTRACTED
**Last Updated**: 2026-03-26

## Overview

Automatic and manual software update system built on Sparkle (macOS), providing background update detection, interactive update UI via a sidebar pill and popover, download/install lifecycle management, and detailed update logging.

## Requirements

### REQ-US-001: Automatic Update Checks on Launch
- **Description**: On app launch, the updater starts and immediately probes for updates in the background. A periodic background probe re-checks every hour so the update indicator appears even if the app has been running for a long time.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-US-002: Manual Update Check via Menu
- **Description**: Users can trigger an update check from the app menu ("Check for Updates"). The check retries up to 20 times (at 250ms intervals) if the Sparkle updater is not yet ready.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-US-003: Update State Machine
- **Description**: The update system maintains a state machine with states: idle, permissionRequest, checking, updateAvailable, notFound, error, downloading, extracting, installing. State transitions are observable via `UpdateViewModel` and drive all UI.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-US-004: Sidebar Update Pill
- **Description**: A pill-shaped badge appears in the sidebar when the update state is non-idle or a background update has been detected. The pill shows contextual text (version, progress percentage, error title) and an appropriate icon/badge for each state.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-US-005: Update Popover Details
- **Description**: Clicking the update pill opens a popover with state-specific content: checking spinner, update metadata (version, size, release date), download progress bar, extraction progress, install/restart prompt, not-found message, or error details with retry/copy-details actions.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-US-006: Background Update Detection
- **Description**: When Sparkle's delegate reports a valid update via background probing (not user-initiated), the detected version is recorded in the view model. The sidebar pill shows "Update Available: X.Y.Z" even while the main state is idle.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-US-007: Release Notes Links
- **Description**: For tagged releases, the popover shows a "View Release Notes" link to the GitHub release page. For commit-based versions, it shows a "View GitHub Commit" link. Version strings are parsed via regex for semantic versions and git hashes.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-US-008: Auto-Confirm Install Flow
- **Description**: `installUpdate()` subscribes to state changes and auto-confirms any installable state. `attemptUpdate()` checks for updates and auto-confirms if one is found, stopping on terminal failure states.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-US-009: No-Update Auto-Dismiss
- **Description**: When the "No Updates Available" state is shown, it auto-dismisses after 5 seconds (configurable via `UpdateTiming.noUpdateDisplayDuration`).
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2

### REQ-US-010: Minimum Check Display Duration
- **Description**: The "Checking for Updates" spinner is shown for at least 2 seconds (`UpdateTiming.minimumCheckDisplayDuration`) to avoid UI flicker on fast checks.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2

### REQ-US-011: Check Timeout
- **Description**: If a check does not complete within 10 seconds (`UpdateTiming.checkTimeoutDuration`), the state transitions to notFound automatically.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-US-012: Update Log Store
- **Description**: All update events are logged to `~/Library/Logs/cmux-update.log` with ISO 8601 timestamps. A 200-entry in-memory ring buffer is maintained. Log path is included in error details.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-US-013: User-Facing Error Messages
- **Description**: Network errors, Sparkle errors, and signature errors are mapped to user-friendly titles and messages. Technical details (domain, code, URL, feed URL) are shown in a copyable details section.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-US-014: Feed URL Resolution
- **Description**: The update feed URL is read from Info.plist (`SUFeedURL`). If missing, falls back to the GitHub releases appcast URL. Nightly builds are detected by URL path containing "/nightly/".
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-US-015: Sparkle Permission Suppression
- **Description**: Sparkle's built-in permission dialog is never shown. The driver auto-allows update permission checks with automatic checks enabled and system profile sending disabled.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-US-016: Settings Migration
- **Description**: On first run after migration, the updater repairs older installs that may have ended up with automatic checks disabled. The scheduled check interval is migrated from 24h to 1h.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-US-017: Session Persistence Before Relaunch
- **Description**: Before the updater relaunches the app, the current session is persisted, the terminal controller is stopped, and all windows invalidate their restorable state.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-US-018: Sparkle Installation Cache Management
- **Description**: Before each update check, the system ensures the Sparkle installation cache directory exists at the correct path with proper permissions (0o700). If a file exists where the directory should be, it is removed.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-US-019: Localized Update Strings
- **Description**: All user-facing update UI strings use `String(localized:defaultValue:)` for localization support.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-US-020: Test Support Infrastructure
- **Description**: DEBUG builds support environment variables for UI testing: `CMUX_UI_TEST_MODE`, `CMUX_UI_TEST_UPDATE_STATE`, `CMUX_UI_TEST_UPDATE_VERSION`, `CMUX_UI_TEST_DETECTED_UPDATE_VERSION`, `CMUX_UI_TEST_FEED_URL`, `CMUX_UI_TEST_FEED_MODE`. A custom URL protocol (`UpdateTestURLProtocol`) serves mock appcast feeds.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2

### REQ-US-021: Auto-Install on Quit
- **Description**: When Sparkle reports an update ready to install on quit (automatic download enabled), the view model transitions to installing state with `isAutoUpdate=true`, showing "Restart to Complete Update" in the pill.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

## Scenarios

### SCENARIO-US-001: User Manually Checks for Updates - Update Available
- **Given**: The app is running and idle
- **When**: User selects "Check for Updates" from the menu
- **Then**: Pill shows "Checking for Updates..." for at least 2 seconds, then transitions to "Update Available: X.Y.Z" with install/skip/later buttons in the popover
- **Verifies**: REQ-US-002, REQ-US-003, REQ-US-010
- **Status**: Covered

### SCENARIO-US-002: User Manually Checks - No Update Available
- **Given**: The app is running the latest version
- **When**: User selects "Check for Updates"
- **Then**: Pill shows "No Updates Available" for 5 seconds, then auto-dismisses back to idle
- **Verifies**: REQ-US-002, REQ-US-009
- **Status**: Covered

### SCENARIO-US-003: Background Update Detection
- **Given**: The app just launched with automatic checks enabled
- **When**: A new version is published to the appcast feed
- **Then**: The sidebar pill appears showing "Update Available: X.Y.Z" without user interaction
- **Verifies**: REQ-US-001, REQ-US-006
- **Status**: Covered (UI test)

### SCENARIO-US-004: Install and Relaunch Flow
- **Given**: An update is available and the user clicks "Install and Relaunch"
- **When**: The download completes and extraction finishes
- **Then**: The app persists the session, transitions to installing state, and relaunches
- **Verifies**: REQ-US-008, REQ-US-017
- **Status**: Partial (manual verification required for relaunch)

### SCENARIO-US-005: Network Error During Update Check
- **Given**: The device has no internet connection
- **When**: User triggers an update check
- **Then**: The pill shows an orange error state with "No Internet Connection" title and a "Retry" button. Technical details are copyable.
- **Verifies**: REQ-US-013
- **Status**: Covered (UI test with mock feed)

### SCENARIO-US-006: Check Times Out
- **Given**: The update server does not respond
- **When**: 10 seconds elapse after starting a check
- **Then**: The state transitions to notFound automatically
- **Verifies**: REQ-US-011
- **Status**: Missing (no automated test)

### SCENARIO-US-007: Feed URL Falls Back to GitHub
- **Given**: Info.plist has no SUFeedURL entry
- **When**: The updater resolves the feed URL
- **Then**: The fallback URL `https://github.com/manaflow-ai/cmux/releases/latest/download/appcast.xml` is used
- **Verifies**: REQ-US-014
- **Status**: Missing (logic is inline, no isolated test)

### SCENARIO-US-008: Settings Migration from 24h to 1h Interval
- **Given**: An older install has the 24h check interval
- **When**: The migration runs on launch
- **Then**: The interval is updated to 1h and automatic checks are re-enabled
- **Verifies**: REQ-US-016
- **Status**: Missing (no automated test)

### SCENARIO-US-009: Release Notes Link for Tagged Version
- **Given**: The update version string is "0.16.0"
- **When**: The popover is displayed
- **Then**: A "View Release Notes" link points to `https://github.com/manaflow-ai/cmux/releases/tag/v0.16.0`
- **Verifies**: REQ-US-007
- **Status**: Missing (no automated test for URL construction)

### SCENARIO-US-010: Release Notes Link for Commit Version
- **Given**: The update version string contains a git hash "abc1234"
- **When**: The popover is displayed
- **Then**: A "View GitHub Commit" link points to `https://github.com/manaflow-ai/cmux/commit/abc1234`
- **Verifies**: REQ-US-007
- **Status**: Missing

### SCENARIO-US-011: Update Pill Visibility for Detected Background Update
- **Given**: A background probe detects version 9.9.9
- **When**: The pill is rendered
- **Then**: The pill shows "Update Available: 9.9.9" with accent color background
- **Verifies**: REQ-US-004, REQ-US-006
- **Status**: Covered (UI test: `testDetectedBackgroundUpdateShowsPillWithoutManualCheck`)

### SCENARIO-US-012: Download Progress Display
- **Given**: An update is being downloaded with known content length
- **When**: Data is received
- **Then**: The pill shows "Downloading: XX%" and the popover shows a progress bar
- **Verifies**: REQ-US-004, REQ-US-005
- **Status**: Missing (no automated test for progress rendering)

### SCENARIO-US-013: Sparkle Cache Directory Repair
- **Given**: A file exists where the Sparkle installation cache directory should be
- **When**: The updater starts
- **Then**: The file is removed and the directory is created with 0o700 permissions
- **Verifies**: REQ-US-018
- **Status**: Missing

## Cross-Platform Notes

The update system is currently macOS-only, built on the Sparkle framework (macOS native). For Linux cross-platform support, a different update mechanism would be needed (e.g., checking a GitHub releases API endpoint, or package manager integration for distro packages). The `UpdateViewModel` state machine and `UpdateState` enum are framework-agnostic and could be reused with a different backend.

## Implementation Status

| Component | File | Status |
|-----------|------|--------|
| UpdateController | Sources/Update/UpdateController.swift | Complete |
| UpdateDriver (SPUUserDriver) | Sources/Update/UpdateDriver.swift | Complete |
| UpdateDelegate (SPUUpdaterDelegate) | Sources/Update/UpdateDelegate.swift | Complete |
| UpdateViewModel / UpdateState | Sources/Update/UpdateViewModel.swift | Complete |
| UpdatePill | Sources/Update/UpdatePill.swift | Complete |
| UpdateBadge | Sources/Update/UpdateBadge.swift | Complete |
| UpdatePopoverView | Sources/Update/UpdatePopoverView.swift | Complete |
| UpdateTiming | Sources/Update/UpdateTiming.swift | Complete |
| UpdateLogStore | Sources/Update/UpdateLogStore.swift | Complete |
| UpdateTitlebarAccessory | Sources/Update/UpdateTitlebarAccessory.swift | Complete |
| UpdateTestSupport | Sources/Update/UpdateTestSupport.swift | Complete (DEBUG only) |
| UpdateTestURLProtocol | Sources/Update/UpdateTestURLProtocol.swift | Complete (DEBUG only) |
