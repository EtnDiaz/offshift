#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The asset catalog has no product version; keep the artifact name stable until
# release metadata is introduced by a signed distribution workflow.
VERSION="${OFFSHIFT_VERSION:-0.1.1}"
RELEASE_DIR="$ROOT_DIR/release"
STAGING_DIR="${TMPDIR:-/tmp}/OffshiftDmgStage"
APP_BUNDLE="$STAGING_DIR/Offshift.app"
DMG_PATH="$RELEASE_DIR/Offshift-$VERSION.dmg"

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$RELEASE_DIR"
OFFSHIFT_BUILD_DIR="$STAGING_DIR" "$ROOT_DIR/script/build_and_run.sh" --bundle
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

# The companion is intentionally menu-bar-first, so a bare app bundle in a
# DMG reads as a failed launch. Present the conventional install affordance and
# state where the first-run window and later controls live.
ln -s /Applications "$STAGING_DIR/Applications"
cat >"$STAGING_DIR/Install Offshift.txt" <<'TEXT'
Install Offshift

1. Drag Offshift.app onto the Applications shortcut in this window.
2. Open Offshift from Applications.

On the first launch, Offshift opens a short setup window. Afterwards it lives
in the menu bar (the moon icon), not in the Dock. Choose “Open Today” from the
menu bar whenever you want to see its status or settings.
TEXT

hdiutil create -volname "Offshift" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH" >/dev/null
test -s "$DMG_PATH"
printf '%s\n' "$DMG_PATH"
