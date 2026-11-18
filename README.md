# Remote Desktop Toggle

A tiny macOS menu-bar app that turns **Chrome Remote Desktop** access on and off with one click,
without uninstalling it or redoing the web setup.

- **Turn Off**: your Mac goes offline in Chrome Remote Desktop and rejects connections. It stays
  off after a restart and at the login screen. No password needed.
- **Turn On**: back online in seconds with your existing PIN. Asks for your admin password
  (or Touch ID where macOS offers it), because turning remote access on should never happen silently.

> Not affiliated with or endorsed by Google. "Chrome Remote Desktop" is a trademark of Google LLC.

## Install

1. Download `RemoteDesktopToggle-<version>.pkg` from [Releases](https://github.com/hassansys2/remote-desktop-toggle/releases).
2. The package is not notarized, so macOS will block a plain double-click. Right-click it → **Open**
   (or *System Settings → Privacy & Security → Open Anyway*).
3. Follow the installer. The app starts automatically. Look for the 🖥 icon in the menu bar.
4. Optional: tick **Launch at Login** in the menu.

Requires macOS 13 or later and Chrome Remote Desktop already set up for remote access
(at [remotedesktop.google.com/access](https://remotedesktop.google.com/access)).

## How it works

The Chrome Remote Desktop host on macOS is started by the LaunchAgent
`/Library/LaunchAgents/org.chromium.chromoting.plist`. Its service checks a flag file at launch:

```
/Library/PrivilegedHelperTools/org.chromium.chromoting.me2me_enabled
```

If the file is missing, the service exits immediately ([source](https://chromium.googlesource.com/chromium/src/+/main/remoting/host/mac/host_service_main.cc)).
This is Chrome Remote Desktop's own on/off switch. The host's config and PIN live in a separate file
(`org.chromium.chromoting.json`) that this app never touches.

| Action | What the app does |
|---|---|
| Turn Off | Deletes the flag file (via the helper), then sends SIGTERM to the running host via `launchctl kill`. |
| Turn On | Re-creates the flag file (via the helper, after an admin prompt), then `launchctl kickstart`s the host. |
| Status | Checks the flag file and whether `remoting_me2me_host` is running, every 3 seconds. |

Chrome, Google Updater and the Chrome Remote Desktop extension are not modified.

## What gets installed

| Path | Purpose |
|---|---|
| `/Applications/Remote Desktop Toggle.app` | The menu-bar app |
| `/Library/PrivilegedHelperTools/remote-desktop-toggle/helper` | Root-owned script with exactly two verbs: `enable` / `disable` (creates/deletes the flag file; paths are hard-coded) |
| `/Library/PrivilegedHelperTools/remote-desktop-toggle/uninstall.sh` | Uninstaller |
| `/etc/sudoers.d/remote-desktop-toggle` | `%admin ALL=(root) NOPASSWD: …/helper disable`, so **only turning off** is password-free |

### Security notes
- The password-free rule can only *disable* remote access. Enabling always goes through the
  standard macOS administrator prompt.
- The installer refuses to install the helper unless every directory on its path is root-owned and
  not writable by other users (otherwise the sudoers rule could be abused).
- Everything is plain shell + ~300 lines of Swift. Read it before installing.

## Uninstall

Use **Uninstall…** in the menu, or run:

```sh
sudo /Library/PrivilegedHelperTools/remote-desktop-toggle/uninstall.sh
```

Chrome Remote Desktop is left in whatever state it was in. If it was off, the uninstaller prints the
two commands to turn it back on.

## Build from source

Requires Xcode (or the Command Line Tools with Swift 5.9+).

```sh
./scripts/build-app.sh   # → build/Remote Desktop Toggle.app (universal, ad-hoc signed)
./scripts/package.sh     # → dist/RemoteDesktopToggle-<version>.pkg
```

The version comes from the `VERSION` file.

## Troubleshooting

- **"Enabled, but the host is not running"**: click *Start Host*. If it still doesn't start, open
  the Chrome Remote Desktop website and check the Mac is set up.
- **"Disabled, but the host is still running"**: click *Stop Host*.
- **A Chrome Remote Desktop update turned it back on**: the menu-bar icon shows the real state; just
  click *Turn Off* again.
- **Google's website says the Mac is offline or offers "Turn on"**: that's expected while it's off.
  Use this app to turn it on; clicking "Turn on" on the website would redo the setup.

## License

[MIT](LICENSE)
