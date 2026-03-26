# Socket Control Design

**Last Updated**: 2026-03-26

## Architecture

Socket control is divided into two components:
1. **Server side** (`Sources/SocketControlSettings.swift`) — Configuration, mode resolution, socket path management, password store
2. **Client side** (`CLI/cmux.swift`) — CLI tool that connects to the socket and sends commands

The settings layer is purely configuration and path resolution; the actual socket listener and command dispatch are in other source files (TerminalController socket handling). This design document covers the configuration and authentication infrastructure.

## Key Components

### SocketControlMode
Five-level enum defining access policy:

```
off          → Socket not created
cmuxOnly     → Process ancestry validation (cmux-spawned only)
automation   → Same-user local access, no ancestry check
password     → Authentication required (file or env password)
allowAll     → No restrictions (0o666 permissions)
```

Default: `cmuxOnly`. The mode is persisted in UserDefaults (`socketControlMode` key).

### SocketControlSettings
Static utility enum providing:

- **Socket path resolution** — Multi-level priority: tagged debug > env override > default (bundle-scoped)
- **Environment overrides** — `CMUX_SOCKET_ENABLE`, `CMUX_SOCKET_MODE`, `CMUX_SOCKET_PATH`
- **Mode migration** — Legacy value mapping (notifications -> automation, full -> allowAll)
- **Launch safety** — Blocks untagged debug builds to prevent socket/bundle conflicts
- **Stable path management** — Records last-used socket path for CLI auto-discovery

### SocketControlPasswordStore
Static utility enum for password lifecycle:

- **Storage**: File at `~/Library/Application Support/cmux/socket-control-password`
- **Security**: File `0o600`, directory `0o700`
- **Resolution chain**: env var > file > optional keychain fallback
- **Legacy migration**: One-time Keychain -> file migration with version tracking
- **Thread safety**: NSLock-guarded cache for lazy keychain reads
- **Verification**: Constant-time comparison not yet implemented (uses `==`)

### CLISocketSentryTelemetry
Telemetry wrapper for CLI error reporting:
- Captures command, subcommand, socket path, workspace/surface IDs
- Sentry breadcrumbs for operation tracking
- Error capture with socket diagnostics
- Disabled via `CMUX_CLI_SENTRY_DISABLED=1`

## Platform Abstraction

| Component | macOS | Linux |
|-----------|-------|-------|
| Socket path default | `~/Library/Application Support/cmux/cmux.sock` | `$XDG_DATA_HOME/cmux/cmux.sock` |
| Password file | `~/Library/Application Support/cmux/socket-control-password` | `$XDG_DATA_HOME/cmux/socket-control-password` |
| Legacy socket path | `/tmp/cmux.sock` | `/tmp/cmux.sock` (same) |
| Keychain | Security framework (macOS-only) | Not available (skip fallback) |
| Bundle ID | `Bundle.main.bundleIdentifier` | Application constant |
| Executable path | `_NSGetExecutablePath` | `/proc/self/exe` readlink |
| Socket permissions | POSIX (portable) | POSIX (portable) |
| lstat probing | POSIX (portable) | POSIX (portable) |

Abstraction strategy:
1. Create `SocketPaths` protocol with `defaultSocketPath`, `passwordFilePath`, `lastSocketPathFile`
2. macOS implementation uses Application Support; Linux uses XDG paths
3. Compile out `#if canImport(Security)` blocks on Linux (already done)
4. Replace `Bundle.main.bundleIdentifier` lookups with a platform-agnostic app identity

## Data Flow

### Socket Path Resolution
```
socketPath(environment:, bundleIdentifier:, isDebugBuild:)
    |
    +--> Tagged debug? (bundle ID suffix or CMUX_TAG)
    |     +--> YES: /tmp/cmux-debug-<tag>.sock
    |     |         (with optional CMUX_SOCKET_PATH override if CMUX_ALLOW_SOCKET_OVERRIDE=1)
    |     +--> NO: continue
    |
    +--> CMUX_SOCKET_PATH set?
    |     +--> shouldHonorOverride? (debug/staging/CMUX_ALLOW_SOCKET_OVERRIDE)
    |     |     +--> YES: use override
    |     |     +--> NO: use default
    |     +--> Not set: use default
    |
    +--> defaultSocketPath()
          +--> Tagged debug bundle: /tmp/cmux-debug-<tag>.sock
          +--> Nightly bundle: /tmp/cmux-nightly.sock
          +--> Debug bundle/build: /tmp/cmux-debug.sock
          +--> Staging bundle: /tmp/cmux-staging.sock
          +--> Release: resolvedStableDefaultSocketPath()
                +--> Probe cmux.sock with lstat
                +--> Missing or owned by current user: use it
                +--> Owned by other user or non-socket: cmux-{uid}.sock
```

### Password Authentication
```
Client connects to socket
    |
    v
Server checks mode == .password?
    +--> NO: proceed (or reject based on ancestry/mode)
    +--> YES: request password from client
              |
              v
          SocketControlPasswordStore.verify(password:)
              |
              +--> configuredPassword()
              |     +--> env CMUX_SOCKET_PASSWORD? → use it
              |     +--> file password? → use it
              |     +--> lazy keychain fallback? → use cached/read
              |
              +--> Compare candidate == expected
              +--> Allow or reject
```

### Effective Mode Resolution
```
effectiveMode(userMode:, environment:)
    |
    +--> CMUX_SOCKET_ENABLE set?
    |     +--> "0/false/no/off" → return .off
    |     +--> "1/true/yes/on" →
    |           +--> CMUX_SOCKET_MODE set? → return parsed mode
    |           +--> userMode == .off? → return .cmuxOnly
    |           +--> else → return userMode
    |
    +--> CMUX_SOCKET_MODE set? → return parsed mode
    |
    +--> return userMode
```

## Dependencies

- **Foundation** — FileManager, UserDefaults, ProcessInfo, URL, Data, NSLock
- **Darwin** — getuid, lstat, stat, errno, mode_t, POSIX constants
- **Security** (macOS only) — SecItemCopyMatching, SecItemDelete for legacy keychain
- **Sentry** (optional) — CLI error telemetry
- **CryptoKit** — Imported in CLI (likely for future HMAC auth or session tokens)
- **LocalAuthentication** (macOS only) — Imported but not actively used in settings (may be for biometric auth feature)
