#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_APP="$ROOT_DIR/.build/Ghostax.app"
INSTALL_APP="/Applications/Ghostax.app"
GHOSTTY_RESOURCES="/Applications/Ghostty.app/Contents/Resources"

cd "$ROOT_DIR"

echo "==> Building Ghostax (release)…"
swift build -c release

echo "==> Assembling app bundle…"
rm -rf "$BUILD_APP"
mkdir -p "$BUILD_APP/Contents/MacOS" "$BUILD_APP/Contents/Resources"

cp "$ROOT_DIR/.build/arm64-apple-macosx/release/Ghostax" "$BUILD_APP/Contents/MacOS/Ghostax"
chmod +x "$BUILD_APP/Contents/MacOS/Ghostax"
cp "$ROOT_DIR/Resources/Info.plist" "$BUILD_APP/Contents/Info.plist"

if [[ -d "$GHOSTTY_RESOURCES/terminfo" ]]; then
    cp -R "$GHOSTTY_RESOURCES/terminfo" "$BUILD_APP/Contents/Resources/terminfo"
fi
if [[ -d "$GHOSTTY_RESOURCES/ghostty" ]]; then
    cp -R "$GHOSTTY_RESOURCES/ghostty" "$BUILD_APP/Contents/Resources/ghostty"
fi

echo "==> Signing (ad-hoc)…"
codesign --force --deep --sign - "$BUILD_APP"

echo "==> Installing to /Applications…"
killall Ghostax 2>/dev/null || true
rm -rf "$INSTALL_APP"
cp -R "$BUILD_APP" "$INSTALL_APP"

echo "==> Done. Launching Ghostax…"
open "$INSTALL_APP"
