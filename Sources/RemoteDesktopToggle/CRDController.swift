import AppKit
import Foundation

/// Paths used by the Chrome Remote Desktop (CRD) host on macOS, and by our helper.
enum Paths {
    static let crdHostApp = "/Library/PrivilegedHelperTools/ChromeRemoteDesktopHost.app"
    static let crdConfig = "/Library/PrivilegedHelperTools/org.chromium.chromoting.json"
    /// CRD's own on/off switch. If it is missing, the host service exits at launch.
    static let crdEnabledFlag = "/Library/PrivilegedHelperTools/org.chromium.chromoting.me2me_enabled"
    static let crdLaunchdLabel = "org.chromium.chromoting"
    static let crdHostProcess = "remoting_me2me_host"

    static let helper = "/Library/PrivilegedHelperTools/remote-desktop-toggle/helper"
    static let uninstaller = "/Library/PrivilegedHelperTools/remote-desktop-toggle/uninstall.sh"
    static let sudoersRule = "/etc/sudoers.d/remote-desktop-toggle"

    static var bundledInstaller: String? {
        Bundle.main.path(forResource: "install-helper", ofType: "sh")
    }

    static var launchdTarget: String { "gui/\(getuid())/\(crdLaunchdLabel)" }
}

enum CRDState: Equatable {
    case crdNotInstalled
    case crdNotSetUp
    case on
    case off
    case turningOn
    case turningOff
    /// Flag present but host not running (for example, it crashed or was never started).
    case enabledButStopped
    /// Flag removed but host still running (for example, it was stopped outside this app).
    case disabledButRunning
}

@MainActor
final class CRDController: ObservableObject {
    @Published private(set) var state: CRDState = .off
    @Published private(set) var helperInstalled = false
    @Published private(set) var busy = false
    @Published var lastError: String?

    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshIfIdle() }
        }
    }

    // MARK: - Status

    /// SF Symbol names. Every name here must exist on macOS 13+, otherwise the menu-bar item
    /// renders blank and the app becomes unreachable (see `MenuBarIcon` for the fallback).
    var iconName: String {
        switch state {
        case .on, .turningOn: return "display"
        case .enabledButStopped, .disabledButRunning: return "exclamationmark.triangle"
        default: return "lock.display"
        }
    }

    var statusText: String {
        switch state {
        case .crdNotInstalled: return "Chrome Remote Desktop is not installed"
        case .crdNotSetUp: return "Chrome Remote Desktop is not set up yet"
        case .on: return "Remote access: ON"
        case .off: return "Remote access: OFF"
        case .turningOn: return "Turning on…"
        case .turningOff: return "Turning off…"
        case .enabledButStopped: return "Enabled, but the host is not running"
        case .disabledButRunning: return "Disabled, but the host is still running"
        }
    }

    private func refreshIfIdle() {
        if !busy { refresh() }
    }

    func refresh() {
        let fm = FileManager.default
        helperInstalled = fm.fileExists(atPath: Paths.helper) && fm.fileExists(atPath: Paths.sudoersRule)
        state = Self.currentState()
    }

    nonisolated static func hostRunning() -> Bool {
        Shell.run("/usr/bin/pgrep", ["-x", Paths.crdHostProcess]).ok
    }

    nonisolated static func currentState() -> CRDState {
        let fm = FileManager.default
        guard fm.fileExists(atPath: Paths.crdHostApp) else { return .crdNotInstalled }
        guard fm.fileExists(atPath: Paths.crdConfig) else { return .crdNotSetUp }
        let enabled = fm.fileExists(atPath: Paths.crdEnabledFlag)
        let running = hostRunning()
        switch (enabled, running) {
        case (true, true): return .on
        case (false, false): return .off
        case (true, false): return .enabledButStopped
        case (false, true): return .disabledButRunning
        }
    }

    // MARK: - Actions

    func turnOff() {
        perform(transition: .turningOff) {
            // 1. Remove the flag so the host can't come back (reboot, login screen, relaunch).
            var result = Shell.run("/usr/bin/sudo", ["-n", Paths.helper, "disable"])
            if !result.ok {
                // No password-less rule (helper missing or sudoers changed): ask for admin.
                result = Shell.runAsAdmin([Paths.helper, "disable"],
                                          prompt: "Remote Desktop Toggle needs permission to turn off Chrome Remote Desktop.")
                if !result.ok { return "Could not turn off: \(result.message)" }
            }
            // 2. Stop the running host. The service forwards SIGTERM to the host and exits;
            //    launchd does not restart it (the job has no KeepAlive).
            return Self.stopHost()
        }
    }

    func turnOn() {
        perform(transition: .turningOn) {
            let result = Shell.runAsAdmin([Paths.helper, "enable"],
                                          prompt: "Remote Desktop Toggle wants to turn ON remote access to this Mac.")
            if !result.ok { return "Could not turn on: \(result.message)" }
            return Self.startHost()
        }
    }

    /// Fixes a mismatch between the flag and the running host without changing the flag.
    func reconcile() {
        switch state {
        case .enabledButStopped: perform(transition: .turningOn) { Self.startHost() }
        case .disabledButRunning: perform(transition: .turningOff) { Self.stopHost() }
        default: refresh()
        }
    }

    func installHelper() {
        guard let installer = Paths.bundledInstaller else {
            lastError = "Installer script is missing from the app bundle. Please reinstall the app."
            return
        }
        perform(transition: nil) {
            let result = Shell.runAsAdmin([installer],
                                          prompt: "Remote Desktop Toggle needs to install its helper.")
            return result.ok ? nil : "Could not install helper: \(result.message)"
        }
    }

    func uninstall() {
        let alert = NSAlert()
        alert.messageText = "Uninstall Remote Desktop Toggle?"
        alert.informativeText = "This removes the app, its helper and its sudoers rule. "
            + "Chrome Remote Desktop itself is not removed and stays in its current state (\(state == .off ? "OFF" : "ON"))."
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        perform(transition: nil) {
            let result = Shell.runAsAdmin([Paths.uninstaller],
                                          prompt: "Remote Desktop Toggle needs permission to uninstall itself.")
            if !result.ok { return "Could not uninstall: \(result.message)" }
            DispatchQueue.main.async { NSApp.terminate(nil) }
            return nil
        }
    }

    // MARK: - Helpers

    nonisolated private static func stopHost() -> String? {
        guard hostRunning() else { return nil }
        Shell.run("/bin/launchctl", ["kill", "15", Paths.launchdTarget])
        if waitFor(running: false, timeout: 6) { return nil }
        // Fallback: the host runs as the current user, so we can signal it directly.
        Shell.run("/usr/bin/pkill", ["-TERM", "-x", Paths.crdHostProcess])
        return waitFor(running: false, timeout: 4) ? nil : "The Chrome Remote Desktop host did not stop."
    }

    nonisolated private static func startHost() -> String? {
        if hostRunning() { return nil }
        let result = Shell.run("/bin/launchctl", ["kickstart", Paths.launchdTarget])
        if !result.ok { return "Could not start the host: \(result.message)" }
        return waitFor(running: true, timeout: 15) ? nil : "The Chrome Remote Desktop host did not start. Check that it is set up at remotedesktop.google.com."
    }

    nonisolated private static func waitFor(running: Bool, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if hostRunning() == running { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return hostRunning() == running
    }

    /// Runs `work` off the main thread. `work` returns an error message or nil.
    private func perform(transition: CRDState?, _ work: @escaping @Sendable () -> String?) {
        guard !busy else { return }
        busy = true
        lastError = nil
        if let transition { state = transition }
        Task.detached {
            let error = work()
            await MainActor.run {
                self.busy = false
                self.lastError = error
                self.refresh()
                if let error { Self.showError(error) }
            }
        }
    }

    private static func showError(_ message: String) {
        guard message != "Cancelled." && !message.hasSuffix(": Cancelled.") else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Remote Desktop Toggle"
        alert.informativeText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
