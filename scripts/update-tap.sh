#!/bin/sh
# Writes Casks/remote-desktop-toggle.rb in hassansys2/homebrew-tap for a new release and pushes it.
# Usage: scripts/update-tap.sh <version> <sha256-of-pkg>
# In CI, $TAP_DEPLOY_KEY holds an SSH deploy key with write access to the tap repo.
set -eu
cd "$(dirname "$0")/.."

VERSION=$1
SHA256=$2
TAP_REPO="git@github.com:hassansys2/homebrew-tap.git"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if [ -n "${TAP_DEPLOY_KEY:-}" ]; then
    printf '%s\n' "$TAP_DEPLOY_KEY" > "$WORK/key"
    chmod 600 "$WORK/key"
    export GIT_SSH_COMMAND="ssh -i $WORK/key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
fi

git clone --depth 1 "$TAP_REPO" "$WORK/tap"
mkdir -p "$WORK/tap/Casks"
sed -e "s/@VERSION@/$VERSION/g" -e "s/@SHA256@/$SHA256/g" \
    pkg/remote-desktop-toggle.rb.in > "$WORK/tap/Casks/remote-desktop-toggle.rb"

cd "$WORK/tap"
git add Casks/remote-desktop-toggle.rb
if git diff --cached --quiet; then
    echo "Tap already up to date."
    exit 0
fi
git -c user.name="github-actions[bot]" \
    -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    commit -m "remote-desktop-toggle $VERSION"
git push origin HEAD
