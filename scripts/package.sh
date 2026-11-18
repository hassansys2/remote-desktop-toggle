#!/bin/sh
# Builds the standard macOS installer: dist/RemoteDesktopToggle-<version>.pkg
set -eu
cd "$(dirname "$0")/.."

APP_NAME="Remote Desktop Toggle"
PKG_ID="io.github.hassansys2.remote-desktop-toggle"
VERSION=$(tr -d '[:space:]' < VERSION)

./scripts/build-app.sh

ROOT=build/pkgroot
rm -rf "$ROOT" build/component.plist build/component.pkg build/distribution.xml build/pkg-resources
mkdir -p "$ROOT/Applications" dist
ditto --norsrc --noextattr --noacl "build/$APP_NAME.app" "$ROOT/Applications/$APP_NAME.app"

# Always install to /Applications, even if an older copy was moved elsewhere.
pkgbuild --analyze --root "$ROOT" build/component.plist >/dev/null
plutil -replace 0.BundleIsRelocatable -bool NO build/component.plist

echo "==> Building component package"
pkgbuild \
    --root "$ROOT" \
    --component-plist build/component.plist \
    --identifier "$PKG_ID" \
    --version "$VERSION" \
    --install-location / \
    --scripts pkg/scripts \
    build/component.pkg

mkdir -p build/pkg-resources
cp pkg/resources/welcome.html build/pkg-resources/
cp LICENSE build/pkg-resources/LICENSE.txt
sed -e "s/@VERSION@/$VERSION/g" -e "s/@PKG_ID@/$PKG_ID/g" \
    pkg/distribution.xml.in > build/distribution.xml

OUT="dist/RemoteDesktopToggle-$VERSION.pkg"
echo "==> Building installer $OUT"
productbuild \
    --distribution build/distribution.xml \
    --resources build/pkg-resources \
    --package-path build \
    "$OUT"

shasum -a 256 "$OUT"
