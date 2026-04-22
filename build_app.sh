#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "$0")/Sources/MacControl" && pwd)"
OUT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$OUT_DIR/MacControl.app"
BIN="$APP/Contents/MacOS/MacControl"
ARCH="$(uname -m)"
MIN_MACOS="12.0"
SDK_PATH="$(xcrun --show-sdk-path)"
MODULE_CACHE="/tmp/maccontrol-clang-module-cache"

echo "▸ Building…"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
mkdir -p "$MODULE_CACHE"

swiftc \
  -sdk "$SDK_PATH" \
  -target "$ARCH-apple-macos$MIN_MACOS" \
  -module-cache-path "$MODULE_CACHE" \
  -parse-as-library \
  "$DIR/Theme.swift" \
  "$DIR/Models.swift" \
  "$DIR/CommandEngine.swift" \
  "$DIR/MessageBubble.swift" \
  "$DIR/ContentView.swift" \
  "$DIR/MacControlApp.swift" \
  -o "$BIN"

cat > "$APP/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>Mac Control</string>
  <key>CFBundleDisplayName</key>
  <string>Mac Control</string>
  <key>CFBundleIdentifier</key>
  <string>dev.maccontrol.app</string>
  <key>CFBundleVersion</key>
  <string>1.0</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleExecutable</key>
  <string>MacControl</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Mac Control needs Automation access to control System Events and apps.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>LSUIElement</key>
  <false/>
</dict>
</plist>
EOF

echo "✓ Done → $APP"
if [ -t 1 ]; then
  echo ""
  echo "Reveal in Finder with: open -R \"$APP\""
fi
