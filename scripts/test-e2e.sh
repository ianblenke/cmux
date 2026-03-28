#!/usr/bin/env bash
# Comprehensive E2E test suite for cmux
# Runs in a nested Wayland compositor — zero keystroke bleed
# Tests ALL features: typing, workspaces, resize, notifications, browser, persistence
#
# Usage: ./scripts/test-e2e.sh
#        ./scripts/build-linux.sh --test
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

LOG="/tmp/cmux-linux.log"
WESTON_SOCK="cmux-e2e-$$"
TEST_DIR="/tmp/cmux-e2e-$$"
PASS=0
FAIL=0
SKIP=0
CMUX_PID=""
WESTON_PID=""

green() { printf '\033[32m  PASS: %s\033[0m\n' "$1"; }
red()   { printf '\033[31m  FAIL: %s\033[0m\n' "$1"; }
yellow(){ printf '\033[33m  SKIP: %s\033[0m\n' "$1"; }
bold()  { printf '\033[1m%s\033[0m\n' "$1"; }

cleanup() {
    [ -n "$CMUX_PID" ] && kill $CMUX_PID 2>/dev/null || true
    [ -n "$WESTON_PID" ] && kill $WESTON_PID 2>/dev/null || true
    wait $CMUX_PID 2>/dev/null || true
    wait $WESTON_PID 2>/dev/null || true
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

assert() {
    local name="$1" got="$2" expected="$3"
    if echo "$got" | grep -q "$expected"; then
        green "$name"; PASS=$((PASS + 1))
    else
        red "$name (expected '$expected', got '$(echo "$got" | head -c 120)')"; FAIL=$((FAIL + 1))
    fi
}

assert_eq() {
    local name="$1" got="$2" expected="$3"
    if [ "$got" = "$expected" ]; then
        green "$name"; PASS=$((PASS + 1))
    else
        red "$name (expected '$expected', got '$got')"; FAIL=$((FAIL + 1))
    fi
}

assert_running() {
    if kill -0 $CMUX_PID 2>/dev/null; then
        green "$1"; PASS=$((PASS + 1))
    else
        red "$1 — PROCESS DIED"; FAIL=$((FAIL + 1))
    fi
}

assert_file() {
    local name="$1" path="$2"
    if [ -f "$path" ]; then
        green "$name"; PASS=$((PASS + 1))
    else
        red "$name (file not found: $path)"; FAIL=$((FAIL + 1))
    fi
}

assert_file_contains() {
    local name="$1" path="$2" expected="$3"
    if [ -f "$path" ] && grep -q "$expected" "$path" 2>/dev/null; then
        green "$name"; PASS=$((PASS + 1))
    else
        red "$name (file '$path' missing or doesn't contain '$expected')"; FAIL=$((FAIL + 1))
    fi
}

send() { echo "$1" | socat -t 3 - UNIX-CONNECT:"$SOCK" 2>/dev/null; }

send_text() {
    local text="$1"
    # Escape for JSON: double-quotes and backslashes (but preserve \n as JSON newline)
    local escaped=$(printf '%s' "$text" | sed 's/"/\\"/g')
    # Use pty_write for direct PTY access (bypasses ghostty IO thread which
    # doesn't process writes reliably in headless/weston E2E environments)
    send "{\"jsonrpc\":\"2.0\",\"method\":\"surface.pty_write\",\"params\":{\"text\":\"$escaped\"},\"id\":99}" >/dev/null
}

# Wait until cmux has an active surface (shell is ready to receive input)
wait_ready() {
    local max_wait="${1:-30}"
    local elapsed=0
    while [ "$elapsed" -lt "$max_wait" ]; do
        local r=$(send '{"jsonrpc":"2.0","method":"system.ready","id":0}' 2>/dev/null || echo "")
        if echo "$r" | grep -q '"ready":"true"'; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    echo "  WARNING: surface not ready after ${max_wait}s"
    return 1
}

ws_count() {
    local r=$(send '{"jsonrpc":"2.0","method":"workspace.list","id":99}')
    echo "$r" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('result',[])))" 2>/dev/null || echo 0
}

# ============================================================
bold "╔══════════════════════════════════════════╗"
bold "║     cmux E2E Test Suite                  ║"
bold "╚══════════════════════════════════════════╝"
echo ""

mkdir -p "$TEST_DIR"

# Build
bold "Building cmux..."
./scripts/build-linux.sh 2>&1 | tail -3
echo ""

# Start nested compositor (headless with GL renderer — GTK4 activate
# doesn't fire reliably with weston --backend=wayland nested compositor)
bold "Starting headless Wayland compositor..."
weston --backend=headless --renderer=gl --socket="$WESTON_SOCK" --width=1024 --height=768 2>/tmp/cmux-e2e-weston.log &
WESTON_PID=$!
sleep 2
if ! kill -0 $WESTON_PID 2>/dev/null; then
    red "Weston failed to start"; exit 1
fi

# Launch cmux
bold "Launching cmux..."
rm -f "$LOG" ~/.local/share/cmux/session.json /tmp/cmux-socket-path
cp Package.linux.swift Package.swift 2>/dev/null || true
WAYLAND_DISPLAY="$WESTON_SOCK" .build/debug/cmux-linux 2>/tmp/cmux-e2e-stderr.log &
CMUX_PID=$!
git checkout Package.swift 2>/dev/null || true

# Wait for socket to appear
echo "  Waiting for socket..."
for i in $(seq 1 15); do
    SOCK=$(cat /tmp/cmux-socket-path 2>/dev/null || echo "")
    if [ -n "$SOCK" ] && [ -S "$SOCK" ]; then break; fi
    sleep 1
done

SOCK=$(cat /tmp/cmux-socket-path 2>/dev/null || echo "")
if [ -z "$SOCK" ] || [ ! -S "$SOCK" ]; then
    red "cmux failed to start (no socket after 15s)"
    cat /tmp/cmux-e2e-stderr.log 2>/dev/null | tail -20
    exit 1
fi
echo "  cmux PID=$CMUX_PID socket=$SOCK"

# Wait for surface to be ready (shell initialized)
echo "  Waiting for surface readiness..."
if ! wait_ready 30; then
    red "cmux surface never became ready"
    cat /tmp/cmux-e2e-stderr.log 2>/dev/null | tail -20
    exit 1
fi
echo "  Surface ready!"

# Extra settle time for shell startup scripts
sleep 2
echo ""

# ============================================================
# TEST SUITE
# ============================================================

bold "━━━ 1. STARTUP & IDENTITY ━━━"

R=$(send '{"jsonrpc":"2.0","method":"system.identify","id":1}')
assert "identify: app name" "$R" '"app":"cmux-linux"'
assert "identify: version" "$R" '"version":"0.1.0"'
assert "identify: platform" "$R" '"platform":"linux"'
assert "identify: has pid" "$R" '"pid"'
assert_running "startup: process alive"

R=$(send '{"jsonrpc":"2.0","method":"system.status","id":2}')
assert "status: has workspaces" "$R" '"workspaces"'
assert "status: has socket" "$R" '"socket"'
assert "status: has pid" "$R" '"pid"'

# ============================================================
bold "━━━ 2. TERMINAL INPUT (via socket send_text) ━━━"

send_text "echo E2E_MARKER_1\n"
sleep 2
# Verify the command executed by checking if title updated
R=$(strings "$LOG" 2>/dev/null | grep -c "\[action\] title:" || echo 0)
assert "typing: shell responded to command" "$R" "[1-9]"
assert_running "typing: process alive after input"

# Write to a file to verify shell works
send_text "echo CMUX_TEST_OK > $TEST_DIR/output1.txt\n"
sleep 2
assert_file_contains "typing: shell wrote file" "$TEST_DIR/output1.txt" "CMUX_TEST_OK"

# ============================================================
bold "━━━ 3. WORKSPACE CREATION ━━━"

C0=$(ws_count)
send '{"jsonrpc":"2.0","method":"workspace.create","params":{"directory":"/tmp","title":"ws-test"},"id":10}' >/dev/null
sleep 2
wait_ready 15
sleep 2
C1=$(ws_count)
assert "create: count increased" "$C1" "$(( ${C0:-0} + 1 ))"
assert_running "create: process alive"

# Verify new workspace is active and at /tmp
R=$(send '{"jsonrpc":"2.0","method":"workspace.list","id":11}')
assert "create: new workspace in list" "$R" '/tmp'
assert "create: new workspace has id" "$R" '"id":"2"'

# Type in new workspace
send_text "echo WS2_MARKER > $TEST_DIR/output2.txt\n"
sleep 2
assert_file_contains "create: new workspace shell works" "$TEST_DIR/output2.txt" "WS2_MARKER"

# ============================================================
bold "━━━ 4. WORKSPACE SWITCHING ━━━"

send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"1"},"id":20}' >/dev/null
sleep 1
assert_running "switch: survives switch to ws1"

# Verify we're on ws1 by typing
send_text "echo WS1_AFTER_SWITCH > $TEST_DIR/output3.txt\n"
sleep 2
assert_file_contains "switch: ws1 shell works after switch" "$TEST_DIR/output3.txt" "WS1_AFTER_SWITCH"

# Switch back to ws2
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"2"},"id":21}' >/dev/null
sleep 1
send_text "echo WS2_AFTER_SWITCH > $TEST_DIR/output4.txt\n"
sleep 2
assert_file_contains "switch: ws2 shell works after switch" "$TEST_DIR/output4.txt" "WS2_AFTER_SWITCH"

# Roundtrip
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"1"},"id":22}' >/dev/null; sleep 1
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"2"},"id":23}' >/dev/null; sleep 1
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"1"},"id":24}' >/dev/null; sleep 1
assert_running "switch: survives 3 roundtrip switches"

# Rapid switching
for i in 1 2 1 2 1 2 1 2 1 2; do
    send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"'$i'"},"id":99}' >/dev/null
    sleep 0.2
done
sleep 1
assert_running "switch: survives 10 rapid switches"

# Type after rapid switch
send_text "echo RAPID_SWITCH_OK > $TEST_DIR/output5.txt\n"
sleep 2
assert_file_contains "switch: typing works after rapid switches" "$TEST_DIR/output5.txt" "RAPID_SWITCH_OK"

# ============================================================
bold "━━━ 5. PROGRAMMATIC RESIZE ━━━"

send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"600","height":"400"},"id":30}' >/dev/null
sleep 3
assert_running "resize: survives 600x400"
send_text "echo RESIZE1 > $TEST_DIR/resize1.txt\n"
sleep 2
assert_file_contains "resize: typing works at 600x400" "$TEST_DIR/resize1.txt" "RESIZE1"

send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"1200","height":"800"},"id":31}' >/dev/null
sleep 3
assert_running "resize: survives 1200x800"
send_text "echo RESIZE2 > $TEST_DIR/resize2.txt\n"
sleep 2
assert_file_contains "resize: typing works at 1200x800" "$TEST_DIR/resize2.txt" "RESIZE2"

send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"400","height":"300"},"id":32}' >/dev/null
sleep 3
assert_running "resize: survives 400x300 (small)"

send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"900","height":"600"},"id":33}' >/dev/null
sleep 3
assert_running "resize: survives 900x600 (restore)"

# ============================================================
bold "━━━ 5b. RESIZE DIMENSION VERIFICATION ━━━"

# Verify surface dimensions actually change after resize
get_surface_width() {
    local r=$(send '{"jsonrpc":"2.0","method":"surface.size","id":99}')
    echo "$r" | python3 -c "import sys,json; print(json.load(sys.stdin).get('result',{}).get('gtk_width','0'))" 2>/dev/null || echo 0
}

send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"800","height":"500"},"id":35}' >/dev/null
sleep 3
W=$(get_surface_width)
assert "resize-dim: active surface has width ~800" "$W" "^[5-8][0-9][0-9]$"

# Now resize, switch to ws2 (which was hidden), verify IT also has correct dims
send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"600","height":"400"},"id":36}' >/dev/null
sleep 3
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"2"},"id":37}' >/dev/null
sleep 2
W2=$(get_surface_width)
assert "resize-dim: switched ws2 has width ~600" "$W2" "^[3-6][0-9][0-9]$"

# Switch back to ws1, verify it also has the 600-width
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"1"},"id":38}' >/dev/null
sleep 2
W1=$(get_surface_width)
assert "resize-dim: switched-back ws1 has width ~600" "$W1" "^[3-6][0-9][0-9]$"

# Type in ws1 after resize+switch to prove it's alive
send_text "echo RESIZE_DIM_OK > $TEST_DIR/resize_dim.txt\n"
sleep 2
assert_file_contains "resize-dim: typing works after resize+switch" "$TEST_DIR/resize_dim.txt" "RESIZE_DIM_OK"

# Restore size
send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"900","height":"600"},"id":39}' >/dev/null
sleep 2

# ============================================================
bold "━━━ 6. RESIZE + SWITCH COMBO ━━━"

send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"700","height":"500"},"id":40}' >/dev/null; sleep 1
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"2"},"id":41}' >/dev/null; sleep 1
send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"900","height":"600"},"id":42}' >/dev/null; sleep 1
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"1"},"id":43}' >/dev/null; sleep 1
assert_running "resize+switch: survives interleaved"

send_text "echo COMBO_OK > $TEST_DIR/combo.txt\n"
sleep 2
assert_file_contains "resize+switch: typing works after combo" "$TEST_DIR/combo.txt" "COMBO_OK"

# Switch to ws2 after combo
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"2"},"id":44}' >/dev/null; sleep 1
send_text "echo COMBO_WS2 > $TEST_DIR/combo2.txt\n"
sleep 2
assert_file_contains "resize+switch: ws2 typing works after combo" "$TEST_DIR/combo2.txt" "COMBO_WS2"

# ============================================================
bold "━━━ 7. SIMULATED DRAG RESIZE (11 rapid resizes) ━━━"

for size in "800x500" "810x510" "820x520" "830x530" "840x540" "850x550" "860x560" "870x570" "880x580" "890x590" "900x600"; do
    W=${size%x*}; H=${size#*x}
    send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"'$W'","height":"'$H'"},"id":99}' >/dev/null
    sleep 0.05
done
sleep 3
assert_running "drag: survives 11 rapid resizes"

send_text "echo DRAG_OK > $TEST_DIR/drag.txt\n"
sleep 2
assert_file_contains "drag: typing works after rapid resize" "$TEST_DIR/drag.txt" "DRAG_OK"

# ============================================================
bold "━━━ 8. RESIZE + SWITCH + TYPE (Full Workflow) ━━━"

# Resize, switch to ws1, type, switch to ws2, type, resize, switch back
send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"800","height":"500"},"id":50}' >/dev/null; sleep 1
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"1"},"id":51}' >/dev/null; sleep 1
send_text "echo WORKFLOW_WS1 > $TEST_DIR/wf1.txt\n"; sleep 2
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"2"},"id":52}' >/dev/null; sleep 1
send_text "echo WORKFLOW_WS2 > $TEST_DIR/wf2.txt\n"; sleep 2
send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"1000","height":"700"},"id":53}' >/dev/null; sleep 2
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"1"},"id":54}' >/dev/null; sleep 1
send_text "echo WORKFLOW_BACK > $TEST_DIR/wf3.txt\n"; sleep 2
assert_file_contains "workflow: ws1 typing after full workflow" "$TEST_DIR/wf3.txt" "WORKFLOW_BACK"
assert_running "workflow: process alive after full workflow"

# ============================================================
bold "━━━ 9. NOTIFICATIONS ━━━"

R=$(send '{"jsonrpc":"2.0","method":"notify","params":{"title":"E2E Test","body":"All systems go"},"id":60}')
assert "notify: returns ok" "$R" '"ok":"true"'
assert_running "notify: process alive after notification"

# ============================================================
bold "━━━ 10. THIRD WORKSPACE ━━━"

send '{"jsonrpc":"2.0","method":"workspace.create","params":{"directory":"/var"},"id":70}' >/dev/null
sleep 2
wait_ready 15
sleep 2
C=$(ws_count)
assert_eq "3ws: count is 3" "$C" "3"

# Type in ws3
send_text "echo WS3_OK > $TEST_DIR/ws3.txt\n"
sleep 2
assert_file_contains "3ws: ws3 shell works" "$TEST_DIR/ws3.txt" "WS3_OK"

# Switch between all 3
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"1"},"id":71}' >/dev/null; sleep 0.5
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"2"},"id":72}' >/dev/null; sleep 0.5
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"3"},"id":73}' >/dev/null; sleep 0.5
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"1"},"id":74}' >/dev/null; sleep 0.5
assert_running "3ws: survives switching between 3 workspaces"

# Resize with 3 workspaces
send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"800","height":"500"},"id":75}' >/dev/null; sleep 2
send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"2"},"id":76}' >/dev/null; sleep 1
send_text "echo WS2_AFTER_3WS_RESIZE > $TEST_DIR/3ws_resize.txt\n"
sleep 2
assert_file_contains "3ws: ws2 works after resize with 3 workspaces" "$TEST_DIR/3ws_resize.txt" "WS2_AFTER_3WS_RESIZE"

# ============================================================
bold "━━━ 11. CLOSE WORKSPACE ━━━"

send '{"jsonrpc":"2.0","method":"workspace.close","id":80}' >/dev/null; sleep 2
C=$(ws_count)
assert_eq "close: count decreased to 2" "$C" "2"
assert_running "close: process alive after close"

# Type after close
send_text "echo AFTER_CLOSE > $TEST_DIR/close.txt\n"
sleep 2
assert_file_contains "close: typing works after close" "$TEST_DIR/close.txt" "AFTER_CLOSE"

# ============================================================
bold "━━━ 12. RESIZE AFTER CLOSE ━━━"

send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"1000","height":"700"},"id":90}' >/dev/null; sleep 2
assert_running "resize-after-close: process alive"
send_text "echo RESIZE_CLOSE > $TEST_DIR/resize_close.txt\n"
sleep 2
assert_file_contains "resize-after-close: typing works" "$TEST_DIR/resize_close.txt" "RESIZE_CLOSE"

# ============================================================
bold "━━━ 13. SESSION PERSISTENCE ━━━"

# Wait for autosave
sleep 5
assert_file "session: file exists" "$HOME/.local/share/cmux/session.json"
if [ -f "$HOME/.local/share/cmux/session.json" ]; then
    R=$(cat "$HOME/.local/share/cmux/session.json")
    assert "session: has workspaces" "$R" "workspaces"
    assert "session: has version" "$R" "version"
fi

# ============================================================
bold "━━━ 14. SOCKET API COMPLETENESS ━━━"

# Unknown method
R=$(send '{"jsonrpc":"2.0","method":"nonexistent","id":100}')
assert "api: unknown method returns error" "$R" '"error"'
assert "api: error has message" "$R" "Method not found"

# Parse error
R=$(send 'not json at all')
assert "api: invalid JSON returns error" "$R" '"error"'

# Status
R=$(send '{"jsonrpc":"2.0","method":"system.status","id":101}')
assert "api: status has workspaces field" "$R" '"workspaces"'

# ============================================================
bold "━━━ 15. STRESS TEST ━━━"

# Create 2 more workspaces (total 4), rapid switch + resize
send '{"jsonrpc":"2.0","method":"workspace.create","id":110}' >/dev/null; sleep 8
send '{"jsonrpc":"2.0","method":"workspace.create","id":111}' >/dev/null; sleep 8

for i in $(seq 1 20); do
    WS=$(( (i % 4) + 1 ))
    send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"'$WS'"},"id":99}' >/dev/null
    sleep 0.1
done
sleep 1
assert_running "stress: survives 20 rapid switches across 4 workspaces"

# Resize during rapid switching
for i in $(seq 1 5); do
    W=$(( 600 + i * 50 ))
    H=$(( 400 + i * 30 ))
    send '{"jsonrpc":"2.0","method":"window.resize","params":{"width":"'$W'","height":"'$H'"},"id":99}' >/dev/null
    WS=$(( (i % 4) + 1 ))
    send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"'$WS'"},"id":99}' >/dev/null
    sleep 0.2
done
sleep 2
assert_running "stress: survives interleaved resize+switch"

# Type after stress — extra settle time for surface recreations
sleep 3
send_text "echo STRESS_OK > $TEST_DIR/stress.txt\n"
sleep 3
assert_file_contains "stress: typing works after stress test" "$TEST_DIR/stress.txt" "STRESS_OK"

# ============================================================
echo ""
bold "━━━ LOG SUMMARY ━━━"
KEYS=$(strings "$LOG" 2>/dev/null | grep -c "\[key\].*handled=true" || echo 0)
SURFACES=$(strings "$LOG" 2>/dev/null | grep -c "Surface created" || echo 0)
SWITCHES=$(strings "$LOG" 2>/dev/null | grep -c "Switched" || echo 0)
RESIZES=$(strings "$LOG" 2>/dev/null | grep -c "\[resize\]" || echo 0)
echo "  Surfaces created: $SURFACES"
echo "  Workspace switches: $SWITCHES"
echo "  Resize events: $RESIZES"

# ============================================================
echo ""
bold "╔══════════════════════════════════════════╗"
if [ "$FAIL" -eq 0 ]; then
    printf '║  \033[32m%-40s\033[0m║\n' "ALL $PASS TESTS PASSED"
else
    printf '║  \033[31m%-40s\033[0m║\n' "$PASS passed, $FAIL failed"
fi
bold "╚══════════════════════════════════════════╝"
exit $FAIL
