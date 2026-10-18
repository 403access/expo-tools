import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

@MainActor
enum Actions {
    static func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }

    static func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    static func reveal(path: String) {
        guard !path.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    static func stop(pid: Int32) {
        // Expo CLI handles SIGINT gracefully and shuts down Metro.
        kill(pid, SIGINT)
    }

    static func openXcode() {
        openApplication(bundleID: "com.apple.dt.Xcode", fallbackPath: "/Applications/Xcode.app")
    }

    static func openSimulator() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iphonesimulator") {
            open(url)
            return
        }

        let developerDirectory = Shell.run("/usr/bin/xcode-select", ["-p"], timeout: 2)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = URL(fileURLWithPath: developerDirectory)
            .appendingPathComponent("Applications/Simulator.app")
        if FileManager.default.fileExists(atPath: fallback.path) {
            NSWorkspace.shared.open(fallback)
        }
    }

    static func openAndroidStudio() {
        openApplication(bundleID: "com.google.android.studio", fallbackPath: "/Applications/Android Studio.app")
    }

    static func quit() {
        NSApplication.shared.terminate(nil)
    }

    private static func openApplication(bundleID: String, fallbackPath: String) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            open(url)
            return
        }

        let fallback = URL(fileURLWithPath: fallbackPath)
        if FileManager.default.fileExists(atPath: fallback.path) {
            NSWorkspace.shared.open(fallback)
        }
    }

    private static func open(_ url: URL) {
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, _ in }
    }
}

enum QRCodeGenerator {
    private static let context = CIContext()

    static func image(for string: String) -> NSImage? {
        guard !string.isEmpty, let data = string.data(using: .utf8) else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let scale = 10.0
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: scaled.extent.width, height: scaled.extent.height))
    }
}
