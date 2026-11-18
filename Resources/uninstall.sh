#!/bin/sh
# Removes Remote Desktop Toggle (app, helper, sudoers rule, installer receipt).
# Usage: sudo /Library/PrivilegedHelperTools/remote-desktop-toggle/uninstall.sh
# Chrome Remote Desktop itself is not touched.
set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo: sudo $0" >&2
    exit 1
fi

pkill -x RemoteDesktopToggle 2>/dev/null || true

rm -f /etc/sudoers.d/remote-desktop-toggle
rm -rf "/Applications/Remote Desktop Toggle.app"
pkgutil --forget io.github.hassansys2.remote-desktop-toggle >/dev/null 2>&1 || true

if [ ! -e /Library/PrivilegedHelperTools/org.chromium.chromoting.me2me_enabled ] &&
   [ -e /Library/PrivilegedHelperTools/org.chromium.chromoting.json ]; then
    echo "Note: Chrome Remote Desktop is currently turned OFF. To turn it back on:"
    echo "  sudo touch /Library/PrivilegedHelperTools/org.chromium.chromoting.me2me_enabled"
    echo "  launchctl kickstart gui/\$(id -u)/org.chromium.chromoting   # run as your normal user"
fi

# Remove the helper directory last (this script lives inside it).
rm -rf /Library/PrivilegedHelperTools/remote-desktop-toggle

echo "Remote Desktop Toggle has been uninstalled."
