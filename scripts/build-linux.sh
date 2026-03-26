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
for arg in "$@"; do
    case "$arg" in
        --run) RUN=1 ;;
        --release) RELEASE=1 ;;
        --rebuild-ghostty) REBUILD_GHOSTTY=1 ;;
        --help|-h) echo "Usage: $0 [--run] [--release] [--rebuild-ghostty]"; exit 0 ;;
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

if [ "$RUN" = "1" ]; then
    echo ""
    echo "=== Running cmux-linux ==="
    exec "$BINARY"
fi
