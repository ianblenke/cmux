# SSH Detection Specification

**Status**: EXTRACTED
**Last Updated**: 2026-03-26

## Overview

Detects active foreground SSH sessions on a terminal's TTY by inspecting process state and parsing SSH command-line arguments, enabling remote workspace features like file upload via SCP and shell bootstrap customization.

## Requirements

### REQ-SSH-001: Foreground SSH Process Detection
- **Description**: Detect foreground SSH processes on a given TTY by running `ps` and filtering for processes where the executable name is `ssh` and the process group matches the terminal's foreground process group (`pgid == tpgid`).
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-SSH-002: SSH Command-Line Parsing
- **Description**: Parse SSH command-line arguments to extract destination, port (`-p`), identity file (`-i`), config file (`-F`), jump host (`-J`), control path (`-S`), login name (`-l`), IPv4/IPv6 preference (`-4`/`-6`), agent forwarding (`-A`), compression (`-C`), and arbitrary `-o` options.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-SSH-003: SSH Option Key Extraction and Filtering
- **Description**: Parse `-o Key=Value` and `-o Key Value` option formats. Extract known options (Port, IdentityFile, ControlPath, ProxyJump, User) into structured fields. Filter security-sensitive options (BatchMode, ControlMaster, ControlPersist, etc.) to prevent forwarding them to SCP/SSH subprocesses.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-SSH-004: Login Name Resolution
- **Description**: When a login name is provided via `-l` or `-o User=...` and the destination does not already contain `@`, prepend the login name as `user@destination`.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-SSH-005: SCP File Upload to Remote
- **Description**: `DetectedSSHSession.uploadDroppedFiles` uploads local files to the remote host via `scp`, constructing arguments that mirror the detected SSH session's connection parameters. Supports cancellation, timeout (45s per file), and automatic cleanup of uploaded files on failure or cancellation.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-SSH-006: IPv6 Literal Bracketing for SCP
- **Description**: When the SSH destination is a bare IPv6 literal (contains `:` but no brackets), the SCP remote destination wraps it in brackets to form valid `[host]:path` syntax.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

### REQ-SSH-007: Process Argument Introspection via sysctl
- **Description**: Read the full command-line arguments of an SSH process via `sysctl(KERN_PROCARGS2)` to access the complete argument vector including option values.
- **Platform**: macOS-only
- **Status**: Implemented
- **Priority**: P0

### REQ-SSH-008: Zsh Bootstrap for Remote Sessions
- **Description**: `RemoteRelayZshBootstrap` generates zsh dotfile content (`.zshenv`, `.zprofile`, `.zshrc`, `.zlogin`) that sources the user's real dotfiles from `$CMUX_REAL_ZDOTDIR` while redirecting `ZDOTDIR` to a cmux-managed state directory. Shared history is redirected to the real ZDOTDIR.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P1

## Scenarios

### SCENARIO-SSH-001: Detect Foreground SSH on TTY
- **Given**: An SSH process is running in the foreground of a terminal TTY
- **When**: `TerminalSSHSessionDetector.detect(forTTY:)` is called with the TTY name
- **Then**: Returns a `DetectedSSHSession` with the correct destination and connection parameters
- **Verifies**: REQ-SSH-001, REQ-SSH-002
- **Status**: Covered

### SCENARIO-SSH-002: Parse SSH with Port and Identity
- **Given**: SSH arguments `["ssh", "-p", "2222", "-i", "~/.ssh/id_ed25519", "user@host.example.com"]`
- **When**: Parsed via `detectForTesting`
- **Then**: Returns destination `user@host.example.com`, port 2222, identity file `~/.ssh/id_ed25519`
- **Verifies**: REQ-SSH-002
- **Status**: Covered

### SCENARIO-SSH-003: Parse SSH with -o Options
- **Given**: SSH arguments with `-o Port=3000 -o ProxyJump=bastion -o StrictHostKeyChecking=no`
- **When**: Parsed by the detector
- **Then**: Port, jump host, and passthrough options are correctly extracted
- **Verifies**: REQ-SSH-003
- **Status**: Covered

### SCENARIO-SSH-004: Login Name Prepended to Destination
- **Given**: SSH arguments `["ssh", "-l", "deploy", "server.example.com"]`
- **When**: Parsed by the detector
- **Then**: Destination resolves to `deploy@server.example.com`
- **Verifies**: REQ-SSH-004
- **Status**: Covered

### SCENARIO-SSH-005: SCP Upload with Session Parameters
- **Given**: A detected SSH session with port, identity file, and jump host
- **When**: `uploadDroppedFiles` is called with local file URLs
- **Then**: SCP is invoked with matching `-P`, `-i`, `-J` flags and the file is uploaded to the remote path
- **Verifies**: REQ-SSH-005
- **Status**: Covered

### SCENARIO-SSH-006: SCP Upload Cleanup on Failure
- **Given**: An SCP upload that fails mid-batch
- **When**: The second file fails to upload
- **Then**: Previously uploaded files are cleaned up via SSH `rm` on the remote
- **Verifies**: REQ-SSH-005
- **Status**: Covered

### SCENARIO-SSH-007: Zsh Bootstrap Sources Real Dotfiles
- **Given**: A `RemoteRelayZshBootstrap` with a shell state directory
- **When**: `zshRCLines` is generated
- **Then**: Output includes sourcing of `$CMUX_REAL_ZDOTDIR/.zshrc` and history redirection
- **Verifies**: REQ-SSH-008
- **Status**: Covered

## Cross-Platform Notes

- **macOS-only**: Process detection via `ps -t <tty>` and argument introspection via `sysctl(KERN_PROCARGS2)` are macOS/BSD-specific. Linux equivalent would use `/proc/<pid>/cmdline`.
- **macOS-only**: SCP/SSH file operations use `/usr/bin/scp` and `/usr/bin/ssh` paths that are macOS-standard.
- **Cross-platform**: SSH argument parsing logic and zsh bootstrap generation are pure Swift with no platform dependencies.
- **Linux port**: Will need `/proc`-based process detection and potentially different executable paths.

## Implementation Status

| Requirement | Status | Test Coverage |
|-------------|--------|--------------|
| REQ-SSH-001 | Implemented | WorkspaceRemoteConnectionTests |
| REQ-SSH-002 | Implemented | WorkspaceRemoteConnectionTests |
| REQ-SSH-003 | Implemented | WorkspaceRemoteConnectionTests |
| REQ-SSH-004 | Implemented | WorkspaceRemoteConnectionTests |
| REQ-SSH-005 | Implemented | WorkspaceRemoteConnectionTests |
| REQ-SSH-006 | Implemented | WorkspaceRemoteConnectionTests |
| REQ-SSH-007 | Implemented (macOS) | (process-level, not unit-testable) |
| REQ-SSH-008 | Implemented | WorkspaceRemoteConnectionTests |
