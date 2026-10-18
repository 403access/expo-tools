import AppKit
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: MonitorStore

    /// `--render` uses a non-scrolling variant because `ImageRenderer` does not
    /// lay out `ScrollView` content offscreen.
    var scrollable = true

    private var snapshot: MonitorSnapshot { store.snapshot }

    var body: some View {
        Group {
            if scrollable {
                shell.frame(width: 392, height: 618)
            } else {
                shell.frame(width: 392)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var shell: some View {
        ZStack {
            background

            if scrollable {
                ScrollView(.vertical, showsIndicators: false) {
                    content
                }
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(spacing: 11) {
            header
            summaryBar
            ExpoCard(state: snapshot.expo)
            XcodeCard(state: snapshot.xcode)
            AndroidCard(state: snapshot.android)
            footer
        }
        .padding(13)
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x07090E), Color(hex: 0x0E111A), Color(hex: 0x090B11)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Palette.expo.opacity(0.22), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 280
            )

            RadialGradient(
                colors: [Palette.xcode.opacity(0.13), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 260
            )

            RadialGradient(
                colors: [Palette.android.opacity(0.09), .clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 300
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x7C6BFF), Color(hex: 0x4534C9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .shadow(color: Palette.expo.opacity(0.45), radius: 10, y: 4)

                Image(systemName: "hammer.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Expo Tools")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Expo · Xcode · Android")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.75)
                    .frame(width: 25, height: 25)
            } else {
                IconButton(symbol: "arrow.clockwise", help: "Refresh now") {
                    store.refresh()
                }
            }

            IconButton(symbol: "power", tint: Palette.danger.opacity(0.75), help: "Quit Expo Tools") {
                Actions.quit()
            }
        }
    }

    // MARK: - Summary

    private var summaryBar: some View {
        HStack(spacing: 8) {
            PulsingDot(
                active: snapshot.hasAnyActivity,
                color: snapshot.activeBuildCount > 0 ? Palette.live : Palette.expo
            )

            Text(statusText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)

            Spacer()

            Text("LIVE")
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Palette.live.opacity(snapshot.hasAnyActivity ? 0.9 : 0.35))

            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 3, height: 3)

            Text(compactRelativeTime(snapshot.updatedAt))
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.34))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            Capsule().fill(Color.white.opacity(0.045))
        }
        .overlay {
            Capsule().strokeBorder(Color.white.opacity(0.055), lineWidth: 0.7)
        }
    }

    private var statusText: String {
        let builds = snapshot.activeBuildCount
        if builds > 0 {
            return builds == 1 ? "1 build in flight" : "\(builds) builds in flight"
        }
        if snapshot.expo.server != nil { return "Metro is running" }
        return "Watching for builds"
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 8))
            Text("Polls every 5s · stays local")
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))

            Spacer()

            Text("v1.0")
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(.white.opacity(0.24))
        .padding(.top, 2)
    }
}

// MARK: - Expo

struct ExpoCard: View {
    let state: ExpoState
    let tint = Palette.expo

    @State private var showStopConfirmation = false

    var body: some View {
        PlatformCard(
            title: "Expo",
            subtitle: "Metro bundler",
            symbol: "chevron.left.forwardslash.chevron.right",
            tint: tint,
            statusText: state.server == nil ? "Idle" : (state.server?.isResponding == true ? "Live" : "Starting"),
            isActive: state.server != nil
        ) {
            if let server = state.server {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(server.projectName)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(1)

                            Text(abbreviatePath(server.projectPath))
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.34))
                                .lineLimit(1)
                                .truncationMode(.middle)

                            HStack(spacing: 5) {
                                StatChip(icon: "number", text: "\(server.port)")
                                StatChip(icon: "cpu", text: "PID \(server.pid)")
                                StatChip(icon: "clock", text: "up \(shortElapsed(server.elapsed))")
                            }
                            .padding(.top, 2)
                        }

                        Spacer(minLength: 4)

                        QRCodeView(text: server.lanURL, size: 62)
                    }

                    HStack(spacing: 6) {
                        ActionButton(title: "Open", symbol: "safari", tint: tint) {
                            Actions.openURL(server.localURL)
                        }
                        ActionButton(title: "Copy URL", symbol: "doc.on.doc", tint: tint) {
                            Actions.copyToPasteboard(server.lanURL)
                        }
                        ActionButton(title: "Folder", symbol: "folder", tint: tint) {
                            Actions.reveal(path: server.projectPath)
                        }

                        Spacer(minLength: 0)

                        IconButton(
                            symbol: "stop.fill",
                            tint: Palette.danger.opacity(0.8),
                            help: "Stop Metro"
                        ) {
                            showStopConfirmation = true
                        }
                    }
                }
                .confirmationDialog(
                    "Stop the Expo dev server?",
                    isPresented: $showStopConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Stop Metro (PID \(server.pid))", role: .destructive) {
                        Actions.stop(pid: server.pid)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            store.refresh()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Sends SIGINT to the detected Metro process.")
                }
            } else {
                EmptyState(
                    symbol: "terminal",
                    text: "No Metro server detected",
                    hint: "npx expo start",
                    tint: tint
                )
            }
        }
    }

    @EnvironmentObject private var store: MonitorStore
}

// MARK: - Xcode

struct XcodeCard: View {
    let state: XcodeState
    let tint = Palette.xcode

    var body: some View {
        PlatformCard(
            title: "Xcode",
            subtitle: "iOS · macOS builds",
            symbol: "hammer",
            tint: tint,
            statusText: statusText,
            isActive: state.isActive || !state.simulators.isEmpty
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(state.activities) { activity in
                    ActivityRow(
                        title: activity.title,
                        detail: activity.detail,
                        elapsed: activity.elapsed,
                        cpu: activity.cpu,
                        tint: tint,
                        symbol: activity.source == .xcode ? "hammer.fill" : "terminal"
                    )
                }

                if !state.simulators.isEmpty {
                    sectionDivider
                    HStack {
                        SectionLabel(text: "Booted simulators")
                        Spacer()
                        ActionButton(title: "Simulator", symbol: "iphone.gen3", tint: tint) {
                            Actions.openSimulator()
                        }
                    }
                    ForEach(state.simulators.prefix(2)) { simulator in
                        SimulatorRow(simulator: simulator, tint: tint)
                    }
                }

                if let recentBuild = state.recentBuild {
                    sectionDivider
                    SectionLabel(text: "Last build")
                    RecentBuildRow(build: recentBuild, tint: tint)
                }

                if state.activities.isEmpty && state.simulators.isEmpty && state.recentBuild == nil {
                    EmptyState(
                        symbol: "hammer",
                        text: "Xcode is idle",
                        hint: state.isXcodeRunning ? "Project open · waiting for a build" : "open -a Xcode",
                        tint: tint
                    )
                }

                HStack(spacing: 6) {
                    ActionButton(title: "Open Xcode", symbol: "arrow.up.forward.app", tint: tint) {
                        Actions.openXcode()
                    }
                    if !state.simulators.isEmpty {
                        ActionButton(title: "Open Simulator", symbol: "iphone.gen3", tint: tint) {
                            Actions.openSimulator()
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 1)
            }
        }
    }

    private var statusText: String {
        if state.isActive { return "Building" }
        if state.isXcodeRunning { return "Open" }
        return "Idle"
    }
}

// MARK: - Android

struct AndroidCard: View {
    let state: AndroidState
    let tint = Palette.android

    var body: some View {
        PlatformCard(
            title: "Android",
            subtitle: "Gradle · devices",
            symbol: "candybarphone",
            tint: tint,
            statusText: statusText,
            isActive: state.isActive || state.hasOnlineDevices
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(state.activities) { activity in
                    ActivityRow(
                        title: activity.title,
                        detail: activity.detail,
                        elapsed: activity.elapsed,
                        cpu: activity.cpu,
                        tint: tint,
                        symbol: "square.stack.3d.up.fill"
                    )
                }

                if !state.devices.isEmpty {
                    if !state.activities.isEmpty { sectionDivider }
                    HStack {
                        SectionLabel(text: "Devices")
                        Spacer()
                        Text("\(state.devices.filter(\.isOnline).count)/\(state.devices.count) online")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.28))
                    }
                    ForEach(state.devices.prefix(3)) { device in
                        AndroidDeviceRow(device: device, tint: tint)
                    }
                }

                if state.activities.isEmpty && state.devices.isEmpty {
                    EmptyState(
                        symbol: "square.stack.3d.up",
                        text: "No Gradle build or emulator",
                        hint: state.isStudioRunning ? "Android Studio is open" : "open -a \"Android Studio\"",
                        tint: tint
                    )
                }

                HStack(spacing: 6) {
                    ActionButton(title: "Android Studio", symbol: "arrow.up.forward.app", tint: tint) {
                        Actions.openAndroidStudio()
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 1)
            }
        }
    }

    private var statusText: String {
        if state.isActive { return "Building" }
        if state.hasOnlineDevices { return "Ready" }
        return "Idle"
    }
}

// MARK: - Shared

private var sectionDivider: some View {
    Rectangle()
        .fill(Color.white.opacity(0.055))
        .frame(height: 1)
        .padding(.vertical, 1)
}
