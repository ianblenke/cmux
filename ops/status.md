# Operational Status

**Last Updated**: 2026-03-26

## What's Working

### macOS Application
- Full terminal rendering via libghostty
- Workspace management with vertical sidebar tabs
- Horizontal and vertical split panes (Bonsplit)
- In-app browser with scriptable API (agent-browser port)
- Notification system (OSC 9/99/777, CLI notifications)
- Session persistence (layout, directories, scrollback, browser URLs)
- Socket control API (v1 text + v2 JSON-RPC)
- CLI automation
- Sparkle auto-updates (stable + nightly channels)
- Configuration from Ghostty config files
- Keyboard shortcuts (customizable)
- Search/find in terminal and browser
- Remote SSH with daemon, reconnect, browser proxying
- AppleScript integration
- Port scanning for sidebar display
- PostHog analytics + Sentry error reporting
- Localization (English, Japanese)

### Remote Daemon (Cross-Platform)
- Go daemon runs on Linux and macOS
- Cross-compiled for darwin/linux × arm64/amd64
- CLI relay with argv[0] detection
- SHA-256 artifact trust

## What's Next

### Cross-Platform (Linux) Port
- Define Platform Abstraction Layer (PAL)
- Evaluate GTK4 Swift bindings or alternative Linux UI
- Port terminal rendering (libghostty already supports Linux)
- Port or replace Bonsplit for Linux
- Replace WKWebView with WebKitGTK
- Linux build system (SPM/CMake)
- Linux distribution packaging (AppImage, Flatpak)

### Spec Backfill (In Progress)
- OpenSpec capability specifications being written for all 21 capabilities
- BMAD strategic documents created
- Traceability matrix to be completed after specs

## Known Blockers
- None currently
