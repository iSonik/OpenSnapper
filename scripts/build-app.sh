#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="OpenSnapper"
BUNDLE_ID="${BUNDLE_ID:-com.opensnapper.app}"
APP_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
EXECUTABLE_PATH="$ROOT_DIR/.build/debug/$APP_NAME"
PLIST_PATH="$APP_DIR/Contents/Info.plist"
ICON_SOURCE_PATH="$ROOT_DIR/Resources/appicon.png"
STATUS_ICON_SOURCE_PATH="$ROOT_DIR/Resources/snappingturtleicon.png"
ICONSET_PATH="$ROOT_DIR/dist/AppIcon.iconset"
ICON_ICNS_PATH="$APP_DIR/Contents/Resources/AppIcon.icns"

cd "$ROOT_DIR"
swift build --product "$APP_NAME"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
if [[ -f "$STATUS_ICON_SOURCE_PATH" ]]; then
    cp "$STATUS_ICON_SOURCE_PATH" "$APP_DIR/Contents/Resources/snappingturtleicon.png"
fi

ICON_PLIST_BLOCK=""
if [[ -f "$ICON_SOURCE_PATH" ]]; then
    rm -rf "$ICONSET_PATH"
    mkdir -p "$ICONSET_PATH"

    sips -z 16 16 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_16x16.png" >/dev/null
    sips -z 32 32 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_16x16@2x.png" >/dev/null
    sips -z 32 32 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_32x32.png" >/dev/null
    sips -z 64 64 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_32x32@2x.png" >/dev/null
    sips -z 128 128 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_128x128.png" >/dev/null
    sips -z 256 256 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_128x128@2x.png" >/dev/null
    sips -z 256 256 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_256x256.png" >/dev/null
    sips -z 512 512 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_256x256@2x.png" >/dev/null
    sips -z 512 512 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_512x512.png" >/dev/null
    sips -z 1024 1024 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_512x512@2x.png" >/dev/null

    iconutil -c icns "$ICONSET_PATH" -o "$ICON_ICNS_PATH"
    rm -rf "$ICONSET_PATH"

    ICON_PLIST_BLOCK=$'    <key>CFBundleIconFile</key>\n    <string>AppIcon.icns</string>\n    <key>CFBundleIconName</key>\n    <string>AppIcon</string>\n    <key>CFBundleIcons</key>\n    <dict>\n        <key>CFBundlePrimaryIcon</key>\n        <dict>\n            <key>CFBundleIconFile</key>\n            <string>AppIcon.icns</string>\n            <key>CFBundleIconName</key>\n            <string>AppIcon</string>\n            <key>CFBundleIconFiles</key>\n            <array>\n                <string>AppIcon</string>\n                <string>AppIcon.icns</string>\n            </array>\n        </dict>\n    </dict>'
fi

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
${ICON_PLIST_BLOCK}
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DIR" >/dev/null 2>&1 || true

echo "Built: $APP_DIR"
echo "Bundle ID: $BUNDLE_ID"
