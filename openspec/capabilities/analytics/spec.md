# Analytics Specification

**Status**: EXTRACTED
**Last Updated**: 2026-03-26

## Overview

Provides opt-in product analytics via PostHog (usage metrics) and Sentry (crash reporting and breadcrumbs), gated behind a unified telemetry consent setting.

## Requirements

### REQ-AN-001: PostHog Daily Active Tracking
- **Description**: Captures a `cmux_daily_active` event at most once per UTC day. The last captured day is stored in UserDefaults (`posthog.lastActiveDayUTC`). The event includes `day_utc`, `reason`, `app_version`, and `app_build` properties. Immediately flushed after capture for delivery reliability.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-AN-002: PostHog Hourly Active Tracking
- **Description**: Captures a `cmux_hourly_active` event at most once per UTC hour. The last captured hour is stored in UserDefaults (`posthog.lastActiveHourUTC`). Properties include `hour_utc`, `reason`, `app_version`, `app_build`. Immediately flushed after capture.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-AN-003: Combined Active Tracking
- **Description**: `trackActive(reason:)` attempts both daily and hourly capture in a single call, flushing once if either event was captured. Called on app activation and by the active check timer.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-AN-004: Active Check Timer
- **Description**: A 30-minute repeating timer fires while the app is active, calling `trackActive(reason: "activeTimer")`. This ensures daily/hourly events are captured even when the app stays in the foreground across midnight or hour boundaries.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2

### REQ-AN-005: Super Properties
- **Description**: Every PostHog event is tagged with `platform: "cmuxterm"`, `app_version`, and `app_build` as super properties registered during SDK setup.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-AN-006: Telemetry Consent Gate
- **Description**: All analytics (PostHog and Sentry) check `TelemetrySettings.enabledForCurrentLaunch` before any operation. When disabled, no events are captured and no breadcrumbs are added.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-AN-007: Debug Build Isolation
- **Description**: In DEBUG builds, PostHog is only enabled when `CMUX_POSTHOG_ENABLE=1` environment variable is set, preventing pollution of production analytics during development.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-AN-008: Anonymous Distinct ID
- **Description**: PostHog SDK automatically generates and persists an anonymous distinct ID. No user-identifying information is collected.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-AN-009: Sentry Breadcrumbs
- **Description**: `sentryBreadcrumb(_:category:data:)` adds informational breadcrumbs for user-action context in crash/hang reports. Each breadcrumb has a message, category, and optional data dictionary. Only fires when telemetry is enabled.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-AN-010: Sentry Warning and Error Capture
- **Description**: `sentryCaptureWarning` and `sentryCaptureError` capture non-crash events at warning/error severity levels with category tags and optional context data. Used for diagnosing issues without a full crash.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-AN-011: Thread Safety
- **Description**: PostHog operations run on a dedicated serial work queue (`com.cmux.posthog.analytics`). The queue uses `DispatchSpecificKey` to detect re-entrant calls and avoid deadlocks. Sentry operations are thread-safe by SDK design.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-AN-012: Public API Key Embedding
- **Description**: The PostHog project API key is intentionally embedded in the binary (it is a public/write-only key). The Sentry DSN is similarly embedded. Neither key grants read access to collected data.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P2

## Scenarios

### SCENARIO-AN-001: First Launch Captures Daily and Hourly
- **Given**: Fresh app launch with telemetry enabled and no prior UserDefaults
- **When**: `trackActive(reason: "launch")` is called
- **Then**: Both `cmux_daily_active` and `cmux_hourly_active` are captured and flushed
- **Verifies**: REQ-AN-001, REQ-AN-002, REQ-AN-003
- **Status**: Missing

### SCENARIO-AN-002: Same Hour Re-Activation Skips Hourly
- **Given**: Hourly event already captured for the current UTC hour
- **When**: `trackActive(reason: "appFocus")` is called again in the same hour
- **Then**: Neither daily nor hourly event is captured (both already recorded)
- **Verifies**: REQ-AN-001, REQ-AN-002
- **Status**: Missing

### SCENARIO-AN-003: Telemetry Disabled Blocks All Events
- **Given**: `TelemetrySettings.enabledForCurrentLaunch` is false
- **When**: `trackActive` or `sentryBreadcrumb` is called
- **Then**: No PostHog events are captured and no Sentry breadcrumbs are added
- **Verifies**: REQ-AN-006
- **Status**: Missing

### SCENARIO-AN-004: Debug Build Without Env Var
- **Given**: A DEBUG build without `CMUX_POSTHOG_ENABLE=1`
- **When**: `startIfNeeded()` is called
- **Then**: PostHog SDK is not initialized; `isEnabled` returns false
- **Verifies**: REQ-AN-007
- **Status**: Missing

### SCENARIO-AN-005: Active Timer Fires After 30 Minutes
- **Given**: The app has been in the foreground for 31 minutes
- **When**: The timer fires
- **Then**: `trackActive(reason: "activeTimer")` is called if the app is still active
- **Verifies**: REQ-AN-004
- **Status**: Missing

### SCENARIO-AN-006: Sentry Breadcrumb with Data
- **Given**: Telemetry is enabled
- **When**: `sentryBreadcrumb("tab.select", category: "ui", data: ["tab_id": "abc"])` is called
- **Then**: A Sentry breadcrumb is recorded with message, category, and data
- **Verifies**: REQ-AN-009
- **Status**: Missing

### SCENARIO-AN-007: Super Properties Include Version
- **Given**: A bundle with CFBundleShortVersionString "0.16.0" and CFBundleVersion "42"
- **When**: `superProperties(infoDictionary:)` is called
- **Then**: Returns `["platform": "cmuxterm", "app_version": "0.16.0", "app_build": "42"]`
- **Verifies**: REQ-AN-005
- **Status**: Missing

## Cross-Platform Notes

- PostHog has SDKs for multiple platforms. The current implementation uses the iOS/macOS PostHog SDK. Linux would use the PostHog HTTP API or a Go/Python SDK.
- Sentry has cross-platform SDKs (sentry-native for C/C++, sentry-cocoa for macOS). Linux would use sentry-native.
- The telemetry consent gate (`TelemetrySettings.enabledForCurrentLaunch`) is a platform-independent concept that should be shared.
- The work queue pattern for thread safety can be replicated on any platform with threading primitives.
- Debug isolation logic would need platform-specific environment variable or build configuration checks.

## Implementation Status

| Requirement | Status | Test Coverage |
|-------------|--------|--------------|
| REQ-AN-001 | Implemented | No automated tests |
| REQ-AN-002 | Implemented | No automated tests |
| REQ-AN-003 | Implemented | No automated tests |
| REQ-AN-004 | Implemented | No automated tests |
| REQ-AN-005 | Implemented | No automated tests |
| REQ-AN-006 | Implemented | No automated tests |
| REQ-AN-007 | Implemented | No automated tests |
| REQ-AN-008 | Implemented | No automated tests |
| REQ-AN-009 | Implemented | No automated tests |
| REQ-AN-010 | Implemented | No automated tests |
| REQ-AN-011 | Implemented | No automated tests |
| REQ-AN-012 | Implemented | No automated tests |
