#!/bin/sh
# Installs the privileged helper and its sudoers rule. Must run as root.
# Called by the .pkg postinstall script, and by the app's "Install helper…" fallback.
set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH

if [ "$(id -u)" -ne 0 ]; then
    echo "install-helper: must run as root" >&2
    exit 1
fi

SRC_DIR=$(cd "$(dirname "$0")" && pwd)
DEST=/Library/PrivilegedHelperTools/remote-desktop-toggle
SUDOERS=/etc/sudoers.d/remote-desktop-toggle

# The sudoers rule below grants password-less root for one command, so every
# directory on the path to the helper must be root-owned and not writable by others.
mkdir -p "$DEST"
chown root:wheel "$DEST"
chmod 755 "$DEST"
for d in /Library /Library/PrivilegedHelperTools "$DEST"; do
    owner=$(stat -f %u "$d")
    perms=$(stat -f %Lp "$d")
    if [ "$owner" -ne 0 ]; then
        echo "install-helper: $d is not owned by root; refusing to install" >&2
        exit 1
    fi
    case "$perms" in
        *[2367]?|*?[2367]) # group- or other-writable
            # /Library/PrivilegedHelperTools is 1755 (sticky) on stock macOS; only plain
            # group/other write bits are rejected here.
            echo "install-helper: $d is writable by non-root users; refusing to install" >&2
            exit 1
            ;;
    esac
done

install -o root -g wheel -m 755 "$SRC_DIR/helper.sh" "$DEST/helper"
install -o root -g wheel -m 755 "$SRC_DIR/uninstall.sh" "$DEST/uninstall.sh"

tmp=$(mktemp /tmp/remote-desktop-toggle-sudoers.XXXXXX)
trap 'rm -f "$tmp"' EXIT
cat > "$tmp" <<EOF
# Installed by Remote Desktop Toggle (https://github.com/hassansys2/remote-desktop-toggle).
# Lets admin users turn Chrome Remote Desktop OFF without a password.
# Turning it ON still requires authentication.
%admin ALL=(root) NOPASSWD: $DEST/helper disable
EOF
visudo -cf "$tmp" >/dev/null
chown root:wheel "$tmp"
chmod 440 "$tmp"
mkdir -p /etc/sudoers.d
mv -f "$tmp" "$SUDOERS"
trap - EXIT

echo "Remote Desktop Toggle helper installed."
