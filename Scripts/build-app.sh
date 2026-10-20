#!/bin/zsh
# Builds a signed Rada.app (release configuration).
#
#   Scripts/build-app.sh            → ~/Library/Caches/app.rada/dist/Rada.app
#   Scripts/build-app.sh --install  → also copies it to /Applications
#
# Signing: $SIGN_IDENTITY (e.g. "Developer ID Application: …"), else ad-hoc.
set -euo pipefail

ROOT="${0:A:h:h}"
CACHE="$HOME/Library/Caches/app.rada"   # outside iCloud Drive: codesign rejects its xattrs
SCRATCH="$CACHE/build"
APP="$CACHE/dist/Rada.app"

[[ -f "$ROOT/Vendor/whisper/lib/libwhisper-bundle.a" ]] || "$ROOT/Scripts/build-whisper.sh"

echo "→ Compiling (release)"
swift build --package-path "$ROOT" --scratch-path "$SCRATCH" -c release --arch arm64 2>&1 \
  | grep -v "search path .* not found" || true
BIN_DIR="$(swift build --package-path "$ROOT" --scratch-path "$SCRATCH" -c release --arch arm64 --show-bin-path)"
[[ -x "$BIN_DIR/Rada" ]] || { echo "Build failed"; exit 1; }

echo "→ Assembling bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Rada" "$APP/Contents/MacOS/Rada"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Vendor/whisper/ggml-silero-vad.bin" "$APP/Contents/Resources/"

ICONSET="$(mktemp -d)/AppIcon.iconset"
"$APP/Contents/MacOS/Rada" --export-iconset "$ICONSET"
iconutil -c icns -o "$APP/Contents/Resources/AppIcon.icns" "$ICONSET"

echo "→ Signing"
IDENTITY="${SIGN_IDENTITY:--}"
xattr -cr "$APP"
codesign --force --options runtime --timestamp=none \
  --entitlements "$ROOT/Resources/Rada.entitlements" --sign "$IDENTITY" "$APP"
codesign --verify --strict "$APP"
echo "  signed with: $IDENTITY"

if [[ "${1:-}" == "--install" ]]; then
  echo "→ Installing to /Applications"
  pkill -x Rada 2>/dev/null && sleep 0.5 || true
  rm -rf /Applications/Rada.app
  ditto "$APP" /Applications/Rada.app
  echo "✓ /Applications/Rada.app"
else
  echo "✓ $APP"
fi
