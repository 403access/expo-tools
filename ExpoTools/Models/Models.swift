import Foundation

// MARK: - Process

struct ProcessEntry: Identifiable, Sendable {
    let pid: Int32
    let cpu: Double
    let elapsed: String
    let command: String

    var id: Int32 { pid }
}

// MARK: - Expo / Metro

struct ExpoServer: Sendable {
    let pid: Int32
    let port: Int
    let projectPath: String
    let elapsed: String
    let cpu: Double
    let lanURL: String
    let localURL: String
    let isResponding: Bool
    let command: String

    var projectName: String {
        guard !projectPath.isEmpty else { return "Expo project" }
        return URL(fileURLWithPath: projectPath).lastPathComponent
    }
}

struct ExpoState: Sendable {
    var server: ExpoServer?
}

// MARK: - Xcode

enum XcodeBuildSource: String, Sendable {
    case commandLine
    case xcode
}

struct XcodeBuildActivity: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let elapsed: String?
    let cpu: Double
    let source: XcodeBuildSource
}

struct SimulatorDevice: Identifiable, Sendable {
    let id: String
    let name: String
    let runtime: String
    let state: String
}

struct RecentXcodeBuild: Sendable {
    let appName: String
    let path: String
    let platform: String
    let date: Date
}

struct XcodeState: Sendable {
    var isXcodeRunning = false
    var activities: [XcodeBuildActivity] = []
    var simulators: [SimulatorDevice] = []
    var recentBuild: RecentXcodeBuild?

    var isActive: Bool { !activities.isEmpty }
}

// MARK: - Android

struct AndroidDevice: Identifiable, Sendable {
    let id: String
    let model: String
    let state: String
    let isEmulator: Bool

    var isOnline: Bool { state == "device" }
    var displayState: String {
        switch state {
        case "device": return "Online"
        case "offline": return "Offline"
        case "unauthorized": return "Unauthorized"
        default: return state.capitalized
        }
    }
}

struct AndroidBuildActivity: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let elapsed: String?
    let cpu: Double
}

struct AndroidState: Sendable {
    var isStudioRunning = false
    var activities: [AndroidBuildActivity] = []
    var devices: [AndroidDevice] = []

    var isActive: Bool { !activities.isEmpty }
    var hasOnlineDevices: Bool { devices.contains { $0.isOnline } }
}

// MARK: - Snapshot

struct MonitorSnapshot: Sendable {
    var expo = ExpoState()
    var xcode = XcodeState()
    var android = AndroidState()
    var updatedAt = Date()

    var activeBuildCount: Int {
        xcode.activities.count + android.activities.count
    }

    var hasAnyActivity: Bool {
        expo.server != nil || activeBuildCount > 0
    }
}
