#!/bin/bash
# Builds AeroCue in release mode and assembles it into AeroCue.app.
# Usage: Scripts/build_app.sh [--install]
#   --install   also copy the built app to /Applications (overwriting any existing copy)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> swift build -c release"
swift build -c release

APP="build/AeroCue.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp ".build/release/AeroCue" "$APP/Contents/MacOS/AeroCue"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# Prefer a stable identity (see Scripts/setup_signing.sh). Ad-hoc signatures
# change on every build, which makes macOS revoke the Accessibility grant each
# time; a fixed certificate keeps the app's identity stable so it sticks.
IDENTITY="AeroCue Local Dev"
if security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    SIGN_AS="$IDENTITY"
    echo "==> codesign as '$IDENTITY'"
else
    SIGN_AS="-"
    echo "==> codesign (ad-hoc -- run Scripts/setup_signing.sh to stop"
    echo "    Accessibility permission resetting on every rebuild)"
fi

codesign --force --deep --sign "$SIGN_AS" "$APP"

echo "==> built $APP"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf "/Applications/AeroCue.app"
    cp -R "$APP" "/Applications/AeroCue.app"
    codesign --force --deep --sign "$SIGN_AS" "/Applications/AeroCue.app"
    echo "==> installed to /Applications/AeroCue.app"
fi
