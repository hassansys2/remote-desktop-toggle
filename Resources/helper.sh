#!/bin/sh
# Remote Desktop Toggle privileged helper.
# Installed root-owned at /Library/PrivilegedHelperTools/remote-desktop-toggle/helper.
# It only creates or deletes Chrome Remote Desktop's own "enabled" flag file.
# Paths are fixed on purpose: this script must never act on caller-supplied paths.
set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH

FLAG=/Library/PrivilegedHelperTools/org.chromium.chromoting.me2me_enabled
CONFIG=/Library/PrivilegedHelperTools/org.chromium.chromoting.json

if [ "$(id -u)" -ne 0 ]; then
    echo "helper: must run as root" >&2
    exit 1
fi

case "${1:-}" in
    disable)
        rm -f "$FLAG"
        ;;
    enable)
        if [ ! -f "$CONFIG" ]; then
            echo "Chrome Remote Desktop has not been set up on this Mac yet. Set it up once at https://remotedesktop.google.com/access" >&2
            exit 2
        fi
        umask 022
        : > "$FLAG"
        chown root:wheel "$FLAG"
        chmod 644 "$FLAG"
        ;;
    *)
        echo "usage: helper enable|disable" >&2
        exit 64
        ;;
esac
