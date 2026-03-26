# Operational Status

**Last Updated**: 2026-03-26

## What's Working

### Linux Application (NEW — built this session)
- GTK4 window with sidebar + terminal on Wayland
- libghostty terminal rendering via OpenGL 4.6 in GtkGLArea
- Keyboard input with GDK→evdev keycode mapping
- Command execution with colored output
- Ctrl+C/D/Z signal handling
- Mouse motion, click, scroll
- Clipboard copy (Ctrl+Shift+C) via GDK
- Multiple workspaces (Ctrl+T new, Ctrl+W close, Ctrl+1-9 switch)
- Sidebar with dynamic workspace list and active indicator
- HiDPI support (2x scale)
- Terminal resize with window
- Focus management (click-to-focus, auto-focus on create)
- 60fps event processing tick loop

### Cross-Platform Infrastructure
- Platform Abstraction Layer (15 protocol files, compiles on Linux)
- Core modules (session persistence, config, types — compiles on Linux)
- OpenSpec coverage: 355 REQs, 219 scenarios across 21 capabilities
- BMAD strategic docs (PRD, architecture, traceability)

### Ghostty Fork (ianblenke/ghostty, branch: linux-embedded-platform)
- GHOSTTY_PLATFORM_LINUX in embedded API
- Conditional objc import for Linux
- must_draw_from_app_thread for OpenGL on Linux
- GLAD bundled in shared library
- OpenGL surfaceInit for embedded Linux

### macOS Application (existing, unchanged)
- Full terminal rendering via libghostty
- All existing features preserved
- Build system unchanged (Xcode project)

## What's Next

### Linux — Short Term
1. Proper paste (Ctrl+Shift+V via async GDK clipboard read)
2. Workspace titles from shell CWD/process name
3. Split panes within workspaces
4. Ghostty config file reading (themes, fonts, colors)
5. Build script improvements (auto-detect Package.swift swap)

### Linux — Medium Term
1. Socket control API (cmux CLI)
2. Session persistence (save/restore layout)
3. Notification system (OSC 9/99/777)
4. Browser panels (WebKitGTK)
5. Linux packaging (AppImage, Flatpak)

### Cross-Platform
1. Continue PAL Core extraction (config parsing, tab manager)
2. macOS backend wrappers for PAL protocols
3. Shared build system (single Package.swift with conditional compilation)

## Known Blockers
- Package.swift must be manually swapped for Linux builds (`cp Package.linux.swift Package.swift`)
- libghostty.so loaded via dlopen (not compile-time linked) due to Zig global init
- ghostty fork changes not yet merged to main branch
