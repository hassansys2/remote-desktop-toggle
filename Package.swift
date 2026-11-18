// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RemoteDesktopToggle",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "RemoteDesktopToggle",
            path: "Sources/RemoteDesktopToggle"
        )
    ]
)
