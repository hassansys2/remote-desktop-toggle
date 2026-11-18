# CLAUDE.md

Guidance for Claude Code (and other AI assistants) working in this repository.
User-facing docs live in [README.md](README.md); this file covers what an assistant needs to work safely here.

## What this is

A macOS menu-bar app (SwiftUI `MenuBarExtra`, macOS 13+) that turns the **Chrome Remote Desktop (CRD)**
host on and off. It does not replace or modify CRD, Chrome, or Google Updater.

The mechanism is CRD's own flag file, `/Library/PrivilegedHelperTools/org.chromium.chromoting.me2me_enabled`.
When it is missing, CRD's `remoting_me2me_host_service` exits at launch
([host_service_main.cc](https://chromium.googlesource.com/chromium/src/+/main/remoting/host/mac/host_service_main.cc)).
- **Off**: `sudo -n helper disable` (deletes flag), then `launchctl kill 15 gui/$UID/org.chromium.chromoting`.
- **On**: `helper enable` through the macOS admin prompt (osascript), then `launchctl kickstart`.
- Never touch `org.chromium.chromoting.json` (host config, keys, PIN hash).

## Layout

| Path | Purpose |
|---|---|
| `Sources/RemoteDesktopToggle/App.swift` | Menu-bar UI, `MenuBarIcon` (text fallback if a symbol is missing) |
| `Sources/RemoteDesktopToggle/CRDController.swift` | State detection, on/off actions, all paths in `enum Paths` |
| `Sources/RemoteDesktopToggle/Shell.swift` | `Process` runner and `runAsAdmin` (osascript admin prompt) |
| `Sources/RemoteDesktopToggle/Updater.swift` | Sparkle 2 wrapper ("Check for Updates…") |
| `Resources/helper.sh` | Root helper: only `enable` / `disable`, hard-coded paths |
| `Resources/install-helper.sh` | Installs helper + sudoers rule (run by pkg postinstall) |
| `Resources/uninstall.sh` | Full uninstaller |
| `pkg/` | Installer scripts, distribution template, welcome page, Homebrew cask template |
| `scripts/build-app.sh` | Builds universal, ad-hoc-signed `build/Remote Desktop Toggle.app` (Info.plist incl. Sparkle keys) |
| `scripts/package.sh` | Builds `dist/RemoteDesktopToggle-<VERSION>.pkg` |
| `scripts/make-appcast.sh` | Signs the pkg (EdDSA) and prints `appcast.xml` |
| `scripts/update-tap.sh` | Updates the cask in `hassansys2/homebrew-tap` |
| `.github/workflows/` | `build.yml` (push/PR), `release.yml` (`v*` tags) |

## Commands

```sh
./scripts/build-app.sh                       # build the .app
./scripts/package.sh                         # build the .pkg (runs build-app.sh)
for f in Resources/*.sh scripts/*.sh pkg/scripts/*; do sh -n "$f"; done   # syntax-check scripts
"build/Remote Desktop Toggle.app/Contents/MacOS/RemoteDesktopToggle"      # run a dev build
```

The version lives only in `VERSION`; it is used for both `CFBundleShortVersionString` and `CFBundleVersion`
(Sparkle compares `CFBundleVersion` with `sparkle:version`).

## Repository rules (enforced on GitHub)

- `main` is protected: changes go through a **pull request** that passes the `build` check. Never push to `main` directly.
- PRs need code-owner approval; the owner merges their own PRs with the admin bypass.
  **Assistants must not use `gh pr merge --admin` or any other rule bypass.** Open the PR, wait for `build`
  to pass, then ask the owner to merge.
- Tags can't be moved or deleted, and releases are immutable. A failed release means bumping to the next
  version, not re-tagging.
- Signing secrets (`SPARKLE_PRIVATE_KEY`, `TAP_DEPLOY_KEY`) are in the `release` environment (only `v*` tags).
  Never print, log, or commit them. The Sparkle private key is also in the owner's login Keychain
  (account `remote-desktop-toggle`).

## Release process

1. Branch → bump `VERSION` → PR → `build` passes → owner merges.
2. `git switch main && git pull && git tag vX.Y.Z && git push origin vX.Y.Z`
3. `release.yml` checks the tag matches `VERSION`, builds and signs the pkg, publishes the GitHub Release
   (`.pkg` + `appcast.xml`), and updates the Homebrew cask.
4. Verify: release assets exist, the appcast at `releases/latest/download/appcast.xml` points at the new pkg,
   and `brew info --cask hassansys2/tap/remote-desktop-toggle` shows the new version.

## Conventions

- Commit messages and PR descriptions: plain, imperative, no AI attribution lines
  (no "Generated with", no `Co-Authored-By: Claude`, no session links).
- Shell scripts: POSIX `sh`, `set -eu`, explicit `PATH`, quote every variable.
- Keep the root helper minimal. Anything run via sudo or as root must use fixed paths and must never take
  caller-supplied paths.

## Gotchas

- **SF Symbols**: every name used for the menu-bar icon must exist on macOS 13+. A missing symbol rendered
  the icon blank and made the app unreachable (`display.slash` does not exist). Check with
  `NSImage(systemSymbolName:accessibilityDescription:)`.
- **Helper location**: the helper must stay under `/Library/PrivilegedHelperTools/` (root-owned path).
  `/usr/local` can be user-writable, which combined with the NOPASSWD sudoers rule would allow privilege escalation.
- **sudo needs a TTY**: `brew install`/`sudo` fail inside Claude Code's `!` shell. Ask the user to run them in Terminal.
- **Homebrew**: newer Homebrew requires `brew trust hassansys2/tap` before installing from the tap.
- **pkg payload `._*` entries**: files carry the protected `com.apple.provenance` xattr; pkgbuild stores it as
  AppleDouble entries. Harmless, since Installer applies them as xattrs.
- **Sparkle framework** from SwiftPM is unsigned. `build-app.sh` re-signs it ad-hoc, inside-out. The app is not
  notarized (no paid Apple Developer account), so hardened runtime is off.
- **Testing on/off** changes real system state and needs admin prompts the user must approve. Check state with:
  ```sh
  ls /Library/PrivilegedHelperTools/ | grep me2me_enabled; pgrep -lx remoting_me2me_host
  ```
