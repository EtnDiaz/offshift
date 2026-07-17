#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="OffshiftCompanion"
APP_DISPLAY_NAME="Offshift"
BUNDLE_ID="com.tixo.offshift.companion"
MIN_SYSTEM_VERSION="14.0"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ASSET_CATALOG="$ROOT_DIR/Resources/AppIcon/Assets.xcassets"
ASSET_INFO_PLIST="$APP_CONTENTS/asset-info.plist"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
cd "$ROOT_DIR"
swift build
bash ./script/generate_app_icon.sh
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$DIST_DIR/$APP_NAME.app" "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleDisplayName</key><string>$APP_DISPLAY_NAME</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleName</key><string>$APP_DISPLAY_NAME</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.1</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>$MIN_SYSTEM_VERSION</string>
<key>LSUIElement</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST

xcrun actool --compile "$APP_RESOURCES" --platform macosx \
  --minimum-deployment-target "$MIN_SYSTEM_VERSION" --app-icon AppIcon \
  --output-partial-info-plist "$ASSET_INFO_PLIST" "$ASSET_CATALOG" >/dev/null
plutil -replace CFBundleIconFile -string AppIcon "$INFO_PLIST"
plutil -replace CFBundleIconName -string AppIcon "$INFO_PLIST"
rm -f "$ASSET_INFO_PLIST"

# SwiftPM produces the executable, while this script stages the app bundle.
# Sign that completed bundle ad hoc so Launch Services treats its Info.plist
# and resources (including the icon) as one local development artifact.
xattr -cr "$APP_BUNDLE"
codesign --force --sign - "$APP_BUNDLE"

# `open -n` asks LaunchServices for a new instance each time. A rebuilt,
# ad-hoc-signed dev bundle then leaves stale entries in Launchpad. The process
# is stopped above, so a normal bundle launch is both single-instance and keeps
# the macOS GUI lifecycle, icon, and menu-bar identity intact.
open_app() { /usr/bin/open "$APP_BUNDLE"; }
open_care_preview() { /usr/bin/open "$APP_BUNDLE" --args --care-preview; }
case "$MODE" in
  run) open_app ;;
  --care-preview|care-preview) open_care_preview ;;
  --debug|debug) lldb -- "$APP_BINARY" ;;
  --logs|logs) open_app; /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\"" ;;
  --telemetry|telemetry) open_app; /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\"" ;;
  --verify|verify) open_app; sleep 1; pgrep -x "$APP_NAME" >/dev/null ;;
  *) echo "usage: $0 [run|--care-preview|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac
