#!/bin/sh
# Signs an installer with Sparkle's EdDSA key and prints a one-item appcast.xml to stdout.
# Usage: scripts/make-appcast.sh dist/RemoteDesktopToggle-1.2.0.pkg 1.2.0 > dist/appcast.xml
#
# Key source: $SPARKLE_PRIVATE_KEY (CI) or, if unset, the "remote-desktop-toggle" key in the
# login Keychain (created with Sparkle's generate_keys --account remote-desktop-toggle).
set -eu
cd "$(dirname "$0")/.."

PKG=$1
VERSION=$2
REPO="hassansys2/remote-desktop-toggle"
SIGN_UPDATE=.build/artifacts/sparkle/Sparkle/bin/sign_update
[ -x "$SIGN_UPDATE" ] || swift package resolve >/dev/null

if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
    SIG_ATTRS=$(printf '%s' "$SPARKLE_PRIVATE_KEY" | "$SIGN_UPDATE" --ed-key-file - "$PKG")
else
    SIG_ATTRS=$("$SIGN_UPDATE" --account remote-desktop-toggle "$PKG")
fi
# SIG_ATTRS looks like: sparkle:edSignature="..." length="12345"
case "$SIG_ATTRS" in
    *sparkle:edSignature=*length=*) ;;
    *) echo "make-appcast: unexpected sign_update output" >&2; exit 1 ;;
esac

PKG_NAME=$(basename "$PKG")
PUB_DATE=$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")

cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Remote Desktop Toggle</title>
    <link>https://github.com/$REPO</link>
    <item>
      <title>Version $VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://github.com/$REPO/releases/tag/v$VERSION</sparkle:releaseNotesLink>
      <enclosure url="https://github.com/$REPO/releases/download/v$VERSION/$PKG_NAME"
                 sparkle:installationType="package"
                 type="application/octet-stream"
                 $SIG_ATTRS />
    </item>
  </channel>
</rss>
EOF
