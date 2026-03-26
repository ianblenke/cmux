# Port Scanning Design

**Last Updated**: 2026-03-26

## Architecture

The port scanner uses a kick-coalesce-burst pattern to efficiently detect TCP listening ports across all terminal panels with minimal process spawning overhead.

Instead of each shell running its own `ps + lsof` scan, panels send lightweight `report_tty` + `ports_kick` messages over the socket. The scanner batches all pending kicks and runs a single pair of system commands covering every active TTY.

## Key Components

### PortScanner (singleton)
- `@unchecked Sendable` for cross-queue access
- All mutable state guarded by a serial `DispatchQueue(label: "com.cmux.port-scanner", qos: .utility)`
- Owns: TTY registry, pending kicks set, burst state, coalesce timer

### PanelKey
- `Hashable` struct combining `workspaceId: UUID` + `panelId: UUID`
- Used as the key for TTY registration and kick tracking

### Coalesce Timer
- 200ms `DispatchSourceTimer` that starts on the first kick when no burst is active
- When fired: snapshots pending kicks, starts burst sequence

### Burst Sequence
- 6 scans at absolute offsets: [0.5, 1.5, 3, 5, 7.5, 10] seconds from burst start
- Recursive scheduling via `queue.asyncAfter(deadline:)`
- After last scan: if new kicks arrived during burst, starts new coalesce cycle

### System Commands
- **ps**: `/bin/ps -t <tty_list> -o pid=,tty=` - targeted scan, much cheaper than `-ax`
- **lsof**: `/usr/sbin/lsof -nP -a -p <pids> -iTCP -sTCP:LISTEN -Fpn` - machine-readable output format

### Result Joining
- PID->TTY (from ps) + PID->ports (from lsof) -> TTY->ports
- TTY->ports mapped to per-panel port lists via the TTY registry
- Delivered to `onPortsUpdated` callback on `@MainActor`

## Platform Abstraction

| Component | macOS (current) | Linux (planned) |
|-----------|----------------|-----------------|
| Process listing | `/bin/ps -t <ttys>` | `/bin/ps -t <ttys>` or `/proc` enumeration |
| Port detection | `/usr/sbin/lsof -Fpn` | `ss -tlnp` or `/proc/net/tcp` |
| Timer/queue | GCD DispatchSourceTimer | GCD or platform timer |
| Callback delivery | Task { @MainActor } | Main thread dispatch |

The core pattern (kick -> coalesce -> burst -> batch scan -> deliver) is platform-independent.

## Data Flow

```
Shell sends report_tty via socket
  -> PortScanner.registerTTY(workspaceId, panelId, ttyName)

Shell sends ports_kick via socket
  -> PortScanner.kick(workspaceId, panelId)
    -> pendingKicks.insert(key)
    -> if !burstActive: startCoalesce() [200ms timer]

Coalesce timer fires
  -> burstActive = true
  -> runBurst(index: 0)
    -> runScan()
      -> ps -t tty1,tty2,...  ->  PID->TTY mapping
      -> lsof -p pid1,pid2,...  ->  PID->ports mapping
      -> Join: TTY->ports  ->  per-panel port lists
      -> deliverResults on @MainActor
    -> runBurst(index: 1) at next offset
    -> ... (6 total scans)
  -> burstActive = false
  -> if pendingKicks not empty: startCoalesce() again
```

## Dependencies

- Foundation (Process, Pipe for subprocess execution)
- Dispatch (serial queue, timer source)
- No external packages
- Socket command handlers (report_tty, ports_kick) as integration points
