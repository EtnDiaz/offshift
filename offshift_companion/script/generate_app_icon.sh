#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_IMAGE="$ROOT_DIR/Sources/OffshiftCompanion/Resources/ThirdParty/RedCard/brand/sleeping-codex-logo.png"
ICON_DIR="$ROOT_DIR/Resources/AppIcon"
ICONSET_DIR="$ICON_DIR/Offshift.iconset"
ASSET_ICONSET_DIR="$ICON_DIR/Assets.xcassets/AppIcon.appiconset"
OUTPUT_ICON="$ICON_DIR/Offshift.icns"

mkdir -p "$ICON_DIR"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
mkdir -p "$ASSET_ICONSET_DIR"

render_icon() {
  local size="$1"
  local name="$2"
  sips -z "$size" "$size" "$SOURCE_IMAGE" --out "$ICONSET_DIR/$name" >/dev/null
  sips -z "$size" "$size" "$SOURCE_IMAGE" --out "$ASSET_ICONSET_DIR/$name" >/dev/null
}

render_icon 16 icon_16x16.png
render_icon 32 icon_16x16@2x.png
render_icon 32 icon_32x32.png
render_icon 64 icon_32x32@2x.png
render_icon 128 icon_128x128.png
render_icon 256 icon_128x128@2x.png
render_icon 256 icon_256x256.png
render_icon 512 icon_256x256@2x.png
render_icon 512 icon_512x512.png
render_icon 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICON"
rm -rf "$ICONSET_DIR"
