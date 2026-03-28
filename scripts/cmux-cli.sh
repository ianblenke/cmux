#!/usr/bin/env bash
# cmux CLI — control cmux-linux via the Unix socket API
# Usage: cmux <command> [args...]
set -euo pipefail

CMD="${1:-help}"

# Help doesn't need a running instance
if [ "$CMD" = "help" ] || [ "$CMD" = "--help" ] || [ "$CMD" = "-h" ]; then
    cat <<'HELPTEXT'
cmux — control cmux-linux via socket API

Commands:
  cmux status                Show comprehensive app status
  cmux identify              Show app info (version, pid)
  cmux list                  List all workspaces
  cmux surfaces              List all surfaces
  cmux current               Show current workspace details
  cmux new [dir] [title]     Create new workspace
  cmux select <index>        Switch to workspace (1-based)
  cmux next / prev / last    Navigate workspaces
  cmux close                 Close active workspace
  cmux rename <title>        Rename active workspace
  cmux reorder <from> <to>   Reorder workspace positions
  cmux split [h|v]           Split pane (horizontal/vertical)
  cmux send <text>           Send text to active terminal
  cmux read                  Read terminal text (visible content)
  cmux clear-history         Clear terminal scrollback
  cmux browser [url]         Open browser in split
  cmux navigate <url>        Navigate browser to URL
  cmux eval <javascript>     Execute JS in browser
  cmux snapshot              Get browser DOM snapshot (for agents)
  cmux notify <title> [body] Send notification
  cmux notifications         List notifications
  cmux clear-notifications   Clear all notifications
  cmux ping                  Ping cmux (heartbeat)
  cmux caps                  List all supported commands
  cmux tree                  Show workspace/surface tree

Environment:
  CMUX_SOCKET    Path to cmux Unix socket (auto-detected)

Examples:
  cmux new /home/user/project "my-project"
  cmux notify "Claude" "Build succeeded"
  cmux split vertical
  cmux send "ls -la\n"
  cmux select 2
  cmux next
  cmux read
  cmux rename "my-workspace"
  cmux caps
HELPTEXT
    exit 0
fi

SOCK_PATH="${CMUX_SOCKET:-$(cat /tmp/cmux-socket-path 2>/dev/null || echo "")}"

if [ -z "$SOCK_PATH" ] || [ ! -S "$SOCK_PATH" ]; then
    echo "cmux: no running instance found" >&2
    echo "  Start cmux-linux first, or set CMUX_SOCKET=/path/to/sock" >&2
    exit 1
fi

send() {
    echo "$1" | socat -t 2 - UNIX-CONNECT:"$SOCK_PATH" 2>/dev/null
}

shift 2>/dev/null || true

case "$CMD" in
    status)
        send '{"jsonrpc":"2.0","method":"system.status","id":1}' | python3 -c "
import sys, json
d = json.load(sys.stdin).get('result', {})
print(f\"Workspaces: {d.get('workspaces', '?')}\")
print(f\"Active: {d.get('active_title', '?')}\")
print(f\"CWD: {d.get('active_cwd', '?')}\")
if d.get('active_branch'): print(f\"Branch: {d.get('active_branch')}\")
print(f\"Browser: {'open' if d.get('has_browser') == 'true' else 'none'}\")
print(f\"Socket: {d.get('socket', '?')}\")
print(f\"PID: {d.get('pid', '?')}\")
" 2>/dev/null || send '{"jsonrpc":"2.0","method":"system.status","id":1}'
        ;;

    snapshot)
        send '{"jsonrpc":"2.0","method":"browser.snapshot","id":1}'
        ;;

    identify|id)
        send '{"jsonrpc":"2.0","method":"system.identify","id":1}'
        ;;

    list|ls)
        send '{"jsonrpc":"2.0","method":"workspace.list","id":1}' | python3 -c "
import sys, json
data = json.load(sys.stdin)
for ws in data.get('result', []):
    marker = '▸' if ws.get('active') == 'true' else ' '
    unread = ' *' if ws.get('hasUnread') == 'true' else ''
    print(f\"{marker} {ws['id']}: {ws.get('title', '?')}{unread}\")
" 2>/dev/null || send '{"jsonrpc":"2.0","method":"workspace.list","id":1}'
        ;;

    new|create)
        DIR="${1:-}"
        TITLE="${2:-}"
        PARAMS=""
        [ -n "$DIR" ] && PARAMS="\"directory\":\"$DIR\""
        [ -n "$TITLE" ] && { [ -n "$PARAMS" ] && PARAMS="$PARAMS,"; PARAMS="${PARAMS}\"title\":\"$TITLE\""; }
        send "{\"jsonrpc\":\"2.0\",\"method\":\"workspace.create\",\"params\":{$PARAMS},\"id\":1}"
        ;;

    select|switch)
        INDEX="${1:?Usage: cmux select <index>}"
        send "{\"jsonrpc\":\"2.0\",\"method\":\"workspace.select\",\"params\":{\"index\":\"$INDEX\"},\"id\":1}"
        ;;

    close)
        send '{"jsonrpc":"2.0","method":"workspace.close","id":1}'
        ;;

    split)
        ORIENT="${1:-horizontal}"
        send "{\"jsonrpc\":\"2.0\",\"method\":\"workspace.split\",\"params\":{\"orientation\":\"$ORIENT\"},\"id\":1}"
        ;;

    send|type)
        TEXT="${1:?Usage: cmux send <text>}"
        # Escape quotes for JSON
        TEXT=$(echo "$TEXT" | sed 's/\\/\\\\/g; s/"/\\"/g')
        send "{\"jsonrpc\":\"2.0\",\"method\":\"surface.send_text\",\"params\":{\"text\":\"$TEXT\"},\"id\":1}"
        ;;

    browser|browse|open)
        URL="${1:-https://google.com}"
        send "{\"jsonrpc\":\"2.0\",\"method\":\"browser.open\",\"params\":{\"url\":\"$URL\"},\"id\":1}"
        ;;

    navigate|goto)
        URL="${1:?Usage: cmux navigate <url>}"
        send "{\"jsonrpc\":\"2.0\",\"method\":\"browser.navigate\",\"params\":{\"url\":\"$URL\"},\"id\":1}"
        ;;

    eval|js)
        SCRIPT="${1:?Usage: cmux eval <javascript>}"
        SCRIPT=$(echo "$SCRIPT" | sed 's/\\/\\\\/g; s/"/\\"/g')
        send "{\"jsonrpc\":\"2.0\",\"method\":\"browser.eval\",\"params\":{\"script\":\"$SCRIPT\"},\"id\":1}"
        ;;

    notify)
        TITLE="${1:-Notification}"
        BODY="${2:-}"
        send "{\"jsonrpc\":\"2.0\",\"method\":\"notify\",\"params\":{\"title\":\"$TITLE\",\"body\":\"$BODY\"},\"id\":1}"
        ;;

    # Workspace navigation
    next)
        send '{"jsonrpc":"2.0","method":"workspace.next","id":1}'
        ;;
    prev|previous)
        send '{"jsonrpc":"2.0","method":"workspace.previous","id":1}'
        ;;
    last)
        send '{"jsonrpc":"2.0","method":"workspace.last","id":1}'
        ;;
    current)
        send '{"jsonrpc":"2.0","method":"workspace.current","id":1}' | python3 -c "
import sys, json
d = json.load(sys.stdin).get('result', {})
print(f\"Workspace {d.get('index', '?')}: {d.get('title', '?')}\")
print(f\"CWD: {d.get('cwd', '?')}\")
if d.get('git_branch'): print(f\"Branch: {d.get('git_branch')}\")
" 2>/dev/null || send '{"jsonrpc":"2.0","method":"workspace.current","id":1}'
        ;;
    rename)
        TITLE="${1:?Usage: cmux rename <title>}"
        TITLE=$(echo "$TITLE" | sed 's/"/\\"/g')
        send "{\"jsonrpc\":\"2.0\",\"method\":\"workspace.rename\",\"params\":{\"title\":\"$TITLE\"},\"id\":1}"
        ;;
    reorder)
        FROM="${1:?Usage: cmux reorder <from> <to>}"
        TO="${2:?Usage: cmux reorder <from> <to>}"
        send "{\"jsonrpc\":\"2.0\",\"method\":\"workspace.reorder\",\"params\":{\"from\":\"$FROM\",\"to\":\"$TO\"},\"id\":1}"
        ;;

    # Surface commands
    read|read-text)
        send '{"jsonrpc":"2.0","method":"surface.read_text","id":1}' | python3 -c "
import sys, json
d = json.load(sys.stdin).get('result', {})
print(d.get('text', ''))
" 2>/dev/null || send '{"jsonrpc":"2.0","method":"surface.read_text","id":1}'
        ;;
    clear-history)
        send '{"jsonrpc":"2.0","method":"surface.clear_history","id":1}'
        ;;
    surfaces)
        send '{"jsonrpc":"2.0","method":"surface.list","id":1}' | python3 -c "
import sys, json
data = json.load(sys.stdin)
for s in data.get('result', []):
    marker = '▸' if s.get('active') == 'true' else ' '
    print(f\"{marker} {s['index']}: {s.get('title', '?')} [{s.get('cwd', '?')}]\")
" 2>/dev/null || send '{"jsonrpc":"2.0","method":"surface.list","id":1}'
        ;;

    # System commands
    ping)
        send '{"jsonrpc":"2.0","method":"system.ping","id":1}'
        ;;
    capabilities|caps)
        send '{"jsonrpc":"2.0","method":"system.capabilities","id":1}' | python3 -c "
import sys, json
d = json.load(sys.stdin).get('result', {})
methods = d.get('methods', '').split(',')
print(f\"Protocol: {d.get('protocol', '?')} v{d.get('version', '?')}\")
print(f\"Platform: {d.get('platform', '?')}\")
print(f\"Commands: {d.get('method_count', '?')}\")
for m in sorted(methods):
    if m: print(f\"  {m}\")
" 2>/dev/null || send '{"jsonrpc":"2.0","method":"system.capabilities","id":1}'
        ;;
    tree)
        send '{"jsonrpc":"2.0","method":"system.tree","id":1}' | python3 -c "
import sys, json
data = json.load(sys.stdin)
for node in data.get('result', []):
    active = '▸' if node.get('active') == 'true' else ' '
    branch = f\" [{node.get('git_branch')}]\" if node.get('git_branch') else ''
    print(f\"{active} {node.get('type', '?')} {node.get('index', '?')}: {node.get('title', '?')}{branch}\")
" 2>/dev/null || send '{"jsonrpc":"2.0","method":"system.tree","id":1}'
        ;;

    # Notification management
    notifications)
        send '{"jsonrpc":"2.0","method":"notification.list","id":1}' | python3 -c "
import sys, json
data = json.load(sys.stdin)
for n in data.get('result', []):
    print(f\"ws{n.get('workspace_id', '?')}: {n.get('message', '?')}\")
if not data.get('result'): print('No notifications')
" 2>/dev/null || send '{"jsonrpc":"2.0","method":"notification.list","id":1}'
        ;;
    clear-notifications)
        send '{"jsonrpc":"2.0","method":"notification.clear","id":1}'
        ;;

    help|--help|-h)
        cat <<'HELP'
cmux — control cmux-linux via socket API

Commands:
  cmux status                Show comprehensive app status
  cmux identify              Show app info (version, pid)
  cmux list                  List all workspaces
  cmux surfaces              List all surfaces
  cmux current               Show current workspace details
  cmux new [dir] [title]     Create new workspace
  cmux select <index>        Switch to workspace (1-based)
  cmux next                  Switch to next workspace
  cmux prev                  Switch to previous workspace
  cmux last                  Switch to last workspace
  cmux close                 Close active workspace
  cmux rename <title>        Rename active workspace
  cmux reorder <from> <to>   Reorder workspace positions
  cmux split [h|v]           Split pane (horizontal/vertical)
  cmux send <text>           Send text to active terminal
  cmux read                  Read terminal text (visible content)
  cmux clear-history         Clear terminal scrollback
  cmux browser [url]         Open browser in split
  cmux navigate <url>        Navigate browser to URL
  cmux eval <javascript>     Execute JS in browser
  cmux snapshot              Get browser DOM snapshot (for agents)
  cmux notify <title> [body] Send notification
  cmux notifications         List notifications
  cmux clear-notifications   Clear all notifications
  cmux ping                  Ping cmux (heartbeat)
  cmux caps                  List all supported commands
  cmux tree                  Show workspace/surface tree

Environment:
  CMUX_SOCKET    Path to cmux Unix socket (auto-detected)

Examples:
  cmux new /home/user/project "my-project"
  cmux notify "Claude" "Build succeeded"
  cmux select 2
  cmux list
HELP
        ;;

    *)
        echo "cmux: unknown command '$CMD'. Run 'cmux help' for usage." >&2
        exit 1
        ;;
esac
