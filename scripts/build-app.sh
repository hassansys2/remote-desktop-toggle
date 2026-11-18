#!/bin/sh
# Builds "build/Remote Desktop Toggle.app" (universal arm64 + x86_64, ad-hoc signed).
set -eu
cd "$(dirname "$0")/.."

APP_NAME="Remote Desktop Toggle"
EXEC_NAME="RemoteDesktopToggle"
BUNDLE_ID="io.github.hassansys2.remote-desktop-toggle"
VERSION=$(tr -d '[:space:]' < VERSION)
# Sparkle compares CFBundleVersion with the appcast's sparkle:version, so both use VERSION.
SPARKLE_FEED_URL="https://github.com/hassansys2/remote-desktop-toggle/releases/latest/download/appcast.xml"
SPARKLE_PUBLIC_KEY="eDVckQXRIotUStkPxvzwCt7IAu08ZQEo0eV7ni9rznM="
SPARKLE_FRAMEWORK=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"

APP="build/$APP_NAME.app"

echo "==> Building $EXEC_NAME $VERSION (universal)"
swift build -c release --arch arm64 --arch x86_64
BIN_DIR=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN_DIR/$EXEC_NAME" "$APP/Contents/MacOS/$EXEC_NAME"
ditto "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"
for f in helper.sh install-helper.sh uninstall.sh; do
    cp "Resources/$f" "$APP/Contents/Resources/$f"
    chmod 755 "$APP/Contents/Resources/$f"
done

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>$EXEC_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>SUFeedURL</key><string>$SPARKLE_FEED_URL</string>
    <key>SUPublicEDKey</key><string>$SPARKLE_PUBLIC_KEY</string>
    <key>SUEnableAutomaticChecks</key><true/>
    <key>SUScheduledCheckInterval</key><integer>86400</integer>
    <key>NSHumanReadableCopyright</key><string>MIT License. Not affiliated with Google.</string>
</dict>
</plist>
EOF
plutil -lint "$APP/Contents/Info.plist" >/dev/null

echo "==> Signing (ad-hoc, inside-out as Sparkle's docs require)"
FW="$APP/Contents/Frameworks/Sparkle.framework"
codesign -f -s - "$FW/Versions/B/XPCServices/Installer.xpc"
codesign -f -s - --preserve-metadata=entitlements "$FW/Versions/B/XPCServices/Downloader.xpc"
codesign -f -s - "$FW/Versions/B/Autoupdate"
codesign -f -s - "$FW/Versions/B/Updater.app"
codesign -f -s - "$FW"
codesign -f -s - "$APP"
codesign --verify --deep --strict "$APP"

echo "Built $APP"
