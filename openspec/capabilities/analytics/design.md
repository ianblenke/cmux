# Analytics Design

**Last Updated**: 2026-03-26

## Architecture

Analytics is split into two independent subsystems sharing a common telemetry consent gate:

1. **PostHog** (PostHogAnalytics): Product usage metrics (DAU/HAU counting)
2. **Sentry** (SentryHelper): Crash/hang reporting with contextual breadcrumbs

Both are opt-in via `TelemetrySettings.enabledForCurrentLaunch` and use embedded public API keys.

## Key Components

### PostHogAnalytics (singleton)
- `PostHogAnalytics.shared` manages PostHog SDK lifecycle
- Dedicated serial work queue (`com.cmux.posthog.analytics`) for all operations
- `DispatchSpecificKey` for re-entrancy detection (sync dispatch avoids deadlock)
- Lazy initialization: SDK is set up on first use via `startIfNeededOnWorkQueue()`

#### Deduplication
- Daily: UserDefaults key `posthog.lastActiveDayUTC` stores last captured UTC day string
- Hourly: UserDefaults key `posthog.lastActiveHourUTC` stores last captured UTC hour string
- Both use `DateFormatter` with explicit UTC timezone and POSIX locale

#### Events
- `cmux_daily_active`: Properties include `day_utc`, `reason`, version info
- `cmux_hourly_active`: Properties include `hour_utc`, `reason`, version info
- Super properties (registered once): `platform`, `app_version`, `app_build`

#### Timer
- 30-minute repeating `Timer` on the main run loop
- Only fires `trackActive` when `NSApp.isActive` is true
- Ensures metric capture across midnight/hour boundaries without relying on app activation events

### SentryHelper (free functions)
- `sentryBreadcrumb(_:category:data:)`: Adds info-level breadcrumb
- `sentryCaptureWarning(_:category:data:contextKey:)`: Captures warning-level message
- `sentryCaptureError(_:category:data:contextKey:)`: Captures error-level message
- All gated behind `TelemetrySettings.enabledForCurrentLaunch`
- Used throughout the codebase for UI action context (tab selection, drag events, titlebar interactions)

### TelemetrySettings
- Centralized consent check used by both PostHog and Sentry
- `enabledForCurrentLaunch` returns the telemetry opt-in state frozen at launch time

## Platform Abstraction

| Component | macOS (current) | Linux (planned) |
|-----------|----------------|-----------------|
| PostHog SDK | posthog-ios (Swift) | PostHog HTTP API or posthog-go |
| Sentry SDK | sentry-cocoa | sentry-native (C) |
| Consent storage | UserDefaults | Config file / XDG settings |
| Timer | Foundation Timer | Platform timer / event loop |
| Work queue | GCD DispatchQueue | Thread pool / async runtime |

## Data Flow

```
App Launch
  -> PostHogAnalytics.startIfNeeded()
    -> Check TelemetrySettings.enabledForCurrentLaunch
    -> Check DEBUG build isolation
    -> PostHogSDK.shared.setup(config)
    -> Register super properties
    -> Schedule 30-min active check timer

App Becomes Active / Timer Fires
  -> PostHogAnalytics.trackActive(reason:)
    -> Work queue:
      -> trackDailyActiveOnWorkQueue: check day, capture if new
      -> trackHourlyActiveOnWorkQueue: check hour, capture if new
      -> Flush if either captured

UI Interaction
  -> sentryBreadcrumb("tab.select", category: "ui", data: [...])
    -> Check TelemetrySettings
    -> SentrySDK.addBreadcrumb(...)

Error Condition
  -> sentryCaptureWarning("unexpected state", category: "workspace", data: [...])
    -> Check TelemetrySettings
    -> SentrySDK.capture(message:) with scope
```

## Dependencies

- PostHog iOS SDK (Swift package)
- Sentry Cocoa SDK (Swift package)
- Foundation (UserDefaults, DateFormatter, Timer)
- Dispatch (serial work queue)
- Bundle.main.infoDictionary (version info)
