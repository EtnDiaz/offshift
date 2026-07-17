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
hdiutil create -volname "Offshift" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_PATH" >/dev/null
test -s "$DMG_PATH"
printf '%s\n' "$DMG_PATH"
