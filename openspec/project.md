# cmux Project Conventions

## Language & Frameworks

- **Primary language**: Swift 5.9+
- **macOS UI**: SwiftUI + AppKit (minimum macOS 13)
- **Linux UI**: GTK4 (planned)
- **Terminal engine**: libghostty (Zig)
- **Split panes**: Bonsplit (vendored Swift library)
- **Remote daemon**: Go
- **CLI**: Swift monolith communicating via Unix socket

## Coding Conventions

### Swift
- All user-facing strings: `String(localized: "key.name", defaultValue: "English text")`
- Platform-specific code behind `#if os(macOS)` / `#if os(Linux)` at PAL boundaries only
- No allocations in typing-latency-sensitive paths
- Socket telemetry commands parsed off-main-thread
- Custom UTTypes declared in `Resources/Info.plist`

### Go (Remote Daemon)
- Standard Go conventions
- Cross-compilation targets: `linux/darwin × arm64/amd64`
- Release builds: `zig build -Doptimize=ReleaseFast`

### Testing
- XCTest for unit tests
- XCUITest for UI automation (macOS)
- Python socket tests for CLI/API testing
- Tests must verify runtime behavior, not source code text or metadata
- Every test references REQ-* or SCENARIO-* in comments

## Git Conventions

- Regression tests use two-commit structure (failing test, then fix)
- Submodule commits pushed to remote before parent repo pointer update
- Never commit on detached HEAD in submodules

## Terminology

| Term | Meaning |
|------|---------|
| Window | Native OS window |
| Workspace | Sidebar entry within a window (historically "tab") |
| Pane | Split region inside a workspace |
| Surface | Tab within a pane (terminal or browser) |
| Panel | Internal implementation term; prefer "surface" in API |

## Socket API

- v1: Text protocol (legacy, maintained for compatibility)
- v2: JSON-RPC protocol (current, preferred)
- Commands must not steal app focus (socket focus policy)
- High-frequency telemetry processed off-main-thread
