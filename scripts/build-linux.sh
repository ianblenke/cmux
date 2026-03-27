#!/usr/bin/env bash
# Build and optionally run cmux for Linux
# Usage: ./scripts/build-linux.sh [--run] [--release] [--rebuild-ghostty]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

RUN=0
RELEASE=0
REBUILD_GHOSTTY=0
INSTALL=0
for arg in "$@"; do
    case "$arg" in
        --run) RUN=1 ;;
        --release) RELEASE=1 ;;
        --rebuild-ghostty) REBUILD_GHOSTTY=1 ;;
        --install) INSTALL=1; RELEASE=1 ;;
        --help|-h)
            echo "Usage: $0 [--run] [--release] [--install] [--rebuild-ghostty]"
            echo ""
            echo "Options:"
            echo "  --run              Build and launch"
            echo "  --release          Build optimized release binary"
            echo "  --install          Build release and install to ~/.local/bin"
            echo "  --rebuild-ghostty  Force rebuild libghostty"
            exit 0
            ;;
    esac
done

echo "=== cmux Linux build ==="

# Check prerequisites
for cmd in swift zig pkg-config; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $cmd not found."
        case "$cmd" in
            swift) echo "  Install: yay -S swift-bin" ;;
            zig) echo "  Install: sudo pacman -S zig" ;;
            pkg-config) echo "  Install: sudo pacman -S pkgconf" ;;
        esac
        exit 1
    fi
done

if ! pkg-config --exists gtk4 2>/dev/null; then
    echo "ERROR: GTK4 not found."
    echo "  Arch:   sudo pacman -S gtk4"
    echo "  Ubuntu: sudo apt install libgtk-4-dev"
    echo "  Fedora: sudo dnf install gtk4-devel"
    exit 1
fi

# Init submodules if needed
if [ ! -f ghostty/build.zig ]; then
    echo "Initializing ghostty submodule..."
    git submodule update --init ghostty
fi

# Build libghostty
GHOSTTY_SO="$PROJECT_DIR/ghostty/zig-out/lib/libghostty.so"
if [ ! -f "$GHOSTTY_SO" ] || [ "$REBUILD_GHOSTTY" = "1" ]; then
    echo "Building libghostty..."
    cd "$PROJECT_DIR/ghostty"
    if [ "$RELEASE" = "1" ]; then
        zig build -Dapp-runtime=none -Doptimize=ReleaseFast
    else
        zig build -Dapp-runtime=none -Doptimize=ReleaseFast  # Always ReleaseFast for lib
    fi
    cd "$PROJECT_DIR"
    echo "libghostty: $(ls -lh "$GHOSTTY_SO" | awk '{print $5}')"
else
    echo "libghostty: cached"
fi

# Swap Package.swift for Linux build
SWAPPED=0
if [ -f Package.swift ] && ! head -3 Package.swift | grep -q "Linux build"; then
    cp Package.swift Package.macos.swift.bak
    cp Package.linux.swift Package.swift
    SWAPPED=1
fi

# Restore on exit (even on error)
cleanup() {
    if [ "$SWAPPED" = "1" ] && [ -f Package.macos.swift.bak ]; then
        mv Package.macos.swift.bak Package.swift
    fi
}
trap cleanup EXIT

# Build
echo "Building cmux-linux..."
if [ "$RELEASE" = "1" ]; then
    swift build -c release 2>&1
    BINARY=".build/release/cmux-linux"
else
    swift build 2>&1
    BINARY=".build/debug/cmux-linux"
fi

echo ""
echo "=== Build complete ==="
echo "Binary: $BINARY ($(ls -lh "$BINARY" | awk '{print $5}'))"

if [ "$INSTALL" = "1" ]; then
    echo ""
    echo "=== Installing cmux ==="
    INSTALL_DIR="${HOME}/.local/bin"
    SHARE_DIR="${HOME}/.local/share"
    mkdir -p "$INSTALL_DIR" "$SHARE_DIR/applications" "$SHARE_DIR/cmux"

    # Binary
    cp "$BINARY" "$INSTALL_DIR/cmux-linux"
    echo "  Binary: $INSTALL_DIR/cmux-linux"

    # CLI (remove symlink if exists, then copy)
    rm -f "$INSTALL_DIR/cmux" 2>/dev/null || true
    cp "$PROJECT_DIR/scripts/cmux-cli.sh" "$INSTALL_DIR/cmux"
    chmod +x "$INSTALL_DIR/cmux"
    echo "  CLI: $INSTALL_DIR/cmux"

    # libghostty.so
    cp "$PROJECT_DIR/ghostty/zig-out/lib/libghostty.so" "$SHARE_DIR/cmux/"
    echo "  Library: $SHARE_DIR/cmux/libghostty.so"

    # Shell integration
    cp -r "$PROJECT_DIR/Resources/shell-integration" "$SHARE_DIR/cmux/"
    echo "  Shell integration: $SHARE_DIR/cmux/shell-integration/"

    # Desktop entry
    sed "s|Exec=cmux-linux|Exec=$INSTALL_DIR/cmux-linux|" \
        "$PROJECT_DIR/cmux.desktop" > "$SHARE_DIR/applications/cmux.desktop"
    echo "  Desktop: $SHARE_DIR/applications/cmux.desktop"

    # Shell integration installer
    "$PROJECT_DIR/scripts/install-shell-integration.sh" 2>/dev/null || true

    echo ""
    echo "=== Installation complete ==="
    echo "Run: cmux-linux"
    echo "CLI: cmux list / cmux notify / cmux help"
    echo ""
    echo "Make sure ~/.local/bin is in your PATH:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

if [ "$RUN" = "1" ]; then
    echo ""
    echo "=== Running cmux-linux ==="
    exec "$BINARY"
fi
