import AppKit
import SwiftUI

/// Renders the dashboard to a PNG without starting the menu bar app.
/// Usage: `ExpoTools.app/Contents/MacOS/ExpoTools --render /tmp/dashboard.png`
enum PreviewRenderer {
    static func requestedPath() -> String? {
        guard let index = CommandLine.arguments.firstIndex(of: "--render"),
              CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return CommandLine.arguments[index + 1]
    }

    @MainActor
    static func render(to path: String) {
        _ = NSApplication.shared

        let store = MonitorStore(startMonitoring: false, initial: .demo)
        let renderer = ImageRenderer(content: DashboardView(scrollable: false).environmentObject(store))
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let representation = NSBitmapImageRep(data: tiff),
              let png = representation.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("failed to render dashboard\n".utf8))
            return
        }

        try? png.write(to: URL(fileURLWithPath: path))
    }
}

extension MonitorSnapshot {
    /// Sample data used by `--render` and SwiftUI previews.
    static let demo = MonitorSnapshot(
        expo: ExpoState(
            server: ExpoServer(
                pid: 48213,
                port: 8081,
                projectPath: "/Users/me/Projects/acme-mobile",
                elapsed: "04:12",
                cpu: 12.4,
                lanURL: "exp://192.168.1.24:8081",
                localURL: "http://localhost:8081",
                isResponding: true,
                command: "node /Users/me/Projects/acme-mobile/node_modules/.bin/expo start"
            )
        ),
        xcode: XcodeState(
            isXcodeRunning: true,
            activities: [
                XcodeBuildActivity(
                    id: "xcode-demo",
                    title: "acme-mobile",
                    detail: "Building in Xcode",
                    elapsed: "1:32",
                    cpu: 0,
                    source: .xcode
                ),
                XcodeBuildActivity(
                    id: "cli-demo",
                    title: "AcmeWidgets",
                    detail: "platform=iOS Simulator,name=iPhone 16 Pro",
                    elapsed: "0:48",
                    cpu: 63,
                    source: .commandLine
                )
            ],
            simulators: [
                SimulatorDevice(id: "7AD86EEA", name: "iPhone 16 Pro", runtime: "iOS 18.4", state: "Booted"),
                SimulatorDevice(id: "BRT02K7P", name: "iPad Pro 13-inch", runtime: "iOS 26.4", state: "Booted")
            ],
            recentBuild: RecentXcodeBuild(
                appName: "acme-mobile",
                path: "/Users/me/Library/Developer/Xcode/DerivedData/acme-mobile/Build/Products/Debug-iphonesimulator/acme-mobile.app",
                platform: "iOS Simulator",
                date: Date().addingTimeInterval(-420)
            )
        ),
        android: AndroidState(
            isStudioRunning: true,
            activities: [
                AndroidBuildActivity(
                    id: "gradle-demo",
                    title: ":app:compileDebugKotlin",
                    detail: "Gradle daemon · PID 91337",
                    elapsed: nil,
                    cpu: 41
                )
            ],
            devices: [
                AndroidDevice(id: "emulator-5554", model: "Pixel 9 Pro", state: "device", isEmulator: true),
                AndroidDevice(id: "R58M10ABCDE", model: "Galaxy S24", state: "device", isEmulator: false)
            ]
        ),
        updatedAt: Date().addingTimeInterval(-2)
    )
}
