#!/usr/bin/env bash
# E2E tests for cmux — runs in a nested Wayland compositor
# Tests: startup, typing, resize, workspace switching, persistence
# Usage: ./scripts/test-e2e.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

LOG="/tmp/cmux-linux.log"
WESTON_SOCK="cmux-e2e-$$"
PASS=0
FAIL=0
CMUX_PID=""
WESTON_PID=""

green() { printf '\033[32m  PASS: %s\033[0m\n' "$1"; }
red()   { printf '\033[31m  FAIL: %s\033[0m\n' "$1"; }
bold()  { printf '\033[1m%s\033[0m\n' "$1"; }

cleanup() {
    [ -n "$CMUX_PID" ] && kill $CMUX_PID 2>/dev/null || true
    [ -n "$WESTON_PID" ] && kill $WESTON_PID 2>/dev/null || true
    wait $CMUX_PID 2>/dev/null || true
    wait $WESTON_PID 2>/dev/null || true
    rm -f "/tmp/$WESTON_SOCK" /tmp/cmux-e2e-*.log
}
trap cleanup EXIT

assert() {
    local name="$1" got="$2" expected="$3"
    if echo "$got" | grep -q "$expected"; then
        green "$name"; PASS=$((PASS + 1))
    else
        red "$name (expected '$expected', got '$(echo "$got" | head -c 100)')"; FAIL=$((FAIL + 1))
    fi
}

assert_running() {
    if kill -0 $CMUX_PID 2>/dev/null; then
        green "$1"; PASS=$((PASS + 1))
    else
        red "$1 — process died"; FAIL=$((FAIL + 1))
    fi
}

send() { echo "$1" | socat -t 3 - UNIX-CONNECT:"$SOCK" 2>/dev/null; }

# ============================================================
bold "=== cmux E2E Test Suite ==="
echo ""

# Build
bold "Building..."
./scripts/build-linux.sh 2>&1 | tail -3
echo ""

# Start nested compositor
bold "Starting nested Wayland compositor..."
weston --backend=wayland --socket="$WESTON_SOCK" --width=1024 --height=768 2>/tmp/cmux-e2e-weston.log &
WESTON_PID=$!
sleep 2
if ! kill -0 $WESTON_PID 2>/dev/null; then
    red "Weston failed to start"
    cat /tmp/cmux-e2e-weston.log | tail -5
    exit 1
fi
echo "  Weston PID=$WESTON_PID"

# Launch cmux
bold "Launching cmux..."
rm -f "$LOG" ~/.local/share/cmux/session.json
cp Package.linux.swift Package.swift
WAYLAND_DISPLAY="$WESTON_SOCK" .build/debug/cmux-linux 2>/tmp/cmux-e2e-stderr.log &
CMUX_PID=$!
sleep 5
git checkout Package.swift 2>/dev/null || true

SOCK=$(cat /tmp/cmux-socket-path 2>/dev/null || echo "")
if [ -z "$SOCK" ] || [ ! -S "$SOCK" ]; then
    red "cmux failed to start"
    strings "$LOG" 2>/dev/null | tail -10
    cat /tmp/cmux-e2e-stderr.log 2>/dev/null | tail -10
    exit 1
fi
echo "  cmux PID=$CMUX_PID, socket=$SOCK"
echo ""

# ============================================================
bold "--- Test 1: Startup & Identity ---"
R=$(send '{"jsonrpc":"2.0","method":"system.identify","id":1}')
assert "identify returns app name" "$R" "cmux-linux"
assert "identify returns version" "$R" "0.1.0"
assert_running "process alive after identify"

# ============================================================
bold "--- Test 2: Workspace Operations ---"
R=$(send '{"jsonrpc":"2.0","method":"workspace.list","id":2}')
assert "initial workspace exists" "$R" '"id"'

send '{"jsonrpc":"2.0","method":"workspace.create","params":{"directory":"/tmp","title":"test-ws"},"id":3}' >/dev/null
sleep 2
R=$(send '{"jsonrpc":"2.0","method":"workspace.list","id":4}')
WS_COUNT=$(echo "$R" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('result',[])))" 2>/dev/null || echo 0)
assert "workspace created (count=2)" "$WS_COUNT" "2"
assert_running "process alive after create"

# Switch workspaces
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"1"},"id":5}' >/dev/null; sleep 1
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"2"},"id":6}' >/dev/null; sleep 1
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"1"},"id":7}' >/dev/null; sleep 1
assert_running "survives 3 workspace switches"

# Rapid switching
for i in 1 2 1 2 1 2 1; do
    send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"'$i'"},"id":99}' >/dev/null
    sleep 0.3
done
assert_running "survives 7 rapid switches"

# ============================================================
bold "--- Test 3: Programmatic Resize ---"
send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"600","height":"400"},"id":10}' >/dev/null
sleep 2
assert_running "survives resize to 600x400"

send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"1200","height":"800"},"id":11}' >/dev/null
sleep 2
assert_running "survives resize to 1200x800"

send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"400","height":"300"},"id":12}' >/dev/null
sleep 2
assert_running "survives resize to 400x300 (small)"

send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"900","height":"600"},"id":13}' >/dev/null
sleep 2
assert_running "survives resize back to 900x600"

# ============================================================
bold "--- Test 4: Resize + Switch Combo ---"
send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"700","height":"500"},"id":20}' >/dev/null; sleep 1
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"2"},"id":21}' >/dev/null; sleep 1
send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"900","height":"600"},"id":22}' >/dev/null; sleep 1
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"1"},"id":23}' >/dev/null; sleep 1
assert_running "survives resize+switch interleaved"

# Check workspace content preserved
R=$(send '{"jsonrpc":"2.0","method":"workspace.list","id":24}')
assert "still has 2 workspaces" "$R" '"id":"2"'

# ============================================================
bold "--- Test 5: Multiple Resizes (Simulated Drag) ---"
for size in "800x500" "810x510" "820x520" "830x530" "840x540" "850x550" "860x560" "870x570" "880x580" "890x590" "900x600"; do
    W=${size%x*}; H=${size#*x}
    send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"'$W'","height":"'$H'"},"id":99}' >/dev/null
    sleep 0.1
done
sleep 2
assert_running "survives 11 rapid resizes (simulated drag)"

# Type after rapid resize
send '{"jsonrpc":"2.0","method":"surface.send_text","params":{"text":"echo RESIZE_TEST\n"},"id":30}' >/dev/null
sleep 2
assert_running "survives typing after rapid resize"

# ============================================================
bold "--- Test 6: Notifications ---"
R=$(send '{"jsonrpc":"2.0","method":"notify","params":{"title":"E2E","body":"Test notification"},"id":40}')
assert "notify returns ok" "$R" '"ok":"true"'

# ============================================================
bold "--- Test 7: Close Workspace ---"
send '{"jsonrpc":"2.0","method":"workspace.close","id":50}' >/dev/null; sleep 1
R=$(send '{"jsonrpc":"2.0","method":"workspace.list","id":51}')
WS_COUNT=$(echo "$R" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('result',[])))" 2>/dev/null || echo 0)
assert "workspace closed (count=1)" "$WS_COUNT" "1"
assert_running "survives workspace close"

# ============================================================
bold "--- Test 8: Resize After Close ---"
send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"1000","height":"700"},"id":60}' >/dev/null
sleep 2
assert_running "survives resize after workspace close"

# ============================================================
bold "--- Test 9: Status ---"
R=$(send '{"jsonrpc":"2.0","method":"system.status","id":70}')
assert "status returns workspaces" "$R" '"workspaces"'
assert "status returns socket" "$R" '"socket"'

# ============================================================
bold "--- Test 10: Session Persistence ---"
# Session should have been saved
sleep 2
if [ -f ~/.local/share/cmux/session.json ]; then
    green "session file exists"
    PASS=$((PASS + 1))
else
    red "session file missing"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
bold "=== Log Summary ==="
KEYS=$(strings "$LOG" 2>/dev/null | grep -c "\[key\].*handled=true" || echo 0)
SURFACES=$(strings "$LOG" 2>/dev/null | grep -c "Surface created" || echo 0)
SWITCHES=$(strings "$LOG" 2>/dev/null | grep -c "Switched" || echo 0)
RESIZES=$(strings "$LOG" 2>/dev/null | grep -c "\[resize\]" || echo 0)
echo "  Keys handled: $KEYS"
echo "  Surfaces created: $SURFACES"
echo "  Workspace switches: $SWITCHES"
echo "  Resize events: $RESIZES"

echo ""
bold "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -eq 0 ]; then
    printf '\033[32m%s\033[0m\n' "ALL TESTS PASSED"
else
    printf '\033[31m%s\033[0m\n' "SOME TESTS FAILED"
fi
exit $FAIL
