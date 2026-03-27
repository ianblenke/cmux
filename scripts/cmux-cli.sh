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
  cmux identify              Show app info (version, pid)
  cmux list                  List all workspaces
  cmux new [dir] [title]     Create new workspace
  cmux select <index>        Switch to workspace (1-based)
  cmux close                 Close active workspace
  cmux split [h|v]           Split pane (horizontal/vertical)
  cmux send <text>           Send text to active terminal
  cmux browser [url]         Open browser in split
  cmux navigate <url>        Navigate browser to URL
  cmux eval <javascript>     Execute JS in browser
  cmux notify <title> [body] Send notification

Environment:
  CMUX_SOCKET    Path to cmux Unix socket (auto-detected)

Examples:
  cmux new /home/user/project "my-project"
  cmux notify "Claude" "Build succeeded"
  cmux split vertical
  cmux send "ls -la\n"
  cmux select 2
  cmux list
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

    help|--help|-h)
        cat <<'HELP'
cmux — control cmux-linux via socket API

Commands:
  cmux identify              Show app info (version, pid)
  cmux list                  List all workspaces
  cmux new [dir] [title]     Create new workspace
  cmux select <index>        Switch to workspace (1-based)
  cmux close                 Close active workspace
  cmux split [h|v]           Split pane (horizontal/vertical)
  cmux send <text>           Send text to active terminal
  cmux browser [url]         Open browser in split
  cmux navigate <url>        Navigate browser to URL
  cmux eval <javascript>     Execute JS in browser
  cmux notify <title> [body] Send notification

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
