#!/usr/bin/env bash
# Build cmux for Linux
# Prerequisites: swift, zig, libgtk-4-dev (or equivalent)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== cmux Linux build ==="

# Check prerequisites
for cmd in swift zig pkg-config; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $cmd not found. Install it first."
        exit 1
    fi
done

if ! pkg-config --exists gtk4 2>/dev/null; then
    echo "ERROR: GTK4 development libraries not found."
    echo "  Arch:   sudo pacman -S gtk4"
    echo "  Ubuntu: sudo apt install libgtk-4-dev"
    echo "  Fedora: sudo dnf install gtk4-devel"
    exit 1
fi

# Build libghostty if not already built
GHOSTTY_LIB="$PROJECT_DIR/ghostty/zig-out/lib/libghostty.a"
if [ ! -f "$GHOSTTY_LIB" ]; then
    echo "Building libghostty..."
    cd "$PROJECT_DIR/ghostty"
    zig build -Dapp-runtime=none -Doptimize=ReleaseFast
    echo "libghostty built: $GHOSTTY_LIB"
else
    echo "libghostty already built: $GHOSTTY_LIB"
fi

# Swap Package.swift for Linux build
cd "$PROJECT_DIR"
if [ -f Package.swift ] && ! head -3 Package.swift | grep -q "Linux build"; then
    echo "Swapping Package.swift for Linux build..."
    cp Package.swift Package.macos.swift.bak
    cp Package.linux.swift Package.swift
    SWAPPED=1
else
    SWAPPED=0
fi

# Build
echo "Building cmux-linux..."
swift build 2>&1

if [ "$SWAPPED" = "1" ]; then
    echo "Restoring original Package.swift..."
    mv Package.macos.swift.bak Package.swift
fi

echo ""
echo "=== Build complete ==="
echo "Binary: .build/debug/cmux-linux"
