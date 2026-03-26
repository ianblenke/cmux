# Localization Design

**Last Updated**: 2026-03-26

## Architecture

Localization in cmux uses a two-tier approach:

1. **Runtime string resolution** -- `String(localized:defaultValue:)` calls resolve keys from the compiled string catalog at runtime based on the user's system locale.
2. **Static documentation** -- README files are maintained as separate per-language markdown files in the repository root.

```
┌──────────────────────────────────────────┐
│           Source Code (.swift)            │
│  String(localized: "key", defaultValue:) │
└──────────────┬───────────────────────────┘
               │ references
               ▼
┌──────────────────────────────────────────┐
│      Resources/Localizable.xcstrings     │
│  ┌────────┐ ┌────────┐ ┌────────┐       │
│  │  "en"  │ │  "ja"  │ │  ...   │       │
│  └────────┘ └────────┘ └────────┘       │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│     Resources/InfoPlist.xcstrings        │
│  System-level strings (18 languages)     │
│  Camera, Microphone, Service Menu items  │
└──────────────────────────────────────────┘
```

## Key Components

### String Catalogs

| File | Purpose | Languages |
|------|---------|-----------|
| `Resources/Localizable.xcstrings` | All app UI strings | en, ja |
| `Resources/InfoPlist.xcstrings` | OS-level permission and service strings | en, ja + 16 others |

### String Key Convention

Keys use dot-separated namespaces that mirror the feature area:

- `menu.*` -- Menu bar items
- `dialog.*` -- Dialog/alert text
- `sidebar.*` -- Sidebar labels
- `settings.*` -- Settings/preferences
- `update.*` -- Update system strings
- `browser.*` -- Browser panel strings
- `find.*` -- Find/search overlay strings

### Call Site Pattern

Every user-facing string follows this pattern:

```swift
// Simple label
Text(String(localized: "sidebar.workspace.title", defaultValue: "Workspaces"))

// With interpolation
String(localized: "dialog.close.message \(count)",
       defaultValue: "Close \(count) tabs?")
```

## Platform Abstraction

### macOS (Current)

- Uses Apple's native `String(localized:)` API (available since macOS 13)
- Xcode compiles `.xcstrings` into `.strings` / `.stringsdict` at build time
- OS handles locale detection and fallback chain automatically

### Linux (Planned)

Two viable approaches:

**Option A: Foundation on Linux**
- swift-corelibs-foundation supports `Bundle.localizedString(forKey:value:table:)`
- Compile `.xcstrings` to `.strings` files at build time using a script or Swift tool
- Bundle the `.strings` files as Swift Package resources
- Wrap in a `LocalizedString` helper that works identically on both platforms

**Option B: Dual format (xcstrings + gettext)**
- Maintain `.xcstrings` as source of truth
- Build step generates `.po` files from `.xcstrings` for each language
- GTK4 UI layer uses gettext natively
- Shared core logic uses a platform protocol:

```swift
protocol StringLocalizer {
    func localized(_ key: String, defaultValue: String) -> String
}

// macOS: AppleStringLocalizer (wraps String(localized:))
// Linux: GettextStringLocalizer (wraps gettext())
```

**Recommended**: Option A for initial port (less infrastructure), migrate to Option B if GTK integration demands it.

## Data Flow

```
Developer adds string
        │
        ▼
Localizable.xcstrings (JSON, checked in)
        │
        ├─── macOS build: Xcode compiles to .strings bundle
        │         │
        │         ▼
        │    String(localized:) resolves at runtime
        │
        └─── Linux build: extract script → .strings or .po files
                  │
                  ▼
             Bundle.localizedString() or gettext()
```

### Translation Workflow

1. Developer adds key + English default value in code
2. Key auto-appears in `.xcstrings` (Xcode extraction or manual)
3. Japanese translation added (P0 for every string)
4. Extended languages translated in batches (P1/P2)
5. README translations updated independently by contributors

## Dependencies

| Dependency | Role | Platform |
|------------|------|----------|
| Apple String Catalog runtime | String resolution | macOS |
| Foundation `Bundle` | Fallback string resolution | macOS, Linux |
| gettext / libintl | Native Linux localization (if Option B) | Linux |
| Xcode build system | `.xcstrings` compilation | macOS |
| Custom build script | `.xcstrings` to `.strings`/`.po` conversion | Linux |

## Open Questions

1. **Automated lint rule**: Should a SwiftLint custom rule or build plugin flag un-localized string literals in UI constructors?
2. **Translation management**: Should the project adopt a translation management platform (Crowdin, Weblate) as more languages are added?
3. **Pluralization**: Are there strings requiring plural rules beyond simple interpolation? If so, `.stringsdict` / gettext plural forms will be needed.
4. **Linux locale detection**: On Linux without AppKit, locale detection falls to `LANG`/`LC_*` environment variables via Foundation or libc.
