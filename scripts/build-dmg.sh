#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
APP_DIR="$PROJECT_DIR/dist/Mini Keyboard Studio.app"
VERSION=$(/usr/libexec/PlistBuddy \
    -c "Print :CFBundleShortVersionString" \
    "$PROJECT_DIR/Support/Info.plist")
DMG_PATH="$PROJECT_DIR/dist/Mini-Keyboard-Studio-$VERSION.dmg"
STAGING_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

"$PROJECT_DIR/scripts/build-app.sh"

ditto "$APP_DIR" "$STAGING_DIR/Mini Keyboard Studio.app"
ln -s /Applications "$STAGING_DIR/Applications"
xattr -cr "$STAGING_DIR/Mini Keyboard Studio.app"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "Mini Keyboard Studio" \
    -srcfolder "$STAGING_DIR" \
    -format UDZO \
    -ov \
    "$DMG_PATH"

shasum -a 256 "$DMG_PATH"
echo "$DMG_PATH"
