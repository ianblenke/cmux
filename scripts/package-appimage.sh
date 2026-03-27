#!/usr/bin/env bash
# Package cmux as an AppImage for portable Linux distribution
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

echo "=== Packaging cmux AppImage ==="

# Build release
./scripts/build-linux.sh --release

# Create AppDir structure
APPDIR="$PROJECT_DIR/cmux.AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib" "$APPDIR/usr/share/cmux"

# Copy binary
cp .build/release/cmux-linux "$APPDIR/usr/bin/cmux-linux"
cp scripts/cmux-cli.sh "$APPDIR/usr/bin/cmux"
chmod +x "$APPDIR/usr/bin/cmux" "$APPDIR/usr/bin/cmux-linux"

# Copy libghostty
cp ghostty/zig-out/lib/libghostty.so "$APPDIR/usr/lib/"

# Copy shell integration
cp -r Resources/shell-integration "$APPDIR/usr/share/cmux/"

# Desktop file
cp cmux.desktop "$APPDIR/"
sed -i "s|Exec=cmux-linux|Exec=cmux-linux|" "$APPDIR/cmux.desktop"

# AppRun script
cat > "$APPDIR/AppRun" << 'APPRUN'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/lib:${LD_LIBRARY_PATH:-}"
export CMUX_SHELL_INTEGRATION_DIR="$HERE/usr/share/cmux/shell-integration"
export PATH="$HERE/usr/bin:$PATH"
exec "$HERE/usr/bin/cmux-linux" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

# Icon (use a generic terminal icon for now)
if [ -f /usr/share/icons/hicolor/256x256/apps/utilities-terminal.png ]; then
    cp /usr/share/icons/hicolor/256x256/apps/utilities-terminal.png "$APPDIR/cmux.png"
else
    # Create a minimal 1x1 PNG as placeholder
    printf '\x89PNG\r\n\x1a\n' > "$APPDIR/cmux.png"
fi
ln -sf cmux.png "$APPDIR/.DirIcon"

# Check if appimagetool is available
if command -v appimagetool &>/dev/null; then
    echo "Building AppImage..."
    ARCH=x86_64 appimagetool "$APPDIR" "cmux-linux-x86_64.AppImage"
    echo "=== AppImage created: cmux-linux-x86_64.AppImage ==="
    ls -lh cmux-linux-x86_64.AppImage
else
    echo ""
    echo "=== AppDir created: $APPDIR ==="
    echo ""
    echo "To create AppImage, install appimagetool:"
    echo "  wget https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
    echo "  chmod +x appimagetool-x86_64.AppImage"
    echo "  ./appimagetool-x86_64.AppImage $APPDIR cmux-linux-x86_64.AppImage"
    echo ""
    echo "Or run the AppDir directly:"
    echo "  $APPDIR/AppRun"
    echo ""
    du -sh "$APPDIR"
fi
