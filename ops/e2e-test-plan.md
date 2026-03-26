# E2E Test Plan

**Last Updated**: 2026-03-26

## Overview

End-to-end tests verify the full deployed stack. For cmux, this means:
- **macOS**: App launch, terminal interaction, socket API, browser automation
- **Linux**: Same scenarios once cross-platform support is implemented

## Test Environment

- **macOS**: macOS 13+ with cmux built from source (tagged debug build)
- **Linux**: Ubuntu 22.04+ (planned)
- **Socket**: `/tmp/cmux-debug-<tag>.sock` for tagged builds
- **Python tests**: `tests_v2/` directory, requires `CMUX_SOCKET` env var

## Capability E2E Scenarios

### Terminal Core (TC)

| SCENARIO ID | Description | Method | Prerequisites |
|------------|-------------|--------|---------------|
| SCENARIO-TC-001 | Terminal renders keystrokes | UI automation: type characters, verify display | Running app |
| SCENARIO-TC-003 | Ghostty config applied | Launch with config, verify theme/font | Ghostty config file |

### Workspaces (WS)

| SCENARIO ID | Description | Method | Prerequisites |
|------------|-------------|--------|---------------|
| SCENARIO-WS-001 | Create new workspace | Socket API: `workspace.create`, verify sidebar | Running app + socket |
| SCENARIO-WS-003 | Workspace switching | Socket API: `workspace.select`, verify focus | Multiple workspaces |

### Browser Panels (BP)

| SCENARIO ID | Description | Method | Prerequisites |
|------------|-------------|--------|---------------|
| SCENARIO-BP-001 | Open browser in split | Socket API: browser.open + navigate | Running app + socket |
| SCENARIO-BP-003 | Browser scriptable API | Socket API: browser JS evaluation | Browser panel open |

### Socket Control (SC)

| SCENARIO ID | Description | Method | Prerequisites |
|------------|-------------|--------|---------------|
| SCENARIO-SC-001 | CLI command execution | Python: send v2 JSON-RPC, verify response | Running app + socket |
| SCENARIO-SC-003 | Authentication | Python: connect without auth, verify rejection | Socket with password |

### Notifications (NT)

| SCENARIO ID | Description | Method | Prerequisites |
|------------|-------------|--------|---------------|
| SCENARIO-NT-001 | OSC notification | Send OSC 9 sequence, verify notification store | Running terminal |
| SCENARIO-NT-003 | Jump to unread | Cmd+Shift+U after notification | Unread notification |

### Session Persistence (SPE)

| SCENARIO ID | Description | Method | Prerequisites |
|------------|-------------|--------|---------------|
| SCENARIO-SPE-001 | Layout restore | Quit + relaunch, verify workspace count/layout | Saved session |

### Remote Daemon (RD)

| SCENARIO ID | Description | Method | Prerequisites |
|------------|-------------|--------|---------------|
| SCENARIO-RD-001 | SSH workspace | `cmux ssh user@host`, verify remote workspace | SSH access |

## Existing Test Suites

- **v1 tests**: `./scripts/run-tests-v1.sh`
- **v2 tests**: `./scripts/run-tests-v2.sh`
- **E2E workflow**: `gh workflow run test-e2e.yml`
- **Unit tests**: `xcodebuild -scheme cmux-unit`

## Notes

- Never run untagged `cmux DEV.app` on development machines
- Use `CMUX_SOCKET=/tmp/cmux-debug-<tag>.sock` for Python tests
- E2E tests should run in CI (GitHub Actions) not locally
