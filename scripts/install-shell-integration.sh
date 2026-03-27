#!/usr/bin/env bash
# Install cmux shell integration into .bashrc / .zshrc
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INTEGRATION_DIR="$PROJECT_DIR/Resources/shell-integration"

SNIPPET='
# cmux shell integration (auto-loaded when running inside cmux)
if [ -n "${CMUX_SOCKET_PATH:-}" ] && [ -n "${CMUX_SHELL_INTEGRATION_DIR:-}" ]; then
    if [ -n "${BASH_VERSION:-}" ] && [ -f "$CMUX_SHELL_INTEGRATION_DIR/cmux-bash-integration.bash" ]; then
        source "$CMUX_SHELL_INTEGRATION_DIR/cmux-bash-integration.bash"
    elif [ -n "${ZSH_VERSION:-}" ] && [ -f "$CMUX_SHELL_INTEGRATION_DIR/cmux-zsh-integration.zsh" ]; then
        source "$CMUX_SHELL_INTEGRATION_DIR/cmux-zsh-integration.zsh"
    fi
fi'

install_for() {
    local rcfile="$1"
    if [ -f "$rcfile" ] && grep -q "cmux shell integration" "$rcfile" 2>/dev/null; then
        echo "Already installed in $rcfile"
        return
    fi
    echo "$SNIPPET" >> "$rcfile"
    echo "Installed in $rcfile"
}

echo "Installing cmux shell integration..."
echo "Integration dir: $INTEGRATION_DIR"

if [ -n "${BASH_VERSION:-}" ] || [ -f "$HOME/.bashrc" ]; then
    install_for "$HOME/.bashrc"
fi

if [ -f "$HOME/.zshrc" ]; then
    install_for "$HOME/.zshrc"
fi

echo ""
echo "Done! Restart your shell or run:"
echo "  source ~/.bashrc"
echo ""
echo "Inside cmux, you can now use:"
echo "  cmux list"
echo "  cmux notify 'Agent' 'Build done'"
