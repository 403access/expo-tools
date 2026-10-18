import Dispatch
import Foundation

enum DiagnosticsCLI {
    /// Runs one monitor pass synchronously and prints it. Used by `--dump`.
    static func runAndExit() -> Never {
        let semaphore = DispatchSemaphore(value: 0)
        let box = TextBox()

        Task.detached {
            let snapshot = await SystemMonitor.snapshot()
            box.set(snapshot.diagnostics)
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + 25) == .timedOut {
            box.set("Timed out while scanning for builds.")
        }

        FileHandle.standardOutput.write(Data((box.value + "\n").utf8))
        exit(0)
    }

    private final class TextBox: @unchecked Sendable {
        private let lock = NSLock()
        private var text = ""

        func set(_ newValue: String) {
            lock.lock()
            text = newValue
            lock.unlock()
        }

        var value: String {
            lock.lock()
            defer { lock.unlock() }
            return text
        }
    }
}

extension MonitorSnapshot {
    /// Plain-text rendering used by the `--dump` flag.
    var diagnostics: String {
        var lines: [String] = []

        lines.append("Expo / Metro")
        if let server = expo.server {
            lines.append("  • \(server.projectName)  pid=\(server.pid)  port=\(server.port)  responding=\(server.isResponding)")
            lines.append("    path: \(server.projectPath)")
            lines.append("    dev URL: \(server.lanURL)")
        } else {
            lines.append("  • not detected")
        }

        lines.append("")
        lines.append("Xcode")
        lines.append("  • app running: \(xcode.isXcodeRunning)")
        for activity in xcode.activities {
            lines.append("  • build [\(activity.source.rawValue)] \(activity.title) — \(activity.detail)\(activity.elapsed.map { " (\($0))" } ?? "")")
        }
        for simulator in xcode.simulators {
            lines.append("  • simulator \(simulator.name) (\(simulator.runtime))")
        }
        if let build = xcode.recentBuild {
            lines.append("  • last build \(build.appName) — \(build.platform) — \(build.path)")
        }

        lines.append("")
        lines.append("Android")
        lines.append("  • Android Studio running: \(android.isStudioRunning)")
        for activity in android.activities {
            lines.append("  • build \(activity.title) — \(activity.detail)")
        }
        for device in android.devices {
            lines.append("  • device \(device.model) [\(device.id)] \(device.displayState)")
        }

        return lines.joined(separator: "\n")
    }
}
