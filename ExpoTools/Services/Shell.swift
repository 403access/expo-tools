import Foundation

/// Small, dependency-free process runner used by the monitors.
/// Every call is synchronous and is intended to run off the main actor.
enum Shell {
    private final class OutputBox: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()

        func store(_ newData: Data) {
            lock.lock()
            data = newData
            lock.unlock()
        }

        var value: Data {
            lock.lock()
            defer { lock.unlock() }
            return data
        }
    }

    @discardableResult
    static func run(
        _ executable: String,
        _ arguments: [String],
        timeout: TimeInterval = 5
    ) -> String {
        guard FileManager.default.isExecutableFile(atPath: executable) else { return "" }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = processEnvironment()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return ""
        }

        let box = OutputBox()
        let readGroup = DispatchGroup()
        readGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            box.store(data)
            readGroup.leave()
        }

        if readGroup.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            _ = readGroup.wait(timeout: .now() + 1)
        }

        process.waitUntilExit()
        return String(decoding: box.value, as: UTF8.self)
    }

    /// Reads the tail of a file without loading the whole thing into memory.
    static func tail(of url: URL, bytes: Int = 96_000) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }

        let end = (try? handle.seekToEnd()) ?? 0
        let start = end > UInt64(bytes) ? end - UInt64(bytes) : 0
        try? handle.seek(toOffset: start)
        let data = handle.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }

    static func isRunning(executable: String, arguments: [String]) -> Bool {
        !run(executable, arguments, timeout: 2)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    static func homePath(_ relativePath: String) -> String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(relativePath)
            .path
    }

    private static func processEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        // GUI apps get a very small PATH. Add the usual developer locations.
        let additions = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        let existing = environment["PATH"] ?? ""
        environment["PATH"] = (additions + [existing])
            .filter { !$0.isEmpty }
            .joined(separator: ":")
        return environment
    }
}
