#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="OffshiftCompanion"
APP_DISPLAY_NAME="Offshift"
BUNDLE_ID="com.tixo.offshift.companion"
MIN_SYSTEM_VERSION="14.0"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# A bundle executed from ~/Documents triggers the Files & Folders TCC prompt,
# while an Application Support bundle can still be indexed by Spotlight. Keep
# source in the workspace, but stage the runnable developer app under TMPDIR:
# it needs no Documents permission and never becomes an app-search candidate.
WORKSPACE_DIST_DIR="$ROOT_DIR/dist"
DEVELOPER_BUILD_DIR="${TMPDIR:-/tmp}/OffshiftDeveloperBuild"
DIST_DIR="${OFFSHIFT_BUILD_DIR:-$DEVELOPER_BUILD_DIR}"
APP_BUNDLE="$DIST_DIR/$APP_DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ASSET_CATALOG="$ROOT_DIR/Resources/AppIcon/Assets.xcassets"
ASSET_INFO_PLIST="$APP_CONTENTS/asset-info.plist"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
# LaunchServices may still be releasing the previous bundle for a short moment
# after the process exits. Do not replace or sign that bundle until it has gone:
# otherwise macOS can attach FinderInfo while codesign is walking its contents.
for _ in {1..30}; do
  pgrep -x "$APP_NAME" >/dev/null 2>&1 || break
  sleep 0.1
done
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  echo "Offshift did not exit before rebuild" >&2
  exit 1
fi
cd "$ROOT_DIR"
swift build
bash ./script/generate_app_icon.sh
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

# Migrate old generated bundles once. They are disposable build artifacts,
# never application state, and are the source of stale Spotlight/Launchpad
# records from earlier development runs.
LSREGISTER="$(/usr/bin/xcode-select -p)/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
didUnregisterLegacyBundle=false
for legacyApp in \
  "$WORKSPACE_DIST_DIR/$APP_DISPLAY_NAME.app" \
  "$HOME/Library/Application Support/Offshift/DeveloperBuild/$APP_DISPLAY_NAME.app"; do
  if [ -d "$legacyApp" ] && [ "$legacyApp" != "$APP_BUNDLE" ]; then
    "$LSREGISTER" -u "$legacyApp" >/dev/null 2>&1 || true
    rm -rf "$legacyApp"
    didUnregisterLegacyBundle=true
  fi
done
if [ "$didUnregisterLegacyBundle" = true ]; then
  killall Dock >/dev/null 2>&1 || true
fi

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
# Finder can write this harmless display metadata after a bundle is opened, but
# codesign correctly rejects it as unsigned bundle data. Remove it explicitly
# (and recursively) from the freshly staged artifact before its final signing.
xattr -cr "$APP_BUNDLE" || true
xattr -d com.apple.FinderInfo "$APP_BUNDLE" 2>/dev/null || true
xattr -d com.apple.fileprovider.fpfs#P "$APP_BUNDLE" 2>/dev/null || true
codesign --force --sign - "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

# `open -n` asks LaunchServices for a new instance each time. A rebuilt,
# ad-hoc-signed dev bundle then leaves stale entries in Launchpad. The process
# is stopped above, so a normal bundle launch is both single-instance and keeps
# the macOS GUI lifecycle, icon, and menu-bar identity intact.
open_app() { /usr/bin/open "$APP_BUNDLE"; }
open_care_preview() { /usr/bin/open "$APP_BUNDLE" --args --care-preview; }
case "$MODE" in
  run) open_app ;;
  --care-preview|care-preview) open_care_preview ;;
  --bundle|bundle) ;;
  --debug|debug) lldb -- "$APP_BINARY" ;;
  --logs|logs) open_app; /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\"" ;;
  --telemetry|telemetry) open_app; /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\"" ;;
  --verify|verify) open_app; sleep 1; pgrep -x "$APP_NAME" >/dev/null ;;
  *) echo "usage: $0 [run|--care-preview|--bundle|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac
