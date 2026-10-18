import Darwin
import Foundation

enum SystemMonitor {
    private static let derivedDataRoot = URL(
        fileURLWithPath: Shell.homePath("Library/Developer/Xcode/DerivedData"),
        isDirectory: true
    )

    // MARK: - Public

    static func snapshot() async -> MonitorSnapshot {
        let entries = await detached { processEntries() }

        async let lanIPAsync = detached { localIPAddress() }
        async let derivedDataAsync = detached { scanDerivedData() }
        async let simulatorsAsync = detached { bootedSimulators() }
        async let androidDevicesAsync = detached { connectedAndroidDevices() }
        async let xcodeRunningAsync = detached { isXcodeRunning() }
        async let studioRunningAsync = detached { isAndroidStudioRunning() }
        async let gradleAsync = detached { gradleActivities(entries: entries) }

        let lanIP = await lanIPAsync
        let expo = await expoState(entries, lanIP: lanIP)

        let derivedData = await derivedDataAsync
        let simulators = await simulatorsAsync
        let androidDevices = await androidDevicesAsync
        let xcodeRunning = await xcodeRunningAsync
        let studioRunning = await studioRunningAsync
        let gradle = await gradleAsync

        var xcode = XcodeState(
            isXcodeRunning: xcodeRunning,
            activities: xcodeActivities(entries: entries, derivedData: derivedData),
            simulators: simulators,
            recentBuild: derivedData.recentBuild
        )
        xcode.activities = deduplicated(xcode.activities)

        let android = AndroidState(
            isStudioRunning: studioRunning,
            activities: gradle,
            devices: androidDevices
        )

        return MonitorSnapshot(
            expo: expo,
            xcode: xcode,
            android: android,
            updatedAt: Date()
        )
    }

    // MARK: - Expo / Metro

    private static func expoState(_ entries: [ProcessEntry], lanIP: String?) async -> ExpoState {
        let candidates = entries
            .filter { isExpoProcess($0.command) }
            .sorted { lhs, rhs in
                let left = expoProcessScore(lhs.command)
                let right = expoProcessScore(rhs.command)
                return left == right ? lhs.pid < rhs.pid : left > right
            }
        guard let primary = candidates.first else { return ExpoState() }

        var port: Int?
        var projectPath = ""

        // Prefer a candidate that owns a listening socket; that is the real bundler.
        for candidate in candidates.prefix(4) {
            if let listening = listeningPort(of: candidate.pid) {
                port = listening
                projectPath = workingDirectory(of: candidate.pid) ?? ""
                break
            }
        }

        if projectPath.isEmpty {
            projectPath = workingDirectory(of: primary.pid) ?? ""
        }

        var isResponding = false
        if let port, await metroResponds(port: port) {
            isResponding = true
        } else {
            for fallback in unique([port].compactMap { $0 } + [8081, 8082, 19000, 19001]) {
                if await metroResponds(port: fallback) {
                    port = fallback
                    isResponding = true
                    break
                }
            }
        }

        let resolvedPort = port ?? 8081
        let host = lanIP ?? "localhost"

        return ExpoState(
            server: ExpoServer(
                pid: primary.pid,
                port: resolvedPort,
                projectPath: projectPath,
                elapsed: primary.elapsed,
                cpu: primary.cpu,
                lanURL: "exp://\(host):\(resolvedPort)",
                localURL: "http://localhost:\(resolvedPort)",
                isResponding: isResponding,
                command: primary.command
            )
        )
    }

    /// Prefer the real `node .../@expo/cli` process over the `npm exec` wrapper:
    /// it owns the project working directory and handles SIGINT cleanly.
    private static func expoProcessScore(_ command: String) -> Int {
        let lower = command.lowercased()
        var score = 0
        if lower.contains("npm exec") { score -= 2 }
        if lower.contains("node ") { score += 3 }
        if lower.contains("@expo/cli") { score += 2 }
        if lower.contains("expo start") || lower.contains("expo run:") { score += 1 }
        if lower.contains("metro") { score += 1 }
        return score
    }

    private static func isExpoProcess(_ command: String) -> Bool {
        let lower = command.lowercased()
        guard !lower.contains("expotools.app") else { return false }

        if lower.contains("expo start")
            || lower.contains("expo run:")
            || lower.contains("@expo/cli") {
            return true
        }
        if lower.contains("react-native start") || lower.contains("react-native run-ios") {
            return true
        }
        return lower.contains("metro") && (lower.contains("node") || lower.contains("expo"))
    }

    private static func metroResponds(port: Int) async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(port)/status") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.0
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
            let body = String(decoding: data, as: UTF8.self)
            return body.contains("packager-status:running") || !body.isEmpty
        } catch {
            return false
        }
    }

    // MARK: - Processes

    private static func processEntries() -> [ProcessEntry] {
        let output = Shell.run("/bin/ps", ["-axo", "pid=,pcpu=,etime=,command="], timeout: 5)
        return output.split(separator: "\n").compactMap { line -> ProcessEntry? in
            let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count == 4,
                  let pid = Int32(parts[0]),
                  let cpu = Double(parts[1]) else { return nil }
            let command = String(parts[3])
            guard !command.contains("ExpoTools.app/Contents/MacOS/ExpoTools") else { return nil }
            return ProcessEntry(pid: pid, cpu: cpu, elapsed: String(parts[2]), command: command)
        }
    }

    private static func workingDirectory(of pid: Int32) -> String? {
        let output = Shell.run(
            "/usr/sbin/lsof",
            ["-nP", "-a", "-p", "\(pid)", "-d", "cwd", "-Fn"],
            timeout: 3
        )
        for line in output.split(separator: "\n") where line.hasPrefix("n") {
            let path = String(line.dropFirst())
            if path.hasPrefix("/") { return path }
        }
        return nil
    }

    private static func listeningPort(of pid: Int32) -> Int? {
        let output = Shell.run(
            "/usr/sbin/lsof",
            ["-nP", "-a", "-p", "\(pid)", "-iTCP", "-sTCP:LISTEN", "-Fn"],
            timeout: 3
        )
        var ports: [Int] = []
        for line in output.split(separator: "\n") where line.hasPrefix("n") {
            let address = line.dropFirst()
            guard let colon = address.lastIndex(of: ":") else { continue }
            if let port = Int(address[address.index(after: colon)...]), !ports.contains(port) {
                ports.append(port)
            }
        }
        if ports.contains(8081) { return 8081 }
        return ports.first
    }

    // MARK: - Xcode

    private struct ActiveBuildLog {
        let project: String
        let startedAt: Date
        let modifiedAt: Date
    }

    private struct DerivedDataScan {
        var activeLog: ActiveBuildLog?
        var recentBuild: RecentXcodeBuild?

        static let empty = DerivedDataScan()
    }

    private static func scanDerivedData() -> DerivedDataScan {
        let fileManager = FileManager.default
        guard let projectDirectories = try? fileManager.contentsOfDirectory(
            at: derivedDataRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return .empty
        }

        var scan = DerivedDataScan.empty
        var newestLogDate = Date.distantPast
        var newestAppDate = Date.distantPast
        let now = Date()

        for projectDirectory in projectDirectories {
            let isDirectory = (try? projectDirectory.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDirectory else { continue }

            let projectName = friendlyProjectName(fromDerivedData: projectDirectory.lastPathComponent)

            // Activity logs are a reliable signal that Xcode's UI is building.
            let logsDirectory = projectDirectory.appendingPathComponent("Logs/Build", isDirectory: true)
            if let logs = try? fileManager.contentsOfDirectory(
                at: logsDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey],
                options: [.skipsHiddenFiles]
            ) {
                for log in logs where log.pathExtension == "xcactivitylog" {
                    guard let values = try? log.resourceValues(
                        forKeys: [.contentModificationDateKey, .creationDateKey]
                    ), let modified = values.contentModificationDate else { continue }

                    if modified > newestLogDate {
                        newestLogDate = modified
                        scan.activeLog = ActiveBuildLog(
                            project: projectName,
                            startedAt: values.creationDate ?? modified,
                            modifiedAt: modified
                        )
                    }
                }
            }

            // Recently produced app bundles.
            let productsDirectory = projectDirectory.appendingPathComponent("Build/Products", isDirectory: true)
            guard let configurations = try? fileManager.contentsOfDirectory(
                at: productsDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for configuration in configurations {
                let configIsDirectory = (try? configuration.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                guard configIsDirectory else { continue }

                guard let products = try? fileManager.contentsOfDirectory(
                    at: configuration,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                for product in products where product.pathExtension == "app" {
                    guard let date = (try? product.resourceValues(
                        forKeys: [.contentModificationDateKey]
                    ))?.contentModificationDate, date > newestAppDate else { continue }

                    newestAppDate = date
                    scan.recentBuild = RecentXcodeBuild(
                        appName: product.deletingPathExtension().lastPathComponent,
                        path: product.path,
                        platform: platformName(fromConfiguration: configuration.lastPathComponent),
                        date: date
                    )
                }
            }
        }

        if let activeLog = scan.activeLog, now.timeIntervalSince(activeLog.modifiedAt) > 25 {
            scan.activeLog = nil
        }
        return scan
    }

    private static func xcodeActivities(
        entries: [ProcessEntry],
        derivedData: DerivedDataScan
    ) -> [XcodeBuildActivity] {
        var activities: [XcodeBuildActivity] = []

        for entry in entries where isXcodeBuildProcess(entry.command) {
            let title = flagValue("-scheme", in: entry.command)
                ?? flagValue("-workspace", in: entry.command).map { URL(fileURLWithPath: $0).lastPathComponent }
                ?? flagValue("-project", in: entry.command).map { URL(fileURLWithPath: $0).lastPathComponent }
                ?? "xcodebuild"

            let detail = flagValue("-destination", in: entry.command) ?? "Command line build"
            activities.append(
                XcodeBuildActivity(
                    id: "cli-\(entry.pid)",
                    title: title,
                    detail: detail,
                    elapsed: entry.elapsed,
                    cpu: entry.cpu,
                    source: .commandLine
                )
            )
        }

        if let activeLog = derivedData.activeLog {
            activities.append(
                XcodeBuildActivity(
                    id: "xcode-\(activeLog.project)",
                    title: activeLog.project,
                    detail: "Building in Xcode",
                    elapsed: elapsedString(since: activeLog.startedAt),
                    cpu: 0,
                    source: .xcode
                )
            )
        }

        return activities
    }

    private static func isXcodeBuildProcess(_ command: String) -> Bool {
        let padded = " " + command.lowercased() + " "
        return padded.contains(" xcodebuild ") || padded.contains("/xcodebuild ")
    }

    private static func bootedSimulators() -> [SimulatorDevice] {
        let output = Shell.run(
            "/usr/bin/xcrun",
            ["simctl", "list", "devices", "booted", "--json"],
            timeout: 8
        )
        guard let data = output.data(using: .utf8) else { return [] }

        struct Response: Decodable {
            let devices: [String: [Device]]
        }
        struct Device: Decodable {
            let udid: String
            let name: String
            let state: String
            let isAvailable: Bool?
        }

        guard let response = try? JSONDecoder().decode(Response.self, from: data) else { return [] }
        return response.devices.flatMap { runtime, devices in
            devices
                .filter { $0.state == "Booted" && ($0.isAvailable ?? true) }
                .map {
                    SimulatorDevice(
                        id: $0.udid,
                        name: $0.name,
                        runtime: friendlyRuntime(runtime),
                        state: $0.state
                    )
                }
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func isXcodeRunning() -> Bool {
        Shell.isRunning(executable: "/usr/bin/pgrep", arguments: ["-x", "Xcode"])
    }

    // MARK: - Android

    private static func connectedAndroidDevices() -> [AndroidDevice] {
        guard let adb = adbPath() else { return [] }
        let output = Shell.run(adb, ["devices", "-l"], timeout: 4)
        var devices: [AndroidDevice] = []

        for line in output.split(separator: "\n").dropFirst() {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 2 else { continue }
            let serial = String(parts[0])
            guard serial != "List" else { continue }
            let state = String(parts[1])

            var model: String?
            for part in parts.dropFirst(2) where part.hasPrefix("model:") {
                model = String(part.dropFirst(6)).replacingOccurrences(of: "_", with: " ")
            }

            let isEmulator = serial.hasPrefix("emulator-")
            devices.append(
                AndroidDevice(
                    id: serial,
                    model: model ?? (isEmulator ? "Android Emulator" : "Android device"),
                    state: state,
                    isEmulator: isEmulator
                )
            )
        }

        return devices.sorted {
            if $0.isOnline != $1.isOnline { return $0.isOnline }
            return $0.model.localizedStandardCompare($1.model) == .orderedAscending
        }
    }

    private static func adbPath() -> String? {
        let environment = ProcessInfo.processInfo.environment
        var candidates: [String] = []

        for key in ["ANDROID_HOME", "ANDROID_SDK_ROOT"] {
            if let value = environment[key], !value.isEmpty {
                candidates.append(value + "/platform-tools/adb")
            }
        }
        candidates.append(Shell.homePath("Library/Android/sdk/platform-tools/adb"))
        candidates.append("/opt/homebrew/bin/adb")
        candidates.append("/usr/local/bin/adb")
        candidates.append("/usr/bin/adb")

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func isAndroidStudioRunning() -> Bool {
        Shell.isRunning(
            executable: "/usr/bin/pgrep",
            arguments: ["-f", "Android Studio.app/Contents/MacOS/studio"]
        )
    }

    private static func gradleActivities(entries: [ProcessEntry]) -> [AndroidBuildActivity] {
        let fileManager = FileManager.default
        let daemonRoot = URL(
            fileURLWithPath: Shell.homePath(".gradle/daemon"),
            isDirectory: true
        )

        var recentLogs: [(url: URL, modified: Date)] = []
        if let versions = try? fileManager.contentsOfDirectory(
            at: daemonRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for version in versions {
                let isDirectory = (try? version.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                guard isDirectory else { continue }

                guard let files = try? fileManager.contentsOfDirectory(
                    at: version,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                for file in files where file.lastPathComponent.hasSuffix(".out.log") {
                    guard let modified = (try? file.resourceValues(
                        forKeys: [.contentModificationDateKey]
                    ))?.contentModificationDate else { continue }

                    let pid = daemonPID(fromLogName: file.lastPathComponent)
                    let cpu = entries.first { $0.pid == pid }?.cpu ?? 0
                    if Date().timeIntervalSince(modified) < 20 || cpu > 3 {
                        recentLogs.append((file, modified))
                    }
                }
            }
        }

        recentLogs.sort { $0.modified > $1.modified }

        var activities: [AndroidBuildActivity] = recentLogs.prefix(3).map { item in
            let pid = daemonPID(fromLogName: item.url.lastPathComponent)
            let cpu = pid.flatMap { pid in entries.first { $0.pid == pid }?.cpu } ?? 0
            let task = lastGradleTask(in: item.url)
            return AndroidBuildActivity(
                id: "gradle-daemon-\(pid ?? 0)-\(item.url.path)",
                title: task ?? "Gradle build",
                detail: pid.map { "Gradle daemon · PID \($0)" } ?? "Gradle daemon",
                elapsed: nil,
                cpu: cpu
            )
        }

        if activities.isEmpty {
            // The wrapper/client process only exists while a build is being launched.
            for entry in entries where isGradleClient(entry.command) {
                activities.append(
                    AndroidBuildActivity(
                        id: "gradle-client-\(entry.pid)",
                        title: gradleTask(from: entry.command) ?? "Gradle build",
                        detail: "Gradle client · PID \(entry.pid)",
                        elapsed: entry.elapsed,
                        cpu: entry.cpu
                    )
                )
                if activities.count >= 2 { break }
            }
        }

        if activities.isEmpty {
            // Android Studio builds run inside a persistent daemon. High CPU means it is working.
            for entry in entries where isGradleDaemon(entry.command) && entry.cpu > 8 {
                activities.append(
                    AndroidBuildActivity(
                        id: "gradle-daemon-busy-\(entry.pid)",
                        title: "Gradle build",
                        detail: "Android Studio · PID \(entry.pid)",
                        elapsed: entry.elapsed,
                        cpu: entry.cpu
                    )
                )
                break
            }
        }

        return activities
    }

    private static func isGradleClient(_ command: String) -> Bool {
        command.contains("GradleWrapperMain")
            || command.contains("org.gradle.launcher.GradleMain")
            || command.contains("/gradlew ")
    }

    private static func isGradleDaemon(_ command: String) -> Bool {
        command.contains("GradleDaemon")
    }

    private static func daemonPID(fromLogName name: String) -> Int32? {
        guard name.hasPrefix("daemon-"), let dash = name.firstIndex(of: "-") else { return nil }
        let remainder = name[name.index(after: dash)...]
        let digits = remainder.prefix { $0.isNumber }
        return Int32(digits)
    }

    private static func lastGradleTask(in url: URL) -> String? {
        let text = Shell.tail(of: url)
        for line in text.components(separatedBy: .newlines).reversed() {
            guard let range = line.range(of: "> Task ") else { continue }
            let task = line[range.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: " ")
                .first ?? ""
            if !task.isEmpty { return task }
        }
        return nil
    }

    private static func gradleTask(from command: String) -> String? {
        let tokens = command.split(separator: " ").map(String.init)
        for token in tokens.reversed() where isGradleTaskToken(token) {
            return token
        }
        return nil
    }

    private static func isGradleTaskToken(_ token: String) -> Bool {
        let lower = token.lowercased()
        return lower.hasPrefix(":")
            || lower.contains("assemble")
            || lower.contains("installdebug")
            || lower.contains("installrelease")
            || lower.contains("bundledebug")
            || lower.contains("bundlerelease")
            || lower.contains("connectedandroidtest")
    }

    // MARK: - Helpers

    private static func detached<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await Task.detached(priority: .utility, operation: work).value
    }

    private static func unique(_ ports: [Int]) -> [Int] {
        var seen = Set<Int>()
        return ports.filter { seen.insert($0).inserted }
    }

    private static func deduplicated(_ activities: [XcodeBuildActivity]) -> [XcodeBuildActivity] {
        var seen = Set<String>()
        return activities.filter { seen.insert($0.id).inserted }
    }

    private static func flagValue(_ flag: String, in command: String) -> String? {
        guard let range = command.range(of: flag + " ") else { return nil }
        let rest = command[range.upperBound...]
        guard let first = rest.first else { return nil }

        if first == "\"" || first == "'" {
            let tail = rest.dropFirst()
            guard let end = tail.firstIndex(of: first) else { return String(tail) }
            return String(tail[..<end])
        }

        return rest.split(separator: " ", maxSplits: 1).first.map(String.init)
    }

    private static func elapsedString(since date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds >= 3600 {
            return String(format: "%d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
        }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private static func friendlyProjectName(fromDerivedData name: String) -> String {
        // DerivedData folders look like "MyApp-abcdefghijklmnopqrstuvwx".
        if let range = name.range(of: "-[a-z]{18,}$", options: .regularExpression) {
            return String(name[..<range.lowerBound])
        }
        return name
    }

    private static func platformName(fromConfiguration configuration: String) -> String {
        if configuration.contains("iphonesimulator") { return "iOS Simulator" }
        if configuration.contains("iphoneos") { return "iOS Device" }
        if configuration.contains("macosx") { return "macOS" }
        if configuration.contains("watchsimulator") { return "watchOS Simulator" }
        if configuration.contains("watchos") { return "watchOS Device" }
        if configuration.contains("appletvsimulator") { return "tvOS Simulator" }
        if configuration.contains("appletvos") { return "tvOS Device" }
        if configuration.contains("xrsimulator") { return "visionOS Simulator" }
        return configuration
            .replacingOccurrences(of: "Debug-", with: "")
            .replacingOccurrences(of: "Release-", with: "")
    }

    private static func friendlyRuntime(_ identifier: String) -> String {
        let raw = identifier.components(separatedBy: ".").last ?? identifier
        let parts = raw.split(separator: "-", omittingEmptySubsequences: true)
        guard let platform = parts.first else { return raw }
        let version = parts.dropFirst().joined(separator: ".")
        return version.isEmpty ? String(platform) : "\(platform) \(version)"
    }

    private static func localIPAddress() -> String? {
        var address: String?
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return nil }
        defer { freeifaddrs(interfaces) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard let socketAddress = interface.ifa_addr else { continue }
            guard socketAddress.pointee.sa_family == UInt8(AF_INET) else { continue }

            let name = String(cString: interface.ifa_name)
            guard name == "en0" || name == "en1" else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                socketAddress,
                socklen_t(socketAddress.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            if result == 0 {
                address = String(cString: hostname)
                if name == "en0" { break }
            }
        }
        return address
    }
}
