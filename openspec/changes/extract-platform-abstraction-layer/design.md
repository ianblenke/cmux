## Context

cmux has 60 Swift source files in a flat `Sources/` directory. Platform-specific code (AppKit, SwiftUI, WKWebView, Sparkle, Metal) is mixed with platform-agnostic logic (workspace model, tab management, config parsing, socket control). The existing `openspec/capabilities/cross-platform/design.md` defines the target PAL architecture; this change implements Phase 1 — the non-breaking extraction on macOS only.

Current state: all code in `Sources/` with direct `import AppKit` / `import SwiftUI` throughout. No separation between model logic and UI code. Build system is Xcode project + minimal SPM `Package.swift`.

## Goals / Non-Goals

**Goals:**
- Separate all source files into Core (platform-agnostic), PAL (protocol definitions), and macOS (platform-specific)
- Core code compiles with only Foundation + PAL imports — no AppKit, SwiftUI, Cocoa, WebKit
- All 46 existing tests pass without modification
- Build system supports the new target structure
- Clear protocol boundaries that a future Linux backend can implement

**Non-Goals:**
- No Linux code in this change — no GTK4, no WebKitGTK, no Linux CI
- No new features or behavioral changes
- No test modifications (tests verify existing behavior is preserved)
- No changes to the CLI, socket API, or config format
- No Bonsplit modifications (it stays as a vendored macOS dependency)

## Decisions

### D1: Three-Target SPM Structure

**Decision**: Split into `cmux-core`, `cmux-pal`, and `cmux-macos` SPM targets.

**Rationale**: SPM targets enforce import boundaries at compile time. If `cmux-core` doesn't depend on AppKit, no file in that target can import it. This is a harder guarantee than code review.

**Alternatives considered**:
- Single target with `#if os()` guards — weaker guarantee, easy to accidentally add platform imports to shared code
- Separate SPM packages — too heavy; targets within one package are sufficient

### D2: Protocol-Based PAL (Not Type Aliases)

**Decision**: PAL uses Swift protocols (`PlatformWindow`, `PlatformSurface`, etc.) rather than type aliases or conditional compilation.

**Rationale**: Protocols enforce the contract at the type system level. A Linux backend must implement the same interface. Type aliases would let platform types leak into core logic.

**Exception**: `PlatformTypes.swift` uses type aliases for basic geometry types (`PlatformRect`, `PlatformColor`) where protocols would add overhead in hot paths.

### D3: Wrapper Pattern for macOS Backend

**Decision**: macOS implementations are thin wrappers around existing code, not rewrites.

**Rationale**: Minimizes risk. The existing AppKit/SwiftUI code is battle-tested. Wrapping it in a `MacOSWindow: PlatformWindow` conformance preserves all existing behavior while satisfying the PAL interface.

**Example**:
```swift
// Sources/macOS/MacOSClipboard.swift
import AppKit

struct MacOSClipboard: PlatformClipboard {
    func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
    func paste() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}
```

### D4: Incremental File Migration Order

**Decision**: Migrate files in dependency order — pure models first, then services, then UI.

**Rationale**: Each step is independently compilable and testable. If a file has no platform imports, it moves to Core immediately. If it mixes model and UI, extract the model portion first.

**Migration order**:
1. PAL protocol definitions (new files)
2. Pure model files (Workspace model, config parsing, notification store)
3. Service files (SessionPersistence, SocketControlSettings, PortScanner)
4. Manager files (TabManager — needs protocol injection for UI callbacks)
5. macOS wrappers (thin conformances around existing code)
6. Update remaining files' imports

### D5: Xcode Project Coexistence

**Decision**: Keep `GhosttyTabs.xcodeproj` working alongside SPM targets during transition.

**Rationale**: The Xcode project is the primary build system for macOS. Breaking it would block all development. SPM targets are added in parallel; Xcode file references are updated to match the new directory structure.

## Risks / Trade-offs

**[Risk] Circular dependencies between Core and macOS** → Mitigation: PAL protocols break all cycles. Core depends only on PAL; macOS depends on Core + PAL + system frameworks. Strict layering enforced by SPM target dependencies.

**[Risk] Performance regression from protocol dispatch in hot paths** → Mitigation: Terminal input path (keystroke → render) does not go through PAL protocols — it goes directly through libghostty's C FFI which is already platform-agnostic. PAL protocols are used for lifecycle operations (window create, tab switch), not per-frame or per-keystroke operations.

**[Risk] Xcode project file conflicts during migration** → Mitigation: Move files in small batches, updating `project.pbxproj` group references incrementally. Each batch is a separate commit that builds successfully.

**[Risk] Some files resist clean separation** → Mitigation: Files that mix Core and macOS concerns (e.g., TabManager with SwiftUI `@Published` properties) get the model logic extracted into a Core protocol/class, with the macOS-specific observation layer remaining in `Sources/macOS/`. Accept that some files may need partial extraction rather than clean moves.

**[Trade-off] SwiftUI's `@Published` / `@ObservableObject` are macOS-specific** → For Phase 1, Core model classes can still use `@Published` since it's available via Combine (which ships with Swift on macOS). For Linux, these will need replacement with a custom observation pattern. This is acceptable for Phase 1 — the goal is directory separation and import boundaries, not eliminating all macOS types from Core.

## Open Questions

1. **Combine in Core**: Should Core files be allowed to use Combine (`@Published`, `CurrentValueSubject`)? Combine is available on Linux via OpenCombine, but it's not guaranteed. For Phase 1, allowing it keeps the migration simpler. For Phase 2 (Linux), we may need to replace with a lightweight observable pattern.

2. **Foundation availability**: Foundation on Linux (swift-corelibs-foundation) covers most of what Core needs (FileManager, JSONDecoder, ProcessInfo, URL) but has gaps. Should we audit Foundation usage in Core files now or defer to Phase 2?
