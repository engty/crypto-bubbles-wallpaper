#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${(%):-%N}")/.." && pwd)"
SOURCE_ICON="$ROOT_DIR/Assets/AppIcon.svg"
OUTPUT_ICON="$ROOT_DIR/Assets/AppIcon.icns"
TEMP_DIR="$(mktemp -d)"
ICONSET_DIR="$TEMP_DIR/AppIcon.iconset"
SOURCE_PNG="$TEMP_DIR/AppIcon-1024.png"

trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "$ICONSET_DIR"
sips -s format png "$SOURCE_ICON" --out "$SOURCE_PNG" >/dev/null 2>&1

typeset -a iconSizes=(
  "icon_16x16.png:16"
  "icon_16x16@2x.png:32"
  "icon_32x32.png:32"
  "icon_32x32@2x.png:64"
  "icon_128x128.png:128"
  "icon_128x128@2x.png:256"
  "icon_256x256.png:256"
  "icon_256x256@2x.png:512"
  "icon_512x512.png:512"
  "icon_512x512@2x.png:1024"
)

for iconSize in "${iconSizes[@]}"; do
  fileName="${iconSize%%:*}"
  pixelSize="${iconSize##*:}"
  sips -z "$pixelSize" "$pixelSize" "$SOURCE_PNG" --out "$ICONSET_DIR/$fileName" >/dev/null
done

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICON"
