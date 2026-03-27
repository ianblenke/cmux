#!/usr/bin/env bash
# Automated tests for the cmux socket API
# Usage: ./scripts/test-socket-api.sh
# Requires: socat, a running cmux-linux instance
set -euo pipefail

SOCK_PATH="${CMUX_SOCKET:-$(cat /tmp/cmux-socket-path 2>/dev/null || echo "")}"
PASS=0
FAIL=0

red() { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }

send() {
    echo "$1" | socat -t 2 - UNIX-CONNECT:"$SOCK_PATH" 2>/dev/null
}

assert_contains() {
    local test_name="$1"
    local response="$2"
    local expected="$3"
    if echo "$response" | grep -q "$expected"; then
        green "  PASS: $test_name"
        PASS=$((PASS + 1))
    else
        red "  FAIL: $test_name (expected '$expected' in response)"
        red "        got: $response"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== cmux Socket API Tests ==="
echo "Socket: $SOCK_PATH"
echo ""

if [ -z "$SOCK_PATH" ] || [ ! -S "$SOCK_PATH" ]; then
    red "ERROR: No running cmux instance found."
    red "Start cmux-linux first, then run this test."
    exit 1
fi

# Test 1: system.identify
echo "1. system.identify"
R=$(send '{"jsonrpc":"2.0","method":"system.identify","id":1}')
assert_contains "returns app name" "$R" '"app":"cmux-linux"'
assert_contains "returns version" "$R" '"version"'
assert_contains "returns platform" "$R" '"platform":"linux"'
assert_contains "returns pid" "$R" '"pid"'

# Test 2: system.status
echo "2. system.status"
R=$(send '{"jsonrpc":"2.0","method":"system.status","id":2}')
assert_contains "returns workspaces count" "$R" '"workspaces"'
assert_contains "returns socket path" "$R" '"socket"'

# Test 3: workspace.list
echo "3. workspace.list"
R=$(send '{"jsonrpc":"2.0","method":"workspace.list","id":3}')
assert_contains "returns array" "$R" '"result":\['
assert_contains "has id field" "$R" '"id"'

# Test 4: workspace.create
echo "4. workspace.create"
R=$(send '{"jsonrpc":"2.0","method":"workspace.create","params":{"directory":"/tmp","title":"test-ws"},"id":4}')
assert_contains "returns ok" "$R" '"ok":"true"'
sleep 1

# Test 5: workspace.list (should have more workspaces now)
echo "5. workspace.list (after create)"
R=$(send '{"jsonrpc":"2.0","method":"workspace.list","id":5}')
assert_contains "has test workspace" "$R" '/tmp'

# Test 6: workspace.select
echo "6. workspace.select"
R=$(send '{"jsonrpc":"2.0","method":"workspace.select","params":{"index":"1"},"id":6}')
assert_contains "returns ok" "$R" '"ok":"true"'

# Test 7: notify
echo "7. notify"
R=$(send '{"jsonrpc":"2.0","method":"notify","params":{"title":"Test","body":"Automated test"},"id":7}')
assert_contains "returns ok" "$R" '"ok":"true"'

# Test 8: workspace.close (close the test workspace)
echo "8. workspace.close"
R=$(send '{"jsonrpc":"2.0","method":"workspace.close","id":8}')
assert_contains "returns ok" "$R" '"ok":"true"'

# Test 9: unknown method
echo "9. unknown method"
R=$(send '{"jsonrpc":"2.0","method":"nonexistent","id":9}')
assert_contains "returns error" "$R" '"error"'
assert_contains "method not found" "$R" 'Method not found'

# Test 10: parse error
echo "10. parse error"
R=$(send 'not json')
assert_contains "returns parse error" "$R" '"error"'

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
    red "SOME TESTS FAILED"
    exit 1
else
    green "ALL TESTS PASSED"
fi
