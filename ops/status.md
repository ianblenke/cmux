# Operational Status

**Last Updated**: 2026-03-26

## What's Working

### Linux Application (54 commits this session)

**Terminal**
- GPU-accelerated rendering (OpenGL 4.6 via libghostty)
- Ghostty config support (~/.config/ghostty/config — themes, fonts, colors)
- Font size adjustment (Ctrl+Plus/Minus/0)
- Search/find in scrollback (Ctrl+Shift+F)
- Scrollback navigation (Shift+PageUp/Down/Home/End)
- Clear scrollback (Super+K)
- Config reload (Ctrl+Shift+,)
- HiDPI support (2x scale)
- Terminal resize with window

**Input**
- Full keyboard with GDK→evdev keycode mapping
- All special keys (Backspace, Tab, arrows, Home/End, etc.)
- Mouse click, motion, scroll
- Clipboard copy (Ctrl+Shift+C) and paste (Ctrl+Shift+V)
- Shell signals pass through (Ctrl+C/D/Z)

**Workspaces**
- Create (Super+T / Ctrl+Shift+T)
- Close (Super+W / Ctrl+Shift+W)
- Switch (Super+1-9)
- Next/prev (Super+]/[)
- Sidebar with CSS styling (active highlight, dimmed inactive)
- Dynamic titles from shell (user@host:cwd)
- Git branch detection in sidebar
- Sidebar toggle (Super+B)
- Click-to-switch with auto-focus

**Split Panes**
- Horizontal (Super+D)
- Vertical (Super+Shift+D / Ctrl+Shift+D)
- Close pane / collapse split (Super+Shift+W)
- CWD inheritance on split
- Pane focus navigation (Ctrl+Alt+arrows)

**Browser Panels**
- WebKitGTK 6.0 in-app browser
- Open browser (Super+L / `cmux browser`)
- URL bar with navigation
- JavaScript evaluation (`cmux eval`)
- DOM snapshot for agents (`cmux snapshot`)
- Navigate (`cmux navigate`)

**Notifications**
- Bell detection with sidebar indicator
- OSC 9/99/777 desktop notification parsing
- Notification via CLI (`cmux notify`)

**Persistence**
- Session save/restore on exit/launch
- Autosave every 30 seconds
- SIGTERM/SIGINT-safe save
- Window close handler save
- XDG-compliant paths (~/.local/share/cmux/)

**Automation**
- Unix socket API (14 JSON-RPC commands)
- CLI wrapper (15 commands)
- Shell integration (CMUX_SOCKET_PATH in env)
- Command-line args (-e, -d, --title, --help)

**Build & Distribution**
- `./scripts/build-linux.sh --run` (one-command build+launch)
- `./scripts/build-linux.sh --install` (install to ~/.local/)
- Desktop entry (cmux.desktop)
- Shell integration installer
- GitHub Actions CI workflow
- Linux README with full documentation

### Cross-Platform Infrastructure
- Platform Abstraction Layer (15 protocol files)
- Core shared modules (4 files)
- OpenSpec: 355 requirements, 219 scenarios, 21 capabilities

### Ghostty Fork (ianblenke/ghostty, merged to main)
- GHOSTTY_PLATFORM_LINUX in embedded API
- Conditional objc import, must_draw_from_app_thread
- GLAD bundled in shared library, OpenGL surfaceInit

## What's Next
1. Linux packaging (AppImage/Flatpak)
2. Browser accessibility tree API (full agent-browser port)
3. Sidebar listening ports display
4. macOS PAL extraction (shared Core modules)
5. Automated tests for socket API
