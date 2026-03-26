# OpenSpec Agent Instructions

This document provides instructions for AI agents working with the cmux OpenSpec specifications.

## Spec-Anchored Development Workflow

Every code change follows this chain:

1. **Spec First** — Update or create `openspec/capabilities/<cap>/spec.md` with REQ-* and SCENARIO-*
2. **Write Tests** — Tests reference REQ-* and SCENARIO-* in comments
3. **Implement** — Code to satisfy spec requirements
4. **Verify** — Run unit tests, type checks, builds
5. **E2E Verify** — Run end-to-end tests per `ops/e2e-test-plan.md`
6. **Reconcile** — Update spec implementation status, traceability matrix, ops docs

## Directory Structure

```
openspec/
  config.yaml           # Project context and rules
  AGENTS.md             # This file
  project.md            # Project conventions
  capabilities/         # Source of truth: what the system does
    <capability>/
      spec.md           # REQ-*, SCENARIO-* definitions
      design.md         # Technical patterns and decisions
  changes/              # Delta specs for proposed changes
    <change-name>/
      proposal.md
      specs/
      tasks.md
    archive/            # Completed proposals
  specs/                # OpenSpec default (unused, use capabilities/)
```

## Requirement IDs

Format: `REQ-<CAP>-NNN` where `<CAP>` is the capability abbreviation:

| Capability | Abbreviation |
|-----------|-------------|
| terminal-core | TC |
| tab-management | TM |
| split-panes | SP |
| workspaces | WS |
| browser-panels | BP |
| session-persistence | SPE |
| notifications | NT |
| socket-control | SC |
| update-system | US |
| configuration | CF |
| keyboard-shortcuts | KS |
| search-find | SF |
| remote-daemon | RD |
| ssh-detection | SSH |
| window-management | WM |
| sidebar | SB |
| applescript | AS |
| port-scanning | PS |
| analytics | AN |
| localization | L10N |
| cross-platform | XP |

## Scenario Format

Always use Given/When/Then BDD format:

```markdown
### SCENARIO-TC-001: Terminal renders keystroke
- **Given**: A terminal surface is focused and visible
- **When**: The user types a character
- **Then**: The character appears in the terminal within 16ms (one frame)
- **Verifies**: REQ-TC-001
- **Status**: Covered
```

## Cross-Platform Requirements

Every REQ-* must specify platform applicability:
- `all` — Required on all platforms
- `macOS-only` — Only applies to macOS (e.g., Sparkle updates, AppleScript)
- `Linux-only` — Only applies to Linux (e.g., GTK4 integration)

## Test Traceability

Every test file must include a traceability header:

```swift
// Tests for: openspec/capabilities/terminal-core/spec.md
// REQ-TC-001: GPU-accelerated terminal rendering
// SCENARIO-TC-001: Terminal renders keystroke
```

## Spec Status Values

- `EXTRACTED` — Backfilled from existing code, not yet verified against implementation
- `Specified` — Written as a requirement, not yet implemented
- `Implemented` — Code exists that satisfies this requirement
- `Partial` — Partially implemented
- `Proposed` — New requirement, not yet approved
- `Deprecated` — Scheduled for removal
