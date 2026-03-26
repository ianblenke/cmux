# Configuration Design

**Last Updated**: 2026-03-26

## Architecture

The configuration system has two independent subsystems:

1. **GhosttyConfig** -- Reads Ghostty-compatible terminal configuration (fonts, colors, themes, split appearance) from standard file paths. Provides a cached, color-scheme-aware loading API.
2. **CmuxConfig** -- Reads cmux-specific workspace and command definitions from `cmux.json` files. Manages local/global precedence, file watching, and command execution with trust verification.

Both subsystems are loaded at startup and refreshed reactively (config on file change, Ghostty config on theme reload notification).

## Key Components

### GhosttyConfig (struct)
- Value type holding all parsed terminal config properties
- `loadFromDisk(preferredColorScheme:)` -- walks config file paths in order, parses each
- `parse(_ contents:)` -- line-by-line key=value parser, updates struct fields
- `loadTheme(_:environment:bundleResourceURL:preferredColorScheme:)` -- resolves theme name, searches theme paths, parses theme file as config
- `resolveThemeName(from:preferredColorScheme:)` -- parses `light:Name,dark:Name` syntax
- `themeNameCandidates(from:)` -- generates fallback names (builtin stripping, Solarized aliases)
- `themeSearchPaths(forThemeName:environment:bundleResourceURL:)` -- ordered search locations
- Thread-safe cache: `cachedConfigsByColorScheme` guarded by `NSLock`

### CmuxConfigFile / CmuxCommandDefinition (Codable structs)
- JSON schema: `{ "commands": [{ "name": "...", "workspace": {...} | "command": "..." }] }`
- Validation in `init(from decoder:)`: non-blank names, non-blank commands, exclusive workspace/command, split children count, pane surface count
- `CmuxWorkspaceDefinition`: name, cwd, color (validated hex), layout tree
- `CmuxLayoutNode`: indirect enum with `.pane(CmuxPaneDefinition)` and `.split(CmuxSplitDefinition)`
- `CmuxSplitDefinition`: direction (horizontal/vertical), split ratio (clamped 0.1-0.9), exactly 2 children
- `CmuxPaneDefinition`: surfaces array (at least 1)
- `CmuxSurfaceDefinition`: type (terminal/browser), name, command, cwd, env, url, focus

### CmuxConfigStore (ObservableObject, @MainActor)
- `loadedCommands` -- published array of merged commands (local priority over global)
- `configRevision` -- incremented on each reload for change detection
- `commandSourcePaths` -- maps command ID to source file path
- `wireDirectoryTracking(tabManager:)` -- Combine pipeline observing selected tab's currentDirectory
- File watching: `DispatchSource.makeFileSystemObjectSource` for both local and global configs
- Reattach logic: up to 5 retries at 0.5s for deleted/renamed files
- Directory watchers for file creation detection
- `findCmuxConfig(startingFrom:)` -- walks up directory tree looking for `cmux.json`

### CmuxConfigExecutor (@MainActor struct)
- `execute(command:tabManager:baseCwd:configSourcePath:globalConfigPath:)` -- entry point
- Workspace commands: match existing by name, apply restart behavior, create workspace with layout
- Shell commands: sanitize for dangerous Unicode, optionally show confirmation dialog, send to terminal
- `sanitizeForDisplay(_:)` -- strips zero-width joiners, bidi overrides, BOM characters

### CmuxDirectoryTrust (singleton)
- Persistent trust store at `~/Library/Application Support/cmux/trusted-directories.json`
- `isTrusted(configPath:globalConfigPath:)` -- global always trusted; local checks trust store
- `trustKey(for:)` -- resolves to git repo root via `.git` directory walk, or parent dir
- `trust(configPath:)` / `revokeTrust(configPath:)` / `clearAll()`
- `replaceAll(with:)` for Settings UI bulk editing

## Platform Abstraction

### Portable Components
- `CmuxConfigFile`, `CmuxCommandDefinition`, all layout/surface types -- pure Swift Codable
- `CmuxConfigStore.resolveCwd()` -- uses only Foundation path operations
- `GhosttyConfig.parse()` -- pure string parsing
- `GhosttyConfig.resolveThemeName()`, `themeNameCandidates()` -- pure logic
- Split clamping logic

### macOS-Specific Components
- Config file paths using `~/Library/Application Support/`
- File watching via `DispatchSource` + `O_EVTONLY`
- Color types (`NSColor`)
- Confirmation dialog (`NSAlert`)
- Trust store path
- `NSApp.effectiveAppearance` for color scheme detection

### Linux Adaptation Needed
- Replace `~/Library/Application Support/` with `$XDG_CONFIG_HOME` / `$XDG_DATA_HOME`
- Replace `DispatchSource` file watching with `inotify`
- Replace `NSColor` with platform-agnostic color struct
- Replace `NSAlert` with GTK dialog or terminal confirmation
- Replace `NSApp.effectiveAppearance` with `$GTK_THEME` or portal dark mode detection

## Data Flow

```
App Launch
  -> GhosttyConfig.load(preferredColorScheme:)
    -> Check cache (per color scheme)
    -> loadFromDisk() -> walk config paths -> parse each file
    -> loadTheme() -> resolve name -> search paths -> parse theme
    -> resolveSidebarBackground() -> applySidebarAppearanceToUserDefaults()
    -> Store in cache

Workspace Selected / Directory Changed
  -> CmuxConfigStore.wireDirectoryTracking(tabManager:)
    -> Combine: selectedTabId -> workspace.currentDirectory
    -> updateLocalConfigPath(directory)
      -> findCmuxConfig(startingFrom:) -- walk up tree
      -> stopLocalFileWatcher() / startLocalFileWatcher()
      -> loadAll() -> parse local + global -> merge (local priority)

File Modified (DispatchSource event)
  -> loadAll() -> re-parse -> update loadedCommands + configRevision

Command Execution (from Command Palette)
  -> CmuxConfigExecutor.execute()
    -> Workspace: check existing -> apply restart behavior -> create workspace + layout
    -> Shell: sanitize -> check trust -> optionally confirm -> sendInput to terminal
```

## Dependencies

| Dependency | Purpose | Platform |
|------------|---------|----------|
| Foundation (JSONDecoder, FileManager) | Config parsing, file I/O | all |
| Combine (Publisher, AnyCancellable) | Directory tracking, reactive loading | all |
| AppKit (NSColor, NSAlert, NSApp) | Color parsing, dialogs, appearance | macOS |
| Bonsplit (SplitOrientation) | Layout orientation mapping | all |
| Darwin (open, O_EVTONLY) | File watching via DispatchSource | macOS/BSD |
