# SSH Detection Design

**Last Updated**: 2026-03-26

## Architecture

SSH detection operates as a non-intrusive observer that inspects the process table for a terminal's TTY to discover active SSH sessions. It does not modify or intercept the SSH connection; it only reads process metadata.

The detection feeds into the remote workspace system, enabling:
- Automatic remote workspace tagging
- SCP-based drag-and-drop file upload to remote hosts
- Shell environment bootstrapping for remote sessions

## Key Components

### TerminalSSHSessionDetector (enum, static methods)
- Entry point: `detect(forTTY:)` for production, `detectForTesting(ttyName:processes:argumentsByPID:)` for unit tests
- Runs `ps -ww -t <tty> -o pid=,pgid=,tpgid=,tty=,ucomm=` to snapshot processes
- Filters for `ssh` processes where `pgid == tpgid` (foreground process group)
- Reads full argv via `sysctl(KERN_PROCARGS2)` (macOS-specific)
- Parses SSH command line to extract structured session info

### DetectedSSHSession (struct)
- Value type holding all parsed SSH connection parameters
- Provides `uploadDroppedFiles` for SCP-based file transfer
- Generates SCP/SSH argument arrays that mirror the original session's connection config
- Handles IPv6 literal bracketing, option filtering, and login name resolution

### SSH Command-Line Parser
- Handles all standard SSH flag formats: `-p 22`, `-p22`, `-o Key=Value`, `-o Key Value`
- Classifies flags as no-argument (`-4`, `-6`, `-A`, `-C`, `-t`, etc.) or value-argument (`-p`, `-i`, `-F`, `-J`, `-o`, etc.)
- Filters security-sensitive `-o` keys (BatchMode, ControlMaster, etc.) to prevent leaking them into SCP subprocesses
- Stops at `--` separator or first non-flag argument (the destination)

### RemoteRelayZshBootstrap (struct)
- Generates zsh startup file content for remote shell sessions
- Redirects ZDOTDIR to a cmux-managed directory while sourcing user's real dotfiles
- Ensures shared history files point to the user's real home directory

## Platform Abstraction

| Component | macOS | Linux (planned) |
|-----------|-------|-----------------|
| Process listing | `/bin/ps -ww -t <tty>` | `/bin/ps -ww -t <tty>` or `/proc` enumeration |
| Argv introspection | `sysctl(KERN_PROCARGS2)` | `/proc/<pid>/cmdline` |
| SCP/SSH executables | `/usr/bin/scp`, `/usr/bin/ssh` | Path discovery needed |
| SSH arg parsing | Pure Swift | Pure Swift (shared) |
| Zsh bootstrap | Pure Swift | Pure Swift (shared) |

## Data Flow

```
Terminal surface created
  -> Ghostty reports TTY name
    -> TerminalSSHSessionDetector.detect(forTTY:)
      -> ps snapshot -> filter foreground ssh -> sysctl argv -> parse args
        -> DetectedSSHSession stored on workspace
          -> Enables: drag-drop SCP upload, remote workspace features

User drops file onto remote workspace
  -> DetectedSSHSession.uploadDroppedFiles([URLs])
    -> For each file: scp with session params -> remote path
    -> On failure: ssh rm cleanup of uploaded files
    -> On cancellation: async cleanup
```

## Dependencies

- Foundation (Process, Pipe for subprocess execution)
- Darwin (sysctl for process argument introspection, macOS-only)
- No external packages
- Workspace/TerminalPanel integration for storing detected sessions
