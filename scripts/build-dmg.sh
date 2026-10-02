#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
APP_DIR="$PROJECT_DIR/dist/Mini Keyboard Studio.app"
VERSION=$(/usr/libexec/PlistBuddy \
    -c "Print :CFBundleShortVersionString" \
    "$PROJECT_DIR/Support/Info.plist")
DMG_PATH="$PROJECT_DIR/dist/Mini-Keyboard-Studio-$VERSION.dmg"
SIGNING_IDENTITY=${DEVELOPER_ID_APPLICATION:-}
NOTARY_PROFILE=${NOTARYTOOL_PROFILE:-}

if [[ -n "$NOTARY_PROFILE" && -z "$SIGNING_IDENTITY" ]]; then
    echo "NOTARYTOOL_PROFILE requires DEVELOPER_ID_APPLICATION." >&2
    exit 2
fi

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
if diskutil image create from --help >/dev/null 2>&1; then
    diskutil image create from \
        --format UDZO \
        --volumeName "Mini Keyboard Studio" \
        "$STAGING_DIR" \
        "$DMG_PATH"
else
    hdiutil create \
        -volname "Mini Keyboard Studio" \
        -srcfolder "$STAGING_DIR" \
        -format UDZO \
        -ov \
        "$DMG_PATH"
fi

if [[ -n "$SIGNING_IDENTITY" ]]; then
    codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"
    codesign --verify --verbose=2 "$DMG_PATH"
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
    xcrun notarytool submit \
        "$DMG_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
    spctl \
        --assess \
        --type open \
        --context context:primary-signature \
        --verbose=2 \
        "$DMG_PATH"
fi

hdiutil verify "$DMG_PATH"
shasum -a 256 "$DMG_PATH"
echo "$DMG_PATH"
