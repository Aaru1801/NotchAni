#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Build the Swift binary
swift build -c release

APP="NotchAni.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

# Copy the binary
cp .build/release/NotchAni "$APP/Contents/MacOS/NotchAni"

# CRITICAL: Copy the adapter files into the Resources folder
# If your folder is lowercase 'adapter', rename it to 'Adapter' now!
cp "Adapter/mediaremote-adapter.pl" "$APP/Contents/Resources/"
# `ditto` preserves the framework's Versions symlinks; plain `cp -r` flattens
# them and confuses codesign with an "ambiguous bundle format" error.
/usr/bin/ditto "Adapter/MediaRemoteAdapter.framework" \
               "$APP/Contents/Resources/MediaRemoteAdapter.framework"

# Generate Icon (existing logic)
ICON_SRC="icon.png"
if [[ -f "$ICON_SRC" ]]; then
    ICONSET="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for SIZE in 16 32 64 128 256 512; do
        sips -z "$SIZE" "$SIZE" "$ICON_SRC" --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
        sips -z $((SIZE*2)) $((SIZE*2)) "$ICON_SRC" --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
fi

# Create Info.plist (existing logic)
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>NotchAni</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.notchani.app</string>
    <key>CFBundleName</key>
    <string>NotchAni</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleMusicUsageDescription</key>
    <string>NotchAni needs access to media data.</string>
</dict>
</plist>
PLIST

# Strip xattrs + AppleDouble files that block codesigning
find "$APP" -name ".DS_Store" -delete 2>/dev/null || true
find "$APP" -name "._*" -delete 2>/dev/null || true
xattr -cr "$APP"

# The bundled framework ships pre-signed; ad-hoc re-sign so its hash matches
# the copy we just made, then sign the bundle that contains it.
FRAMEWORK="$APP/Contents/Resources/MediaRemoteAdapter.framework"
if [[ -d "$FRAMEWORK" ]]; then
    rm -rf "$FRAMEWORK/Versions/A/_CodeSignature"
    rm -rf "$FRAMEWORK/_CodeSignature"
    xattr -cr "$FRAMEWORK"
    codesign --force --sign - "$FRAMEWORK" >/dev/null
fi
xattr -cr "$APP"
codesign --force --sign - "$APP" >/dev/null

if ! codesign --verify "$APP" >/dev/null 2>&1; then
    echo "warning: codesign verification failed for $APP" >&2
fi

echo "Built $APP successfully."
