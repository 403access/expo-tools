import Foundation

@MainActor
final class MonitorStore: ObservableObject {
    @Published private(set) var snapshot = MonitorSnapshot()
    @Published private(set) var isRefreshing = false

    private var timer: Timer?
    private var refreshTask: Task<Void, Never>?

    init(startMonitoring: Bool = true, initial: MonitorSnapshot = MonitorSnapshot()) {
        snapshot = initial
        guard startMonitoring else { return }

        refresh()

        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    deinit {
        timer?.invalidate()
        refreshTask?.cancel()
    }

    func refresh() {
        guard refreshTask == nil else { return }

        isRefreshing = true
        refreshTask = Task { [weak self] in
            let newSnapshot = await SystemMonitor.snapshot()
            guard !Task.isCancelled, let self else { return }
            self.snapshot = newSnapshot
            self.isRefreshing = false
            self.refreshTask = nil
        }
    }
}
