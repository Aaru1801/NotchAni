#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release

APP="NotchAni.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp .build/release/NotchAni "$APP/Contents/MacOS/NotchAni"

# Generate AppIcon.icns from icon.png if present.
ICON_SRC="icon.png"
ICONSET="$(mktemp -d)/AppIcon.iconset"
if [[ -f "$ICON_SRC" ]]; then
    mkdir -p "$ICONSET"
    for SIZE in 16 32 64 128 256 512; do
        sips -z "$SIZE" "$SIZE" "$ICON_SRC" --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
        DOUBLE=$((SIZE * 2))
        sips -z "$DOUBLE" "$DOUBLE" "$ICON_SRC" --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
    done
    sips -z 1024 1024 "$ICON_SRC" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>NotchAni</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
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
    <key>NSAppleEventsUsageDescription</key>
    <string>NotchAni queries Spotify and Music for now-playing artwork when MediaRemote doesn't supply it.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc sign so Gatekeeper lets it launch
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "Built $APP"
echo "Launch: open $APP"
