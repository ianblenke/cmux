# Known Issues

**Last Updated**: 2026-03-26

## Active Issues

### KI-001: macOS-Only Build
- **Severity**: Major
- **Description**: cmux can only be built and run on macOS. Linux support requires Platform Abstraction Layer and alternative UI framework.
- **Workaround**: Use macOS for development. Remote daemon already works on Linux.
- **Related**: REQ-XP-* (cross-platform capability)

### KI-002: Live Process State Not Restored
- **Severity**: Minor
- **Description**: Session persistence restores layout and metadata but not live processes (tmux, vim, Claude Code sessions).
- **Workaround**: Use tmux or screen inside cmux terminals for persistent sessions.
- **Related**: REQ-SPE-* (session-persistence capability)

### KI-003: Ghostty Submodule Not Initialized
- **Severity**: Blocker (for builds)
- **Description**: The ghostty submodule at `ghostty/` is registered but not initialized in this clone.
- **Workaround**: Run `git submodule update --init --recursive` or `./scripts/setup.sh`

## Resolved Issues
(none yet)
