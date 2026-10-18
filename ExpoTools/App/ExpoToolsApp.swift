import SwiftUI

@main
struct ExpoToolsApp: App {
    @StateObject private var store: MonitorStore

    init() {
        if let path = PreviewRenderer.requestedPath() {
            PreviewRenderer.render(to: path)
            exit(0)
        }

        if CommandLine.arguments.contains("--dump") {
            DiagnosticsCLI.runAndExit()
        }

        _store = StateObject(wrappedValue: MonitorStore())
    }

    var body: some Scene {
        MenuBarExtra {
            DashboardView()
                .environmentObject(store)
        } label: {
            Image(systemName: store.snapshot.hasAnyActivity ? "hammer.fill" : "hammer")
                .font(.system(size: 15, weight: .semibold))
                .accessibilityLabel("Expo Tools build monitor")
        }
        .menuBarExtraStyle(.window)
    }
}
