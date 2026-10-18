import AppKit
import SwiftUI

// MARK: - Colors

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Palette {
    static let expo = Color(hex: 0x8B7CFF)
    static let xcode = Color(hex: 0x4EA1FF)
    static let android = Color(hex: 0x3DDC84)
    static let live = Color(hex: 0x32D74B)
    static let warning = Color(hex: 0xFFB340)
    static let danger = Color(hex: 0xFF5D5D)
    static let ink = Color(hex: 0x090B10)
}

// MARK: - Platform card

struct PlatformCard<Content: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let statusText: String
    let isActive: Bool
    let content: Content

    init(
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        statusText: String,
        isActive: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.tint = tint
        self.statusText = statusText
        self.isActive = isActive
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(isActive ? 0.22 : 0.10))
                        .frame(width: 28, height: 28)
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isActive ? tint : Color.white.opacity(0.45))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.94))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.34))
                        .lineLimit(1)
                }

                Spacer(minLength: 6)
                StatusPill(text: statusText, tint: tint, active: isActive)
            }

            content
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(isActive ? 0.08 : 0.02), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            tint.opacity(isActive ? 0.34 : 0.10),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
        .shadow(color: tint.opacity(isActive ? 0.13 : 0), radius: 18, y: 7)
        .animation(.easeInOut(duration: 0.3), value: isActive)
    }
}

// MARK: - Status

struct StatusPill: View {
    let text: String
    let tint: Color
    let active: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(active ? tint : Color.white.opacity(0.24))
                .frame(width: 5, height: 5)
            Text(text.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.5)
        }
        .foregroundStyle(active ? tint : Color.white.opacity(0.34))
        .fixedSize()
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(active ? tint.opacity(0.12) : Color.white.opacity(0.04))
        }
        .animation(.easeInOut(duration: 0.25), value: active)
    }
}

struct PulsingDot: View {
    let active: Bool
    let color: Color

    @State private var pulse = false

    var body: some View {
        ZStack {
            if active {
                Circle()
                    .fill(color.opacity(0.25))
                    .frame(width: 13, height: 13)
                    .scaleEffect(pulse ? 1.3 : 0.65)
                    .opacity(pulse ? 0 : 0.9)
            }
            Circle()
                .fill(active ? color : Color.white.opacity(0.26))
                .frame(width: 6, height: 6)
        }
        .frame(width: 14, height: 14)
        .onAppear { startPulse() }
        .onChange(of: active) { _, _ in startPulse() }
    }

    private func startPulse() {
        pulse = false
        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
            pulse = true
        }
    }
}

// MARK: - Chips and buttons

struct StatChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 7, weight: .semibold))
            Text(text)
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.48))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background {
            Capsule().fill(Color.white.opacity(0.045))
        }
    }
}

struct ActionButton: View {
    let title: String
    let symbol: String
    let tint: Color
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 8, weight: .semibold))
                Text(title)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
            }
            .foregroundStyle(hovering ? .white : Color.white.opacity(0.68))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(tint.opacity(hovering ? 0.22 : 0.10))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(tint.opacity(hovering ? 0.35 : 0.16), lineWidth: 0.7)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(title)
    }
}

struct IconButton: View {
    let symbol: String
    var tint: Color = Color.white.opacity(0.62)
    var help: String = ""
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(hovering ? .white : tint)
                .frame(width: 25, height: 25)
                .background {
                    Circle().fill(Color.white.opacity(hovering ? 0.12 : 0.055))
                }
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(hovering ? 0.12 : 0.05), lineWidth: 0.7)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

// MARK: - Rows

struct ActivityRow: View {
    let title: String
    let detail: String
    let elapsed: String?
    let cpu: Double
    let tint: Color
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 22, height: 22)
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 8.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.34))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

            if cpu >= 0.5 {
                Text(String(format: "%.0f%%", cpu))
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }

            if let elapsed {
                Text(elapsed)
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.44))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background {
                        Capsule().fill(Color.white.opacity(0.05))
                    }
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.032))
        }
    }
}

struct SimulatorRow: View {
    let simulator: SimulatorDevice
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint.opacity(0.85))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(simulator.name)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                Text(simulator.runtime)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
            }

            Spacer()

            HStack(spacing: 4) {
                Circle().fill(Palette.live).frame(width: 4, height: 4)
                Text("BOOTED")
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(.white.opacity(0.36))
            }
        }
        .padding(.vertical, 3)
    }
}

struct AndroidDeviceRow: View {
    let device: AndroidDevice
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: device.isEmulator ? "candybarphone" : "iphone")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint.opacity(0.85))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(device.model)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                Text(device.id)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(device.isOnline ? Palette.live : Palette.warning)
                    .frame(width: 4, height: 4)
                Text(device.displayState.uppercased())
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(.white.opacity(0.36))
            }
        }
        .padding(.vertical, 3)
    }
}

struct RecentBuildRow: View {
    let build: RecentXcodeBuild
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint.opacity(0.15))
                .frame(width: 24, height: 24)
                .overlay {
                    Image(systemName: "app.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(tint.opacity(0.9))
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(build.appName)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
                Text("\(build.platform) · \(compactRelativeTime(build.date))")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.32))
                    .lineLimit(1)
            }

            Spacer()

            IconButton(symbol: "magnifyingglass", tint: tint.opacity(0.8), help: "Show in Finder") {
                Actions.reveal(path: build.path)
            }
        }
        .padding(.top, 2)
    }
}

// MARK: - Misc

struct EmptyState: View {
    let symbol: String
    let text: String
    let hint: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint.opacity(0.75))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                Text(hint)
                    .font(.system(size: 8.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.32))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(.white.opacity(0.27))
    }
}

struct QRCodeView: View {
    let text: String
    let size: CGFloat

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: size, height: size)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: size, height: size)
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.white)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        .onAppear { image = QRCodeGenerator.image(for: text) }
        .onChange(of: text) { _, newValue in
            image = QRCodeGenerator.image(for: newValue)
        }
        .help("Scan with Expo Go")
    }
}

// MARK: - Formatting

func compactRelativeTime(_ date: Date) -> String {
    let seconds = max(0, Int(Date().timeIntervalSince(date)))
    if seconds < 5 { return "just now" }
    if seconds < 60 { return "\(seconds)s ago" }
    if seconds < 3600 { return "\(seconds / 60)m ago" }
    if seconds < 86_400 { return "\(seconds / 3600)h ago" }
    return "\(seconds / 86_400)d ago"
}

func abbreviatePath(_ path: String) -> String {
    guard !path.isEmpty else { return "" }
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    if path == home { return "~" }
    if path.hasPrefix(home + "/") {
        return "~" + path.dropFirst(home.count)
    }
    return path
}

func shortElapsed(_ raw: String) -> String {
    // ps returns e.g. "03:12" or "1-02:03:04". Keep it compact for chips.
    raw.hasPrefix("0") ? String(raw.dropFirst()) : raw
}
