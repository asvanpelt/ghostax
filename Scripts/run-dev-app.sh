#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/Ghostax.app"
GHOSTTY_RESOURCES="/Applications/Ghostty.app/Contents/Resources"

cd "$ROOT_DIR"
swift build

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$ROOT_DIR/.build/arm64-apple-macosx/debug/Ghostax" "$APP_DIR/Contents/MacOS/Ghostax"
chmod +x "$APP_DIR/Contents/MacOS/Ghostax"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

if [[ -d "$GHOSTTY_RESOURCES/terminfo" ]]; then
    cp -R "$GHOSTTY_RESOURCES/terminfo" "$APP_DIR/Contents/Resources/terminfo"
fi

if [[ -d "$GHOSTTY_RESOURCES/ghostty" ]]; then
    cp -R "$GHOSTTY_RESOURCES/ghostty" "$APP_DIR/Contents/Resources/ghostty"
fi

killall Ghostax 2>/dev/null || true
open -n "$APP_DIR"
