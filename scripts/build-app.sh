#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Lyric Bridge.app"
SIGNING_IDENTITY="${LYRIC_BRIDGE_SIGNING_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk '/Apple Development:/ && !/CSSMERR/ { print $2; exit }')"
fi
swift build -c release --package-path "$ROOT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/LyricBridge" "$APP/Contents/MacOS/LyricBridge"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>LyricBridge</string>
  <key>CFBundleIdentifier</key><string>com.lyricbridge.app</string>
  <key>CFBundleName</key><string>Lyric Bridge</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP"
else
  codesign --force --deep --sign - "$APP"
  echo "No valid Apple Development identity found; the ad-hoc signature may require re-adding Accessibility permission after a rebuild."
fi
echo "Created $APP"
