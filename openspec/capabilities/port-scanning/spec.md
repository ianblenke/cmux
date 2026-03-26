# Port Scanning Specification

**Status**: EXTRACTED
**Last Updated**: 2026-03-26

## Overview

Batched port scanner that detects TCP listening ports across all terminal panels by coalescing per-shell scan requests into a single `ps` + `lsof` invocation, delivering per-panel port lists to the UI.

## Requirements

### REQ-PS-001: TTY Registration and Unregistration
- **Description**: Panels register their TTY name via `registerTTY(workspaceId:panelId:ttyName:)` and unregister via `unregisterPanel(workspaceId:panelId:)`. Registration is deduplicated (no-op if TTY name unchanged). Unregistration also removes pending kicks.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-PS-002: Kick-Coalesce-Burst Scanning
- **Description**: `kick(workspaceId:panelId:)` requests a scan for a panel. If no burst is active, a 200ms coalesce timer starts. When the timer fires, a burst of 6 scans runs at offsets [0.5, 1.5, 3, 5, 7.5, 10] seconds from burst start. New kicks during a burst merge into the active burst. After the last scan, if new kicks arrived, a new coalesce cycle starts.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-PS-003: Batched Process Scan
- **Description**: A single `ps -t <tty1>,<tty2>,... -o pid=,tty=` is run covering all registered TTYs (not per-panel). This produces a PID-to-TTY mapping for all processes on those TTYs.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-PS-004: Batched Port Detection via lsof
- **Description**: A single `lsof -nP -a -p <all_pids> -iTCP -sTCP:LISTEN -Fpn` is run with all PIDs from the ps scan. The output is parsed in `-F` (field) format: `p<pid>` lines for process, `n<host:port>` lines for listening addresses. Remote endpoint arrows (`->`) are stripped.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-PS-005: Per-Panel Port Delivery
- **Description**: Scan results are joined (PID->TTY + PID->ports -> TTY->ports) and delivered per-panel via the `onPortsUpdated` callback on the main actor. Each panel receives a sorted array of port numbers.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-PS-006: Singleton Scanner
- **Description**: `PortScanner.shared` is a process-wide singleton. All panels share the same scanner instance, ensuring batched scanning efficiency.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

### REQ-PS-007: Thread Safety
- **Description**: All scanner state (TTY names, pending kicks, burst state, timers) is protected by a dedicated serial `DispatchQueue`. Callbacks are delivered via `Task { @MainActor }`.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-PS-008: Empty Scan Clears Ports
- **Description**: When no processes are found on any registered TTY, all panels receive an empty port array, ensuring stale ports are cleared.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P1

## Scenarios

### SCENARIO-PS-001: Register TTY and Kick Scan
- **Given**: A panel registers its TTY name
- **When**: `kick()` is called for that panel
- **Then**: A coalesce timer starts, followed by a burst of scans that detect listening ports
- **Verifies**: REQ-PS-001, REQ-PS-002
- **Status**: Missing

### SCENARIO-PS-002: Multiple Panels Batched
- **Given**: Three panels registered on different TTYs
- **When**: All three kick within the 200ms coalesce window
- **Then**: A single `ps` + `lsof` invocation covers all three TTYs
- **Verifies**: REQ-PS-003, REQ-PS-004
- **Status**: Missing

### SCENARIO-PS-003: Panel Unregistration During Burst
- **Given**: A burst is active and a panel is unregistered
- **When**: The next scan runs
- **Then**: The unregistered panel is excluded from results
- **Verifies**: REQ-PS-001
- **Status**: Missing

### SCENARIO-PS-004: No Processes Clears Ports
- **Given**: Panels are registered but their shells have exited
- **When**: A scan runs and `ps` returns no processes
- **Then**: All panels receive empty port arrays
- **Verifies**: REQ-PS-008
- **Status**: Missing

### SCENARIO-PS-005: Burst Completes and New Kick Restarts
- **Given**: A burst of 6 scans has completed
- **When**: A new kick arrives after burst completion
- **Then**: A new coalesce timer starts and a fresh burst begins
- **Verifies**: REQ-PS-002
- **Status**: Missing

## Cross-Platform Notes

- **macOS-specific tools**: `ps` and `lsof` with macOS-specific flags. Linux `lsof` has similar flags but `/proc/net/tcp` parsing is an alternative.
- **Linux alternative**: Could use `/proc/<pid>/net/tcp6` or `ss -tlnp` for more efficient port detection.
- The coalesce-burst pattern and panel registration model are platform-independent.
- The `PortScanner` class is marked `@unchecked Sendable` for cross-queue use; this pattern works on any platform with GCD or equivalent.

## Implementation Status

| Requirement | Status | Test Coverage |
|-------------|--------|--------------|
| REQ-PS-001 | Implemented | No automated tests |
| REQ-PS-002 | Implemented | No automated tests |
| REQ-PS-003 | Implemented | No automated tests |
| REQ-PS-004 | Implemented | No automated tests |
| REQ-PS-005 | Implemented | No automated tests |
| REQ-PS-006 | Implemented | No automated tests |
| REQ-PS-007 | Implemented | No automated tests |
| REQ-PS-008 | Implemented | No automated tests |
