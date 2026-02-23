#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_EXECUTABLE="DataTransformMac"
APP_DISPLAY_NAME="File Transformer and Formatter"
APP_BUNDLE_ID="com.rohitbhattad.filetransformerformatter"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/dist/${APP_DISPLAY_NAME}.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
ICON_PATH="$ROOT_DIR/Assets/AppIcon.icns"

echo "Generating app icon..."
swift "$ROOT_DIR/scripts/generate_app_icon.swift"

echo "Building release binary..."
swift build -c release --package-path "$ROOT_DIR"

echo "Creating app bundle at $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$BUILD_DIR/$APP_EXECUTABLE" "$MACOS_DIR/$APP_EXECUTABLE"
cp "$ICON_PATH" "$RESOURCES_DIR/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$APP_BUNDLE_ID</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleExecutable</key>
  <string>$APP_EXECUTABLE</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "App bundle created:"
echo "  $APP_DIR"
echo
echo "Optional ZIP for sharing:"
echo "  cd \"$ROOT_DIR/dist\" && zip -r \"${APP_DISPLAY_NAME}.zip\" \"${APP_DISPLAY_NAME}.app\""
