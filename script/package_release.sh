#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-1.0.0}"
APP_DISPLAY="MaxUsage"
TARGET_NAME="OpenUsage"
BUNDLE_ID="com.1c7.maxusage"
MIN_SYSTEM_VERSION="15.0"

DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_DISPLAY.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_HELPERS="$APP_CONTENTS/Helpers"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_DISPLAY"
CLI_BINARY="$APP_HELPERS/openusage"
INFO_PLIST="$APP_CONTENTS/Info.plist"
DMG_NAME="$APP_DISPLAY-$VERSION.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

echo "==> Building release binary ($VERSION)..."
swift build -c release
BUILD_DIR="$(swift build -c release --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$TARGET_NAME"
BUILD_CLI_BINARY="$BUILD_DIR/openusage-cli"

echo "==> Staging $APP_BUNDLE..."
rm -rf "$APP_BUNDLE" "$DMG_PATH"
mkdir -p "$APP_MACOS" "$APP_HELPERS" "$APP_RESOURCES"

cp "$BUILD_BINARY" "$APP_BINARY"
cp "$BUILD_CLI_BINARY" "$CLI_BINARY"
chmod +x "$APP_BINARY" "$CLI_BINARY"

install_name_tool -add_rpath "@executable_path/../Frameworks" "$CLI_BINARY" 2>/dev/null || true

echo "==> Stamping SDK for Liquid Glass..."
vtool -set-build-version macos "$MIN_SYSTEM_VERSION" 26.0 -replace -output "$APP_BINARY.tmp" "$APP_BINARY" 2>/dev/null || true
if [ -f "$APP_BINARY.tmp" ]; then
  mv "$APP_BINARY.tmp" "$APP_BINARY"
  chmod +x "$APP_BINARY"
fi

shopt -s nullglob
for bundle in "$BUILD_DIR"/*.bundle; do
  cp -R "$bundle" "$APP_RESOURCES/$(basename "$bundle")"
done

RESOURCE_BUNDLE_NAME="${TARGET_NAME}_${TARGET_NAME}.bundle"
if [ -d "$APP_RESOURCES/$RESOURCE_BUNDLE_NAME" ]; then
  for lproj in "$APP_RESOURCES/$RESOURCE_BUNDLE_NAME"/*.lproj; do
    cp -R "$lproj" "$APP_RESOURCES/$(basename "$lproj")"
  done
fi

for lproj_dir in "$ROOT_DIR/Sources/OpenUsage/Resources"/*.lproj; do
  mkdir -p "$APP_RESOURCES/$(basename "$lproj_dir")"
  cp -R "$lproj_dir"/* "$APP_RESOURCES/$(basename "$lproj_dir")/"
done
shopt -u nullglob

PREBUILT_ICON_DIR="$ROOT_DIR/assets/AppIcon.prebuilt"
if [ -f "$PREBUILT_ICON_DIR/Assets.car" ]; then
  cp "$PREBUILT_ICON_DIR/Assets.car" "$APP_RESOURCES/Assets.car"
fi
if [ -f "$PREBUILT_ICON_DIR/AppIcon.icns" ]; then
  cp "$PREBUILT_ICON_DIR/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_DISPLAY</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_DISPLAY</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_DISPLAY</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>zh-Hans</string>
  </array>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

CODESIGN_IDENTITY=$(/usr/bin/security find-identity -p codesigning -v 2>/dev/null \
  | /usr/bin/awk -F\" '/Apple Development:/ { print $2; exit }') || CODESIGN_IDENTITY=""

"$ROOT_DIR/script/embed_sparkle.sh" "$APP_BUNDLE" "$APP_BINARY" "$CODESIGN_IDENTITY" "--options runtime"

ENTITLEMENTS="$ROOT_DIR/script/OpenUsage.local.entitlements.plist"

if [ -n "$CODESIGN_IDENTITY" ]; then
  echo "==> Signing with $CODESIGN_IDENTITY..."
  /usr/bin/codesign --force --options runtime --sign "$CODESIGN_IDENTITY" "$CLI_BINARY" >/dev/null 2>&1 || true
  /usr/bin/codesign --force --options runtime --sign "$CODESIGN_IDENTITY" --entitlements "$ENTITLEMENTS" "$APP_BUNDLE" >/dev/null 2>&1 || true
else
  echo "==> Ad-hoc signing..."
  /usr/bin/codesign --force --sign - "$CLI_BINARY" >/dev/null 2>&1 || true
  /usr/bin/codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP_BUNDLE" >/dev/null 2>&1 || true
fi

echo "==> Packaging DMG..."
STAGE_DMG_DIR="$DIST_DIR/dmg_stage"
rm -rf "$STAGE_DMG_DIR"
mkdir -p "$STAGE_DMG_DIR"
cp -R "$APP_BUNDLE" "$STAGE_DMG_DIR/"
ln -s /Applications "$STAGE_DMG_DIR/Applications"

hdiutil create -volname "$APP_DISPLAY" -srcfolder "$STAGE_DMG_DIR" -ov -format UDZO "$DMG_PATH"
rm -rf "$STAGE_DMG_DIR"

echo "==> DMG successfully created: $DMG_PATH"
ls -lh "$DMG_PATH"
