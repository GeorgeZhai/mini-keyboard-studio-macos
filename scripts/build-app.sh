#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
OUTPUT_APP_DIR="$PROJECT_DIR/dist/Mini Keyboard Studio.app"
STAGING_ROOT=$(mktemp -d)
APP_DIR="$STAGING_ROOT/Mini Keyboard Studio.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$PROJECT_DIR/.build/AppIcon.iconset"
BASE_ICON="$PROJECT_DIR/.build/AppIcon-1024.png"
ICON_TOOL="$PROJECT_DIR/.build/make-icon"
ARM_BUILD_DIR="$PROJECT_DIR/.build/arm64"
INTEL_BUILD_DIR="$PROJECT_DIR/.build/x86_64"
SIGNING_IDENTITY=${DEVELOPER_ID_APPLICATION:-}

cleanup() {
    rm -rf "$STAGING_ROOT"
}
trap cleanup EXIT

cd "$PROJECT_DIR"
swift build \
    --scratch-path "$ARM_BUILD_DIR" \
    -c release \
    --triple arm64-apple-macosx \
    --product MiniKeyboard \
    -Xswiftc -gnone \
    -Xcc -g0
swift build \
    --scratch-path "$INTEL_BUILD_DIR" \
    -c release \
    --triple x86_64-apple-macosx \
    --product MiniKeyboard \
    -Xswiftc -gnone \
    -Xcc -g0
ARM_BIN_DIR=$(swift build \
    --scratch-path "$ARM_BUILD_DIR" \
    -c release \
    --triple arm64-apple-macosx \
    --show-bin-path)
INTEL_BIN_DIR=$(swift build \
    --scratch-path "$INTEL_BUILD_DIR" \
    -c release \
    --triple x86_64-apple-macosx \
    --show-bin-path)

rm -rf "$ICONSET_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ICONSET_DIR"

lipo -create \
    "$ARM_BIN_DIR/MiniKeyboard" \
    "$INTEL_BIN_DIR/MiniKeyboard" \
    -output "$MACOS_DIR/MiniKeyboard"
cp "$PROJECT_DIR/Support/Info.plist" "$CONTENTS_DIR/Info.plist"

swiftc "$PROJECT_DIR/scripts/make-icon.swift" -o "$ICON_TOOL" -framework AppKit
"$ICON_TOOL" "$BASE_ICON"

for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$BASE_ICON" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$BASE_ICON" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
xattr -cr "$APP_DIR"
if [[ -n "$SIGNING_IDENTITY" ]]; then
    codesign \
        --force \
        --options runtime \
        --timestamp \
        --sign "$SIGNING_IDENTITY" \
        "$APP_DIR"
else
    codesign --force --sign - "$APP_DIR" >/dev/null
fi
codesign --verify --deep --strict "$APP_DIR"

rm -rf "$OUTPUT_APP_DIR"
ditto "$APP_DIR" "$OUTPUT_APP_DIR"
codesign --verify --deep --strict "$OUTPUT_APP_DIR"

echo "$OUTPUT_APP_DIR"
