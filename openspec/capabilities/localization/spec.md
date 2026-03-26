# Localization Specification

**Status**: EXTRACTED
**Last Updated**: 2026-03-26

## Overview

cmux supports multiple languages for all user-facing strings in the application UI and documentation. The primary localization mechanism is Apple's String Catalog (`.xcstrings`) with `String(localized:defaultValue:)` calls throughout the Swift codebase, plus translated README files for project documentation.

## Requirements

### REQ-L10N-001: All UI strings use localized API
- **Description**: Every user-facing string displayed in the application (labels, buttons, menus, dialogs, tooltips, error messages) must use `String(localized: "key.name", defaultValue: "English text")`. Bare string literals in SwiftUI `Text()`, `Button()`, alert titles, and similar constructs are prohibited.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-L10N-002: String catalog as single source of truth
- **Description**: All localizable strings are declared in `Resources/Localizable.xcstrings` using Apple's String Catalog format. Keys follow a dot-separated namespace convention. The source language is English (`en`).
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-L10N-003: Info.plist string localization
- **Description**: System-level strings referenced by the OS (camera/microphone usage descriptions, Finder service menu items) are localized in `Resources/InfoPlist.xcstrings`, separate from the main string catalog.
- **Platform**: macOS
- **Status**: Implemented
- **Priority**: P0

### REQ-L10N-004: Japanese language support
- **Description**: All strings in both `Localizable.xcstrings` and `InfoPlist.xcstrings` must have complete Japanese (`ja`) translations. Japanese is a first-class supported language alongside English.
- **Platform**: all
- **Status**: Implemented
- **Priority**: P0

### REQ-L10N-005: Extended language support for system strings
- **Description**: `InfoPlist.xcstrings` supports an extended set of languages beyond English and Japanese: zh-Hans, zh-Hant, ko, de, es, fr, it, da, pl, ru, bs, ar, nb, pt-BR, th, tr. New Info.plist entries should include translations for all these languages.
- **Platform**: macOS
- **Status**: Implemented
- **Priority**: P1

### REQ-L10N-006: README documentation translations
- **Description**: The project README is translated into multiple languages as separate files (`README.<lang>.md`). Currently 19 translations exist: ar, bs, da, de, es, fr, it, ja, km, ko, no, pl, pt-BR, ru, th, tr, vi, zh-CN, zh-TW.
- **Platform**: all (documentation)
- **Status**: Implemented
- **Priority**: P2

### REQ-L10N-007: No hardcoded English in UI paths
- **Description**: Code review and linting should flag any bare English string literals passed directly to SwiftUI view constructors (`Text("...")`, `Button("...")`, `Label("...", ...)`) without going through the localized string API.
- **Platform**: all
- **Status**: Partial (enforced by convention, no automated linter)
- **Priority**: P1

### REQ-L10N-008: RTL language support
- **Description**: The UI layout must function correctly for right-to-left languages (currently Arabic). SwiftUI's built-in RTL support handles most layout, but custom layouts (sidebar, split panes, tab bar) must not hardcode left-to-right assumptions.
- **Platform**: all
- **Status**: Partial
- **Priority**: P2

### REQ-L10N-009: Linux localization backend
- **Description**: On Linux, localized strings must be accessible without Apple's String Catalog runtime. A build-time extraction step or cross-platform string table format (e.g., gettext `.po`, JSON, or compiled Swift resource bundle) is required to serve the same keys on non-Apple platforms.
- **Platform**: Linux
- **Status**: Proposed
- **Priority**: P1

### REQ-L10N-010: New string addition workflow
- **Description**: When adding a new user-facing string, developers must: (1) add the key to `Localizable.xcstrings` with the English default value, (2) provide Japanese translation, (3) use `String(localized:defaultValue:)` at the call site. Extended language translations may be batched.
- **Platform**: all
- **Status**: Implemented (by convention)
- **Priority**: P1

## Scenarios

### SCENARIO-L10N-001: App launches in Japanese locale
- **Given**: The user's system locale is set to Japanese (`ja`)
- **When**: The application launches
- **Then**: All menus, dialogs, buttons, and labels display Japanese text from the string catalog
- **Verifies**: REQ-L10N-001, REQ-L10N-002, REQ-L10N-004
- **Status**: Covered

### SCENARIO-L10N-002: Finder service menu shows localized text
- **Given**: The user's system locale is Japanese
- **When**: The user right-clicks a folder in Finder and navigates to the Services submenu
- **Then**: "New cmux Workspace Here" and "New cmux Window Here" appear in Japanese
- **Verifies**: REQ-L10N-003, REQ-L10N-005
- **Status**: Covered

### SCENARIO-L10N-003: Camera/microphone permission dialog is localized
- **Given**: The user's system locale is Japanese
- **When**: A terminal program requests camera or microphone access
- **Then**: The system permission dialog shows the localized usage description
- **Verifies**: REQ-L10N-003
- **Status**: Covered

### SCENARIO-L10N-004: Missing translation falls back to English
- **Given**: The user's system locale is set to a language that has no translations in `Localizable.xcstrings`
- **When**: The application renders any UI string
- **Then**: The English default value is displayed (no empty strings or key names shown)
- **Verifies**: REQ-L10N-001, REQ-L10N-002
- **Status**: Covered (Apple's String Catalog fallback behavior)

### SCENARIO-L10N-005: New feature string added correctly
- **Given**: A developer is adding a new dialog with user-facing text
- **When**: They add the string using `String(localized: "dialog.confirm.title", defaultValue: "Confirm")`
- **Then**: The key appears in `Localizable.xcstrings`, English and Japanese translations are present, and the string renders in both locales
- **Verifies**: REQ-L10N-010
- **Status**: Covered (manual review)

### SCENARIO-L10N-006: RTL layout with Arabic locale
- **Given**: The user's system locale is set to Arabic (`ar`)
- **When**: The application launches and the sidebar, tab bar, and split panes render
- **Then**: Text is right-aligned, sidebar appears on the correct side per RTL conventions, and no UI elements overlap or clip
- **Verifies**: REQ-L10N-008
- **Status**: Missing

### SCENARIO-L10N-007: Linux app displays localized strings
- **Given**: The Linux build of cmux is running with locale set to Japanese
- **When**: The application renders UI strings
- **Then**: Japanese translations are displayed, sourced from the cross-platform localization backend
- **Verifies**: REQ-L10N-009
- **Status**: Missing

## Cross-Platform Notes

- Apple's `.xcstrings` format is a JSON file and can be parsed/transformed on any platform. However, the runtime `String(localized:)` API is Foundation-specific.
- For Linux, the build system should extract strings from `.xcstrings` into a platform-appropriate format at build time, or use a thin Swift wrapper that reads the JSON directly via Foundation on Linux (Foundation is available via swift-corelibs-foundation).
- gettext (`.po`/`.mo`) is the Linux-native localization standard and integrates with GTK. A dual-format approach (xcstrings for macOS, gettext for GTK) with a shared source of truth may be necessary.
- README translations are static markdown files and require no runtime support.

## Implementation Status

| Requirement | Status | Notes |
|-------------|--------|-------|
| REQ-L10N-001 | Implemented | 856 occurrences across 22 source files |
| REQ-L10N-002 | Implemented | `Resources/Localizable.xcstrings` (~2MB) |
| REQ-L10N-003 | Implemented | `Resources/InfoPlist.xcstrings` with 18 languages |
| REQ-L10N-004 | Implemented | Japanese translations in both string catalogs |
| REQ-L10N-005 | Implemented | 18 languages in InfoPlist.xcstrings |
| REQ-L10N-006 | Implemented | 19 README translation files |
| REQ-L10N-007 | Partial | Convention-enforced, no automated check |
| REQ-L10N-008 | Partial | Arabic is in InfoPlist; full RTL UI testing incomplete |
| REQ-L10N-009 | Proposed | No Linux localization backend yet |
| REQ-L10N-010 | Implemented | Developer workflow documented in CLAUDE.md |
