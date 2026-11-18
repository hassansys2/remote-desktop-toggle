import AppKit
import ServiceManagement
import SwiftUI

@main
struct RemoteDesktopToggleApp: App {
    @StateObject private var crd = CRDController()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(crd: crd)
        } label: {
            MenuBarIcon(symbol: crd.iconName, fallbackText: crd.state == .on ? "CRD ON" : "CRD OFF")
                .accessibilityLabel(crd.statusText)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Never lets the menu-bar item go blank: falls back to text if a symbol is unavailable.
struct MenuBarIcon: View {
    let symbol: String
    let fallbackText: String

    var body: some View {
        if NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil {
            Image(systemName: symbol)
        } else {
            Text(fallbackText)
        }
    }
}

struct MenuContent: View {
    @ObservedObject var crd: CRDController
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Text(crd.statusText)

        if let error = crd.lastError, error != "Cancelled.", !error.hasSuffix(": Cancelled.") {
            Text("⚠︎ \(error)")
        }

        Divider()

        switch crd.state {
        case .on:
            Button("Turn Off") { crd.turnOff() }
                .keyboardShortcut("o")
        case .off:
            Button("Turn On…") { crd.turnOn() }
                .keyboardShortcut("o")
        case .enabledButStopped:
            Button("Start Host") { crd.reconcile() }
            Button("Turn Off") { crd.turnOff() }
        case .disabledButRunning:
            Button("Stop Host") { crd.reconcile() }
        case .turningOn, .turningOff:
            Text("Please wait…")
        case .crdNotInstalled, .crdNotSetUp:
            Button("Set Up Chrome Remote Desktop…") { openCRDWebsite() }
        }

        if !crd.helperInstalled {
            Divider()
            Text("Helper not installed: Turn Off will ask for a password")
            Button("Install Helper…") { crd.installHelper() }
        }

        Divider()

        Toggle("Launch at Login", isOn: Binding(
            get: { launchAtLogin },
            set: { setLaunchAtLogin($0) }
        ))
        Button("Open Chrome Remote Desktop Website") { openCRDWebsite() }
        Button("Refresh Status") { crd.refresh() }

        Divider()

        Button("About Remote Desktop Toggle") { showAbout() }
        Button("Uninstall…") { crd.uninstall() }
        Button("Quit") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func openCRDWebsite() {
        if let url = URL(string: "https://remotedesktop.google.com/access") {
            NSWorkspace.shared.open(url)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            crd.lastError = "Launch at Login: \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(string:
                "A menu-bar switch for Chrome Remote Desktop.\n"
                + "github.com/hassansys2/remote-desktop-toggle\n\n"
                + "Not affiliated with or endorsed by Google."),
        ])
    }
}
