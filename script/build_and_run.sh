#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${(%):-%N}")/.." && pwd)"
PRODUCT_NAME="CryptoBubblesWallpaper"
APP_NAME="Crypto Bubbles Wallpaper"
BUILD_CONFIGURATION="release"
VERIFY=0
BUILD_ONLY=0
DEBUG_WINDOW=0
APP_VERSION="${APP_VERSION:-0.1.0}"

for argument in "$@"; do
  case "$argument" in
    --debug) BUILD_CONFIGURATION="debug" ;;
    --verify) VERIFY=1 ;;
    --build-only) BUILD_ONLY=1 ;;
    --debug-window) DEBUG_WINDOW=1 ;;
    *)
      print -u2 "Unknown argument: $argument"
      exit 2
      ;;
  esac
done

cd "$ROOT_DIR"
mkdir -p dist
"$ROOT_DIR/script/build_app_icon.sh"

if pgrep -x "$PRODUCT_NAME" >/dev/null 2>&1; then
  pkill -x "$PRODUCT_NAME" || true
  sleep 1
fi

swift build -c "$BUILD_CONFIGURATION" --product "$PRODUCT_NAME"

APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp ".build/$BUILD_CONFIGURATION/$PRODUCT_NAME" "$APP_BUNDLE/Contents/MacOS/$PRODUCT_NAME"
cp "Assets/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>$PRODUCT_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>net.cryptobubbles.wallpaper</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null

if [[ "$BUILD_ONLY" -eq 0 ]]; then
  if [[ "$DEBUG_WINDOW" -eq 1 ]]; then
    /usr/bin/open -n "$APP_BUNDLE" --args --debug-window
  else
    /usr/bin/open -n "$APP_BUNDLE"
  fi
fi

if [[ "$VERIFY" -eq 1 ]]; then
  sleep 2
  pgrep -x "$PRODUCT_NAME" >/dev/null
  print "Launched $APP_BUNDLE"
fi
