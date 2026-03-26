# Remote Daemon Design

**Last Updated**: 2026-03-26

## Architecture

The remote daemon (`cmuxd-remote`) is a single Go binary that serves two roles:

1. **Daemon mode** (`cmuxd-remote serve --stdio`): An RPC server communicating over stdin/stdout with the local cmux app via an SSH tunnel.
2. **CLI relay mode** (invoked as `cmux` via symlink): A command-line client that translates user commands into socket messages sent back to the local cmux app through a reverse SSH tunnel.

The mode is selected at startup via argv[0] detection (busybox pattern) or explicit subcommand.

## Key Components

### rpcServer
- Manages all daemon state: active proxy streams and resize sessions
- Thread-safe via `sync.Mutex`
- Handles JSON-RPC request dispatch to method handlers
- Owns the `stdioFrameWriter` for serialized output

### stdioFrameWriter
- Mutex-guarded buffered writer to stdout
- Ensures atomic JSON frame output (response or event)
- Used by both request handlers (responses) and stream pumps (push events)

### streamState / streamPump
- Each `proxy.open` creates a `streamState` holding a `net.Conn`
- `proxy.stream.subscribe` spawns a goroutine (`streamPump`) that reads from the connection and pushes `proxy.stream.data`/`proxy.stream.eof`/`proxy.stream.error` events
- Connections set TCP_NODELAY for low-latency proxying

### sessionState / recomputeSessionSize
- Session tracks named attachments, each with cols/rows
- `recomputeSessionSize` implements "smallest screen wins": effective size = min(cols), min(rows) across all attachments
- When no attachments remain, last known size is preserved

### CLI Relay (cli.go)
- Table-driven command registry mapping CLI names to v1 text or v2 JSON-RPC methods
- `dialSocket` handles both Unix socket and TCP connections
- TCP connections trigger relay authentication (HMAC-SHA256 challenge-response)
- Environment fallbacks: `CMUX_WORKSPACE_ID`, `CMUX_SURFACE_ID`, `CMUX_SOCKET_PATH`

### Relay Authentication
- Local cmux app starts a reverse SSH tunnel (`ssh -R`) to expose a relay port on the remote
- Auth state written to `~/.cmux/relay/<port>.auth` (relay_id + relay_token)
- Client reads challenge from server, computes HMAC-SHA256 over `relay_id+nonce+version`, sends MAC
- Server validates MAC before forwarding any commands

## Platform Abstraction

The remote daemon is pure Go with no platform-specific code. It compiles for:
- `linux/amd64`, `linux/arm64`
- `darwin/amd64`, `darwin/arm64`

No CGo dependencies. The binary is statically linked where possible.

## Data Flow

### Proxy Tunneling
```
Browser Panel (local) -> SOCKS5/CONNECT broker (local) -> SSH tunnel -> cmuxd-remote proxy.open/write/subscribe -> TCP connection (remote host)
```

### CLI Relay
```
User types `cmux list-workspaces` (remote shell) -> CLI parses to JSON-RPC -> TCP to reverse tunnel port -> Relay auth handshake -> Forward to local cmux socket -> Response back through tunnel -> CLI formats output
```

### Session Resize
```
Local app detects terminal resize -> session.resize RPC via SSH tunnel -> daemon recomputes min(cols,rows) -> Returns new effective size -> Local app applies SIGWINCH
```

## Dependencies

- Go standard library (no external dependencies)
- SSH transport provided by the local cmux app (not managed by the daemon)
- PostHog/Sentry not used in the daemon (telemetry is local-side only)
