# Remote Daemon Specification

**Status**: EXTRACTED
**Last Updated**: 2026-03-26

## Overview

The remote daemon (`cmuxd-remote`) is a Go binary deployed to remote hosts via SSH that provides a JSON-RPC server over stdio for proxy tunneling, session resize coordination, and CLI relay back to the local cmux app.

## Requirements

### REQ-RD-001: JSON-RPC Server Over Stdio
- **Description**: `cmuxd-remote serve --stdio` reads newline-delimited JSON-RPC requests from stdin and writes newline-delimited JSON responses/events to stdout. Supports `hello`, `ping`, and domain-specific methods.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-RD-002: Hello Handshake
- **Description**: The `hello` method returns the daemon name, version, and a list of capability strings (e.g., `session.basic`, `session.resize.min`, `proxy.http_connect`, `proxy.socks5`, `proxy.stream`, `proxy.stream.push`).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-RD-003: Proxy Stream Open/Close/Write
- **Description**: `proxy.open` dials a TCP connection to a given host:port, returning a stream_id. `proxy.write` sends base64-encoded data to the stream. `proxy.close` tears down the connection. Supports configurable connect and write timeouts.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-RD-004: Proxy Stream Subscribe (Push Events)
- **Description**: `proxy.stream.subscribe` starts a background read pump on a stream, pushing `proxy.stream.data`, `proxy.stream.eof`, and `proxy.stream.error` events over stdout as they arrive. Each event carries the stream_id and base64-encoded data.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-RD-005: Session Resize Coordinator
- **Description**: Provides `session.open`, `session.attach`, `session.resize`, `session.detach`, `session.close`, and `session.status` methods. Implements tmux-style "smallest screen wins" semantics: the effective terminal size is the minimum cols and minimum rows across all active attachments.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-RD-006: Session Size Persistence on Last Detach
- **Description**: When all attachments are removed from a session, the effective size retains the last known dimensions rather than resetting to zero, so reconnections start with a reasonable size.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-RD-007: CLI Relay (Busybox Mode)
- **Description**: When invoked as `cmux` (via symlink/wrapper), the binary auto-dispatches to the CLI relay instead of the daemon server. The CLI relay maps user commands (e.g., `ping`, `list-workspaces`, `new-workspace`, `send`, `browser open`) to v1 text or v2 JSON-RPC messages sent over a socket to the local cmux app via a reverse SSH tunnel.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-RD-008: Relay Authentication
- **Description**: TCP relay connections require HMAC-SHA256 challenge-response authentication. The relay writes auth credentials to `~/.cmux/relay/<port>.auth`. The CLI client reads these credentials and completes the handshake before sending commands.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-RD-009: Socket Address Discovery
- **Description**: The CLI relay discovers the local socket address from `CMUX_SOCKET_PATH` env var, `--socket` flag, or `~/.cmux/socket_addr` file. When using the file fallback, a single stale-address refresh is attempted if the initial connection is refused.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-RD-010: Environment Variable Fallbacks
- **Description**: CLI commands auto-populate `workspace_id` from `CMUX_WORKSPACE_ID` and `surface_id` from `CMUX_SURFACE_ID` environment variables when not explicitly provided via flags.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-RD-011: Oversized Frame Protection
- **Description**: RPC frames exceeding 4MB are rejected with an `invalid_request` error, and the server continues processing subsequent frames without crashing.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-RD-012: Artifact Trust and Versioning
- **Description**: Release and nightly builds publish `cmuxd-remote` for darwin/linux x arm64/amd64. The app embeds a manifest with SHA-256 digests and verifies them before running the remote daemon.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-RD-013: Browser Subcommand Relay
- **Description**: `cmux browser <sub>` maps browser subcommands (open, navigate, back, forward, reload, get-url) to `browser.*` v2 JSON-RPC methods. Supports positional URL arguments and workspace/surface env fallbacks.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-RD-014: Raw RPC Passthrough
- **Description**: `cmux rpc <method> [json-params]` sends an arbitrary JSON-RPC method with optional JSON params, enabling scripting of any socket API method.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P2

## Scenarios

### SCENARIO-RD-001: Hello and Ping Round-Trip
- **Given**: A stdio server is started
- **When**: `hello` and `ping` requests are sent sequentially
- **Then**: Both return `ok: true`; hello includes version and capabilities array with `proxy.stream.push`
- **Verifies**: REQ-RD-001, REQ-RD-002
- **Status**: Covered

### SCENARIO-RD-002: Invalid JSON and Unknown Method
- **Given**: A stdio server is started
- **When**: Malformed JSON and an unknown method are sent
- **Then**: First returns `invalid_request` error, second returns `method_not_found` error
- **Verifies**: REQ-RD-001
- **Status**: Covered

### SCENARIO-RD-003: Session Smallest-Wins Resize
- **Given**: A session is opened with two attachments of different sizes (120x40 and 90x30)
- **When**: `session.status` is queried
- **Then**: Effective size is 90x30 (minimum of both)
- **Verifies**: REQ-RD-005
- **Status**: Covered

### SCENARIO-RD-004: Session Detach Expands to Next Smallest
- **Given**: A session with a small (90x30) and large (200x60) attachment
- **When**: The small attachment is detached
- **Then**: Effective size expands to 200x60
- **Verifies**: REQ-RD-005
- **Status**: Covered

### SCENARIO-RD-005: Session Retains Last Known Size After All Detach
- **Given**: A session where all attachments are detached
- **When**: No attachments remain
- **Then**: Effective size retains the last known dimensions (200x60), attachment count is 0
- **Verifies**: REQ-RD-006
- **Status**: Covered

### SCENARIO-RD-006: Proxy Stream Data Round-Trip
- **Given**: A TCP echo-like server and a proxy stream opened to it
- **When**: "ping" is written and the stream is subscribed
- **Then**: A `proxy.stream.data` event arrives with base64-decoded "pong"
- **Verifies**: REQ-RD-003, REQ-RD-004
- **Status**: Covered

### SCENARIO-RD-007: Proxy Stream EOF Payload Not Duplicated
- **Given**: A connection that returns "tail" and immediately closes (EOF)
- **When**: The stream is subscribed
- **Then**: Exactly two events: `proxy.stream.data` with "tail" and `proxy.stream.eof` with empty payload
- **Verifies**: REQ-RD-004
- **Status**: Covered

### SCENARIO-RD-008: Oversized Frame Continues Serving
- **Given**: A frame exceeding 4MB followed by a valid ping
- **When**: Both are sent to the server
- **Then**: First returns `invalid_request`; second ping succeeds normally
- **Verifies**: REQ-RD-011
- **Status**: Covered

### SCENARIO-RD-009: Busybox Wrapper Dispatches to CLI
- **Given**: The binary is symlinked as `cmuxd-remote-current`
- **When**: Invoked with `--socket <path> ping`
- **Then**: The CLI relay runs and returns PONG from a mock socket
- **Verifies**: REQ-RD-007
- **Status**: Covered

### SCENARIO-RD-010: CLI Relay with HMAC Auth
- **Given**: A mock relay server with challenge-response auth
- **When**: CLI sends a command with valid relay credentials
- **Then**: Auth handshake succeeds and command is forwarded
- **Verifies**: REQ-RD-008
- **Status**: Covered

### SCENARIO-RD-011: Proxy Open Invalid Params
- **Given**: A proxy.open request with port as string type instead of integer
- **When**: Request is processed
- **Then**: Returns `invalid_params` error
- **Verifies**: REQ-RD-003
- **Status**: Covered

### SCENARIO-RD-012: Fractional Float64 Rejected for Integer Params
- **Given**: A parameter map with `port: 80.9` and `timeout_ms: 100.0`
- **When**: `getIntParam` is called
- **Then**: Fractional 80.9 is rejected; integral 100.0 is accepted as 100
- **Verifies**: REQ-RD-003
- **Status**: Covered

## Cross-Platform Notes

- The remote daemon is a standalone Go binary compiled for linux/darwin x arm64/amd64. It has no macOS-specific dependencies.
- The CLI relay connects via Unix sockets (local) or TCP (remote reverse tunnel). Both transports are cross-platform.
- The relay authentication uses HMAC-SHA256 with standard crypto libraries available on all platforms.
- Port filtering excludes ephemeral range (49152-65535) to avoid relay port leakage across workspaces.

## Implementation Status

| Requirement | Status | Test Coverage |
|-------------|--------|--------------|
| REQ-RD-001 | Implemented | main_test.go |
| REQ-RD-002 | Implemented | main_test.go |
| REQ-RD-003 | Implemented | main_test.go |
| REQ-RD-004 | Implemented | main_test.go |
| REQ-RD-005 | Implemented | main_test.go |
| REQ-RD-006 | Implemented | main_test.go |
| REQ-RD-007 | Implemented | main_test.go, cli_test.go |
| REQ-RD-008 | Implemented | cli_test.go |
| REQ-RD-009 | Implemented | cli_test.go |
| REQ-RD-010 | Implemented | cli_test.go |
| REQ-RD-011 | Implemented | main_test.go |
| REQ-RD-012 | Implemented | (CI workflow) |
| REQ-RD-013 | Implemented | cli_test.go |
| REQ-RD-014 | Implemented | cli_test.go |
