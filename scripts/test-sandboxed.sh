#!/usr/bin/env bash
# Sandboxed cmux testing — runs in a nested Wayland compositor (weston)
# No keystrokes leak to other applications
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

LOG="/tmp/cmux-linux.log"
PASS=0
FAIL=0

green() { printf '\033[32m%s\033[0m\n' "$1"; }
red() { printf '\033[31m%s\033[0m\n' "$1"; }

cleanup() {
    kill $CMUX_PID 2>/dev/null || true
    kill $WESTON_PID 2>/dev/null || true
    wait $CMUX_PID 2>/dev/null || true
    wait $WESTON_PID 2>/dev/null || true
    rm -f /tmp/cmux-test-wayland
}
trap cleanup EXIT

# Start nested weston compositor
echo "=== Starting nested Wayland compositor ==="
WESTON_SOCK="/tmp/cmux-test-wayland"
weston --backend=wayland --socket="$WESTON_SOCK" --width=1024 --height=768 &
WESTON_PID=$!
sleep 2

# Build
echo "=== Building ==="
./scripts/build-linux.sh 2>&1 | tail -3

# Launch cmux inside the nested compositor
echo "=== Launching cmux in sandbox ==="
rm -f "$LOG" ~/.local/share/cmux/session.json
cp Package.linux.swift Package.swift
WAYLAND_DISPLAY="$WESTON_SOCK" .build/debug/cmux-linux > /dev/null 2>&1 &
CMUX_PID=$!
sleep 5

SOCK=$(cat /tmp/cmux-socket-path 2>/dev/null || echo "")
if [ -z "$SOCK" ] || [ ! -S "$SOCK" ]; then
    red "FAIL: cmux did not start"
    strings "$LOG" | tail -10
    exit 1
fi
green "cmux running (PID=$CMUX_PID)"

send() { echo "$1" | socat -t 2 - UNIX-CONNECT:"$SOCK" 2>/dev/null; }

assert() {
    local name="$1" got="$2" expected="$3"
    if echo "$got" | grep -q "$expected"; then
        green "  PASS: $name"
        PASS=$((PASS + 1))
    else
        red "  FAIL: $name"
        red "    expected: $expected"
        red "    got: $got"
        FAIL=$((FAIL + 1))
    fi
}

# === Socket API tests (no keystrokes needed) ===

echo ""
echo "=== TEST 1: identify ==="
R=$(send '{"jsonrpc":"2.0","method":"system.identify","id":1}')
assert "returns app name" "$R" "cmux-linux"

echo ""
echo "=== TEST 2: workspace list ==="
R=$(send '{"jsonrpc":"2.0","method":"workspace.list","id":2}')
assert "has workspace 1" "$R" '"id":"1"'

echo ""
echo "=== TEST 3: create workspace ==="
send '{"jsonrpc":"2.0","method":"workspace.create","id":3}' > /dev/null
sleep 2
R=$(send '{"jsonrpc":"2.0","method":"workspace.list","id":4}')
assert "has workspace 2" "$R" '"id":"2"'

echo ""
echo "=== TEST 4: switch workspaces ==="
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"1"},"id":5}' > /dev/null
sleep 1
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"2"},"id":6}' > /dev/null
sleep 1
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"1"},"id":7}' > /dev/null
sleep 1
assert "still running" "$(kill -0 $CMUX_PID 2>&1 && echo yes || echo no)" "yes"

echo ""
echo "=== TEST 5: programmatic resize ==="
send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"600","height":"400"},"id":8}' > /dev/null
sleep 2
assert "still running after resize" "$(kill -0 $CMUX_PID 2>&1 && echo yes || echo no)" "yes"

send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"900","height":"600"},"id":9}' > /dev/null
sleep 2
assert "still running after second resize" "$(kill -0 $CMUX_PID 2>&1 && echo yes || echo no)" "yes"

echo ""
echo "=== TEST 6: resize + switch ==="
send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"700","height":"500"},"id":10}' > /dev/null
sleep 1
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"2"},"id":11}' > /dev/null
sleep 1
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"1"},"id":12}' > /dev/null
sleep 1
assert "survives resize+switch" "$(kill -0 $CMUX_PID 2>&1 && echo yes || echo no)" "yes"

echo ""
echo "=== TEST 7: notify ==="
R=$(send '{"jsonrpc":"2.0","method":"notify","params":{"title":"Test","body":"OK"},"id":13}')
assert "notify ok" "$R" '"ok":"true"'

echo ""
echo "=== TEST 8: close workspace ==="
send '{"jsonrpc":"2.0","method":"workspace.close","id":14}' > /dev/null
sleep 1
R=$(send '{"jsonrpc":"2.0","method":"workspace.list","id":15}')
assert "down to 1 workspace" "$R" '"id":"1"'
N=$(echo "$R" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['result']))" 2>/dev/null || echo "?")
assert "exactly 1 workspace" "$N" "1"

echo ""
echo "=== RESULTS: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && green "ALL TESTS PASSED" || red "SOME TESTS FAILED"

echo ""
echo "=== Log summary ==="
KEYS=$(strings "$LOG" | grep -c "\[key\].*handled=true" 2>/dev/null || echo 0)
SURFACES=$(strings "$LOG" | grep -c "Surface created" 2>/dev/null || echo 0)
SWITCHES=$(strings "$LOG" | grep -c "Switched" 2>/dev/null || echo 0)
echo "  Keys handled: $KEYS"
echo "  Surfaces: $SURFACES"
echo "  Switches: $SWITCHES"

git checkout Package.swift 2>/dev/null || true
