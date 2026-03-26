# Socket Control Specification

**Status**: EXTRACTED
**Last Updated**: 2026-03-26

## Overview

Socket control provides a Unix domain socket interface for external automation and CLI access to the cmux application. It supports five access modes with escalating trust levels, password authentication via file or environment, socket path resolution per bundle identity, and environment variable overrides for mode and path.

## Requirements

### REQ-SC-001: Access control modes
- **Description**: Five `SocketControlMode` levels: `off` (socket disabled), `cmuxOnly` (only cmux-spawned processes), `automation` (any local process from same user, no ancestry check), `password` (requires authentication), `allowAll` (any local process/user, no auth). Default is `cmuxOnly`.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SC-002: Socket file permissions
- **Description**: `allowAll` mode sets socket permissions to `0o666`. All other modes use `0o600` (owner-only).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SC-003: Password storage (file-based)
- **Description**: `SocketControlPasswordStore` manages a password file at `~/Library/Application Support/cmux/socket-control-password` with `0o600` permissions. Directory created with `0o700`. Supports save, load, clear, and verify operations. Password is newline-trimmed.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SC-004: Password resolution priority
- **Description**: Password is resolved in order: (1) `CMUX_SOCKET_PASSWORD` environment variable, (2) file-based password, (3) optional lazy keychain fallback (legacy migration). Environment always takes priority over file.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SC-005: Legacy keychain migration
- **Description**: `migrateLegacyKeychainPasswordIfNeeded` reads from macOS Keychain (`com.cmuxterm.app.socket-control` service), writes to file store, deletes keychain entry, and records migration version in UserDefaults. Migration is idempotent and retries on failure.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-SC-006: Lazy keychain fallback cache
- **Description**: When `allowLazyKeychainFallback` is true, keychain is read exactly once and cached in a thread-safe `NSLock`-guarded cache. Subsequent calls return cached value (even nil). Cache is resettable for testing.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-SC-007: Socket path resolution
- **Description**: `socketPath` resolves the socket file location through a priority chain: tagged debug path (from bundle ID suffix or `CMUX_TAG` env), env override (`CMUX_SOCKET_PATH` with `CMUX_ALLOW_SOCKET_OVERRIDE` gate), or default path. Default paths: release = `~/Library/Application Support/cmux/cmux.sock`, debug = `/tmp/cmux-debug.sock`, nightly = `/tmp/cmux-nightly.sock`, staging = `/tmp/cmux-staging.sock`.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SC-008: Tagged debug socket isolation
- **Description**: Debug builds with tagged bundle IDs (`com.cmuxterm.app.debug.<tag>`) or `CMUX_TAG` env get isolated sockets at `/tmp/cmux-debug-<tag>.sock`. Tag is slug-normalized (lowercase, dots/underscores to hyphens).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-SC-009: User-scoped stable socket path
- **Description**: When the default socket path is occupied by a different user, `resolvedStableDefaultSocketPath` falls back to `cmux-{uid}.sock` to avoid conflicts in multi-user systems.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-SC-010: Last socket path recording
- **Description**: `recordLastSocketPath` writes the active socket path to both the stable location (`~/Library/Application Support/cmux/last-socket-path`) and the legacy location (`/tmp/cmux-last-socket-path`) for CLI discovery.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-SC-011: Environment variable overrides
- **Description**: `CMUX_SOCKET_ENABLE` (1/0) overrides whether socket is active. `CMUX_SOCKET_MODE` overrides the access mode. `effectiveMode` combines user preference with env overrides: if enable=false, returns off; if enable=true with no mode override, promotes off to cmuxOnly.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SC-012: Mode parsing with legacy migration
- **Description**: `migrateMode` accepts both current values (off, cmuxOnly, automation, password, allowAll) and legacy values (notifications -> automation, full -> allowAll). Normalizes casing, hyphens, and underscores.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-SC-013: Socket path override honoring
- **Description**: `CMUX_SOCKET_PATH` is honored in debug/staging builds and when `CMUX_ALLOW_SOCKET_OVERRIDE=1`. Release builds ignore it by default for security.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-SC-014: Untagged debug launch blocking
- **Description**: `shouldBlockUntaggedDebugLaunch` prevents debug builds from launching without a tag (to avoid conflicting with other debug instances). Exempts XCTest and CMUX_UI_TEST environments.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-SC-015: CLI tool structure
- **Description**: The `cmux` CLI tool (`CLI/cmux.swift`) connects to the socket and sends commands. Includes Sentry telemetry for error tracking with breadcrumbs, socket diagnostics, and CLI command/subcommand context.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SC-016: Socket path stability probing
- **Description**: `inspectStableDefaultSocketPathEntry` uses `lstat` to check if the default socket path is missing, is a socket (with owner UID), is another file type, or is inaccessible. Used to resolve multi-user conflicts.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

## Scenarios

### SCENARIO-SC-001: Password file round-trip
- **Given**: No password file exists
- **When**: Save "hunter2", load, then clear
- **Then**: Load returns "hunter2" after save, nil after clear; `hasConfiguredPassword` reflects state
- **Verifies**: REQ-SC-003
- **Status**: Covered

### SCENARIO-SC-002: Environment password takes priority
- **Given**: File contains "stored-secret" and env has CMUX_SOCKET_PASSWORD="env-secret"
- **When**: `configuredPassword` is called
- **Then**: Returns "env-secret"
- **Verifies**: REQ-SC-004
- **Status**: Covered

### SCENARIO-SC-003: Lazy keychain fallback caches
- **Given**: No file password, no env password, keychain returns "legacy-secret"
- **When**: `configuredPassword` called twice with `allowLazyKeychainFallback: true`
- **Then**: Keychain loader invoked exactly once; second call returns cached "legacy-secret"
- **Verifies**: REQ-SC-006
- **Status**: Covered

### SCENARIO-SC-004: Lazy keychain fallback caches nil
- **Given**: No file password, no env password, keychain returns nil
- **When**: Called twice with `allowLazyKeychainFallback: true`
- **Then**: Keychain loader invoked exactly once; both calls return nil
- **Verifies**: REQ-SC-006
- **Status**: Covered

### SCENARIO-SC-005: Tagged debug socket path
- **Given**: Bundle ID is "com.cmuxterm.app.debug.my-feature"
- **When**: `socketPath` is resolved
- **Then**: Returns "/tmp/cmux-debug-my-feature.sock"
- **Verifies**: REQ-SC-008
- **Status**: Covered

### SCENARIO-SC-006: Effective mode with env override
- **Given**: User mode is `off`, env has CMUX_SOCKET_ENABLE=1
- **When**: `effectiveMode` is called
- **Then**: Returns `cmuxOnly` (promotes off when explicitly enabled)
- **Verifies**: REQ-SC-011
- **Status**: Covered

### SCENARIO-SC-007: Mode migration from legacy
- **Given**: Persisted mode string is "notifications"
- **When**: `migrateMode` is called
- **Then**: Returns `.automation`
- **Verifies**: REQ-SC-012
- **Status**: Covered

### SCENARIO-SC-008: AllowAll permissions
- **Given**: Mode is `.allowAll`
- **When**: `socketFilePermissions` is queried
- **Then**: Returns `0o666`
- **Verifies**: REQ-SC-002
- **Status**: Covered

## Cross-Platform Notes

- **Unix domain sockets** work identically on macOS and Linux. Socket path resolution logic is fully portable.
- **Keychain** (`Security` framework) is macOS-only. Linux should use file-based storage only (already the primary path). The keychain fallback and migration code should be compiled out on Linux.
- **Application Support path**: Linux should use `$XDG_DATA_HOME/cmux/` or `~/.local/share/cmux/` instead of `~/Library/Application Support/cmux/`.
- **Bundle identifier**: Linux needs an alternative identity mechanism (application name constant or config file).
- **`lstat` and POSIX permissions**: Fully portable.
- **Sentry telemetry**: Platform-independent once SDK is available.
- **`_NSGetExecutablePath`**: macOS-specific; Linux uses `/proc/self/exe`.

## Implementation Status

| Requirement | Status | Notes |
|-------------|--------|-------|
| REQ-SC-001 | Implemented | SocketControlMode enum |
| REQ-SC-002 | Implemented | socketFilePermissions |
| REQ-SC-003 | Implemented | SocketControlPasswordStore |
| REQ-SC-004 | Implemented | configuredPassword priority chain |
| REQ-SC-005 | Implemented | migrateLegacyKeychainPasswordIfNeeded |
| REQ-SC-006 | Implemented | Lazy cache with NSLock |
| REQ-SC-007 | Implemented | socketPath resolution |
| REQ-SC-008 | Implemented | taggedDebugSocketPath |
| REQ-SC-009 | Implemented | userScopedStableSocketPath |
| REQ-SC-010 | Implemented | recordLastSocketPath |
| REQ-SC-011 | Implemented | effectiveMode + env overrides |
| REQ-SC-012 | Implemented | migrateMode |
| REQ-SC-013 | Implemented | shouldHonorSocketPathOverride |
| REQ-SC-014 | Implemented | shouldBlockUntaggedDebugLaunch |
| REQ-SC-015 | Implemented | CLI/cmux.swift |
| REQ-SC-016 | Implemented | inspectStableDefaultSocketPathEntry |
