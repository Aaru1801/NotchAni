#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release

APP="NotchAni.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp .build/release/NotchAni "$APP/Contents/MacOS/NotchAni"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>NotchAni</string>
    <key>CFBundleIdentifier</key>
    <string>com.notchani.app</string>
    <key>CFBundleName</key>
    <string>NotchAni</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc sign so Gatekeeper lets it launch on first run
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "Built $APP"
echo "Launch: open $APP"
