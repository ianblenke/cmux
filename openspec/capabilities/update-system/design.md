# Update System Design

**Last Updated**: 2026-03-26

## Architecture

The update system follows a layered architecture:

1. **Sparkle Framework** -- Native macOS update framework providing appcast parsing, download, signature verification, extraction, and installation.
2. **UpdateController** -- Application-level orchestrator that owns the `SPUUpdater` instance, manages retry logic, background probing, and auto-install flows.
3. **UpdateDriver** -- Implements `SPUUserDriver` and `SPUUpdaterDelegate` to intercept all Sparkle callbacks and translate them into `UpdateState` transitions on the view model.
4. **UpdateViewModel** -- Observable model that holds the current `UpdateState` plus derived UI properties (text, icon, colors, badge). Published properties drive SwiftUI views.
5. **UI Layer** -- `UpdatePill` (sidebar badge), `UpdateBadge` (icon/spinner/progress ring), `UpdatePopoverView` (detailed state-specific popover content).

## Key Components

### UpdateController
- Singleton lifecycle tied to `AppDelegate`
- Owns `SPUUpdater` and `UpdateDriver`
- `startUpdaterIfNeeded()` -- idempotent start with error recovery
- `checkForUpdates()` / `checkForUpdatesWhenReady(retries:)` -- user-initiated checks with ready-wait retry loop
- `installUpdate()` -- auto-confirm subscription on state changes
- `attemptUpdate()` -- check + auto-install pipeline
- Background probe timer: fires every hour via `Timer.scheduledTimer`
- No-update auto-dismiss: observes `CombineLatest(state, overrideState)`, schedules dismiss after 5s

### UpdateDriver
- `SPUUserDriver` implementation -- translates Sparkle's show/dismiss callbacks to `UpdateState` mutations
- `SPUUpdaterDelegate` implementation -- feed URL resolution, appcast callbacks, relaunch preparation
- Minimum check display duration enforcement via `setStateAfterMinimumCheckDelay()`
- Check timeout via `scheduleCheckTimeout()` (10s)
- All state mutations run on main thread via `runOnMain()`

### UpdateViewModel / UpdateState
- `UpdateState` is an enum with associated values carrying callbacks (cancel, reply, dismiss, retry, acknowledgement)
- `effectiveState` returns `overrideState ?? state` for testing/override support
- `showsDetectedBackgroundUpdate` -- true when idle with a cached detected version
- Computed properties: `text`, `description`, `iconName`, `iconColor`, `backgroundColor`, `foregroundColor`, `badge`, `maxWidthText`
- `ReleaseNotes` nested type parses version strings into `.tagged(URL)` or `.commit(URL)`
- Error mapping: `userFacingErrorTitle(for:)` and `userFacingErrorMessage(for:)` categorize NSURLError codes and Sparkle error codes

### UpdateSettings
- Registers Sparkle defaults: automatic checks enabled, auto-download disabled, 1h check interval, no profile info
- Migration logic repairs older installs (v2 migration key)

### UpdateLogStore
- Thread-safe singleton with serial `DispatchQueue`
- 200-entry in-memory ring buffer
- Appends to `~/Library/Logs/cmux-update.log` with ISO 8601 timestamps
- `FocusLogStore` follows the same pattern for focus debugging

### UpdateFeedResolver
- Resolves feed URL from Info.plist `SUFeedURL` key
- Falls back to `https://github.com/manaflow-ai/cmux/releases/latest/download/appcast.xml`
- Detects nightly channel by URL path

## Platform Abstraction

Currently tightly coupled to macOS via:
- **Sparkle framework** (`SPUUpdater`, `SPUUserDriver`, `SPUUpdaterDelegate`, `SUAppcastItem`)
- **AppKit** (`NSPopover`, `NSHostingView`, `NSMenuItem`, `NSPasteboard`)
- **macOS file paths** (`~/Library/Logs/`, `~/Library/Caches/`)

Cross-platform strategy:
- `UpdateState` enum and `UpdateViewModel` are framework-agnostic; reusable on Linux with a different update backend
- Feed URL resolution and appcast parsing could use a custom HTTP client + XML parser
- UI layer would need GTK/Qt equivalents for the popover and pill
- Log store path would use `XDG_STATE_HOME` or `/var/log/` on Linux

## Data Flow

```
Launch
  -> UpdateController.startUpdaterIfNeeded()
    -> UpdateSettings.apply() (migrate defaults)
    -> SPUUpdater.start()
    -> startLaunchUpdateProbeIfNeeded()
      -> SPUUpdater.checkForUpdateInformation() (background probe)
        -> SPUUpdaterDelegate.updater(_:didFindValidUpdate:)
          -> UpdateViewModel.recordDetectedUpdate()
            -> UpdatePill shows "Update Available: X.Y.Z"

User clicks "Check for Updates"
  -> UpdateController.checkForUpdates()
    -> checkForUpdatesWhenReady(retries: 20)
      -> SPUUpdater.checkForUpdates()
        -> UpdateDriver.showUserInitiatedUpdateCheck()
          -> state = .checking
            -> UpdatePill shows spinner + "Checking..."
        -> UpdateDriver.showUpdateFound()
          -> state = .updateAvailable (after min 2s display)
            -> UpdatePill shows "Update Available: X.Y.Z"
            -> Popover shows version, size, date, install/skip/later

User clicks "Install and Relaunch"
  -> UpdateState.confirm() -> reply(.install)
    -> Sparkle downloads
      -> UpdateDriver.showDownloadInitiated/DidReceiveData
        -> state = .downloading (progress updates)
    -> Sparkle extracts
      -> UpdateDriver.showDownloadDidStartExtractingUpdate/showExtractionReceivedProgress
        -> state = .extracting
    -> UpdateDriver.showReady(toInstallAndRelaunch:)
      -> reply(.install) (auto-confirm)
    -> UpdateDriver.showInstallingUpdate
      -> state = .installing
    -> SPUUpdaterDelegate.updaterWillRelaunchApplication
      -> persistSessionForUpdateRelaunch()
      -> TerminalController.shared.stop()
```

## Dependencies

| Dependency | Purpose | Platform |
|------------|---------|----------|
| Sparkle (SPUUpdater, SPUUserDriver, SPUUpdaterDelegate) | Update check, download, verify, install | macOS |
| Combine (AnyCancellable, Publishers) | Reactive state observation | macOS/Linux (via OpenCombine) |
| SwiftUI | Pill, badge, popover UI | macOS (Linux via alternative) |
| AppKit (NSPopover, NSHostingView, NSMenuItem) | Native popover hosting | macOS |
| Foundation (UserDefaults, FileManager, Timer) | Settings, logging, scheduling | all |
