# cmux for Linux

A cross-platform fork of [cmux](https://github.com/manaflow-ai/cmux) — a Ghostty-based terminal with vertical tabs, notifications, and workspaces for AI coding agents.

## Build from Source

### Prerequisites

- **Swift 6.0+** (`yay -S swift-bin` on Arch, or [swift.org/download](https://swift.org/download))
- **Zig 0.14+** (`sudo pacman -S zig` on Arch)
- **GTK4 dev** (`sudo pacman -S gtk4` / `sudo apt install libgtk-4-dev`)
- **pkg-config** (`sudo pacman -S pkgconf`)

### Quick Build

```bash
git clone --recursive https://github.com/ianblenke/cmux.git
cd cmux
./scripts/build-linux.sh --run
```

This will:
1. Init the ghostty submodule (if needed)
2. Build libghostty with the Linux embedded API
3. Build the cmux-linux binary
4. Launch the app

### Manual Build

```bash
# Init submodules
git submodule update --init ghostty

# Build libghostty
cd ghostty && zig build -Dapp-runtime=none -Doptimize=ReleaseFast && cd ..

# Build cmux
cp Package.linux.swift Package.swift
swift build

# Run
.build/debug/cmux-linux
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Ctrl+T | New workspace |
| Ctrl+W | Close workspace |
| Ctrl+1-9 | Switch to workspace 1-9 |
| Ctrl+] | Next workspace |
| Ctrl+[ | Previous workspace |
| Ctrl+Shift+C | Copy selection |
| Ctrl+Shift+V | Paste from clipboard |
| Ctrl+C | Send SIGINT |

## Architecture

```
Swift (GTK4 + GtkGLArea) → libghostty.so (dlopen) → OpenGL 4.6 → Terminal
                                    ↕
                               PTY → /bin/bash
```

- Terminal rendering: libghostty with Ghostty's OpenGL renderer
- UI framework: GTK4 on Wayland (X11 also supported)
- Keyboard: GDK keyval → evdev keycode mapping
- Clipboard: GDK clipboard (Wayland native)
- Build: Swift Package Manager

## Ghostty Fork

This project uses a [modified Ghostty](https://github.com/ianblenke/ghostty/tree/linux-embedded-platform) with `GHOSTTY_PLATFORM_LINUX` added to the embedded API, enabling host applications to embed Ghostty terminal surfaces in GtkGLArea widgets.

## CLI

Install the CLI for remote control:
```bash
ln -sf "$(pwd)/scripts/cmux-cli.sh" ~/.local/bin/cmux
```

Control cmux from any terminal:
```bash
cmux list                           # List workspaces
cmux new /path/to/project "name"    # Create workspace
cmux select 2                       # Switch to workspace
cmux notify "Agent" "Build done"    # Send notification
cmux identify                       # Show app info
```

AI agents can use the socket directly:
```bash
SOCK=$(cat /tmp/cmux-socket-path)
echo '{"method":"workspace.create","params":{"directory":"/project"}}' \
  | socat - UNIX-CONNECT:$SOCK
```

## Status

Working:
- GPU-accelerated terminal rendering (OpenGL 4.6)
- Ghostty config (themes, fonts from ~/.config/ghostty/config)
- Full keyboard input with modifier keys
- Mouse (click, motion, scroll)
- Clipboard (Ctrl+Shift+C/V)
- Multiple workspaces (Super+T/W/1-9)
- Split panes (Super+D, Ctrl+Shift+D)
- CWD inheritance on split
- Dynamic window/sidebar titles from shell
- Bell notifications with sidebar indicators
- Font size adjustment (Ctrl+Plus/Minus/0)
- Session persistence (save/restore on exit/launch)
- Socket control API (9 JSON-RPC commands)
- CLI wrapper (cmux list/new/select/notify)
- HiDPI support
- Command-line args (-e, -d, --title)

In progress:
- Browser panels (WebKitGTK)
- Shell integration hooks
- Linux packaging (AppImage/Flatpak)
