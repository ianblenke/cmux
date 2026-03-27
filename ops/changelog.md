# Changelog

## 2026-03-26 — Linux Port + OpenSpec Backfill (38 commits)

### OpenSpec Backfill
- Created `_bmad/prd.md`, `_bmad/architecture.md`, `_bmad/traceability.md`
- Created 21 capability specs (355 REQs, 219 scenarios) in `openspec/capabilities/`
- Created ops/ directory (status, changelog, known-issues, e2e-test-plan, metrics)
- Created PAL protocols (15 files in `Sources/PAL/`)
- Created Core modules (4 files in `Sources/Core/`)

### Linux Terminal Application (NEW)
**Built from scratch in one session — macOS-only to cross-platform**

Terminal rendering:
- GTK4 + GtkGLArea + OpenGL 4.6 via libghostty embedded API
- Ghostty fork extended with GHOSTTY_PLATFORM_LINUX (5 commits)
- dlopen-based loading to bypass Zig global constructor issues
- Dracula theme and Ghostty config support

Input:
- Full keyboard with GDK→evdev keycode mapping (GdkToEvdev.swift)
- Mouse click, motion, scroll via GTK4 gesture controllers
- Clipboard copy (Ctrl+Shift+C) and paste (Ctrl+Shift+V) via GDK
- C ABI helpers for struct-by-value calling convention (CGhosttyHelpers)

Workspaces:
- Create (Super+T), close (Super+W), switch (Super+1-9)
- Sidebar with dynamic workspace list and active indicator
- CWD inheritance on split
- Dynamic window title from shell (user@host:cwd)

Split panes:
- Horizontal (Super+D), vertical (Ctrl+Shift+D)
- Both panes render independently (fresh GtkGLAreas)
- Pane focus navigation (Ctrl+Alt+arrows)

Notifications:
- Bell detection with * indicator in sidebar
- Desktop notification action routing (OSC 9/99/777)

Session persistence:
- Save workspace layout on exit (SIGTERM-safe)
- Restore on launch from ~/.local/share/cmux/session.json
- Autosave every 30 seconds

Socket control API:
- Unix socket at /tmp/cmux-<pid>.sock
- 9 JSON-RPC commands: identify, list, create, select, close, split, send_text, send_key, notify
- CLI wrapper: `cmux list`, `cmux new`, `cmux notify`, etc.

Other:
- Font size adjustment (Ctrl+Plus/Minus/0)
- Command-line args (-e command, -d directory, --title, --help)
- Build script: `./scripts/build-linux.sh --run`
- Linux README with full documentation

### Trigger
User instruction: "This is an upstream project named cmux that is targeted at MacOS only but is based on Ghostty which should be compatible with Linux. This project is a fork of that which makes it run natively on linux again."
