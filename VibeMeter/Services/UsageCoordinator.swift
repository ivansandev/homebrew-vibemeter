import AppKit
import Foundation
import Network

@MainActor
final class UsageCoordinator: ObservableObject {
    @Published private(set) var states: [ProviderID: ProviderAvailability]
    @Published private(set) var isRefreshing = false

    let settings: AppSettings
    private let store: SnapshotStore
    private let alerts: UsageAlertManager
    private let pathMonitor = NWPathMonitor()
    private var refreshLoop: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?

    init(settings: AppSettings, store: SnapshotStore = .init(), alerts: UsageAlertManager = .init()) {
        self.settings = settings
        self.store = store
        self.alerts = alerts
        let cached = store.load()
        states = Dictionary(uniqueKeysWithValues: ProviderID.allCases.map { provider in
            if let snapshot = cached[provider] {
                return (provider, .available(snapshot, isStale: true))
            }
            return (provider, .loading)
        })

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }

        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in await self?.refresh() }
        }
        pathMonitor.start(queue: DispatchQueue(label: "dev.ivansandev.vibemeter.network"))

        refreshLoop = Task { [weak self] in
            await self?.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                await self?.refresh()
            }
        }
    }

    deinit {
        refreshLoop?.cancel()
        pathMonitor.cancel()
    }

    var snapshots: [ProviderSnapshot] {
        ProviderID.allCases.compactMap { states[$0]?.snapshot }
    }

    var allWindows: [UsageWindow] { snapshots.flatMap(\.windows) }

    var menuBarTitle: String {
        switch settings.menuDisplayMode {
        case .iconOnly:
            return ""
        case .lowest:
            guard let lowest = allWindows.map(\.remainingPercent).min() else { return "--" }
            return "\(Int(lowest.rounded()))%"
        case .providers:
            return ProviderID.allCases.map { provider in
                let value = states[provider]?.snapshot?.windows.map(\.remainingPercent).min()
                let prefix = provider == .claude ? "C" : "X"
                return value.map { "\(prefix) \(Int($0.rounded()))%" } ?? "\(prefix) --"
            }.joined(separator: " · ")
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let providers: [any UsageProvider] = [
            ClaudeUsageProvider(),
            CodexUsageProvider(executableOverride: settings.codexExecutablePath)
        ]

        await withTaskGroup(of: (ProviderID, Result<ProviderSnapshot, Error>).self) { group in
            for provider in providers {
                group.addTask {
                    do { return (provider.id, .success(try await provider.fetchUsage())) }
                    catch { return (provider.id, .failure(error)) }
                }
            }

            for await (provider, result) in group {
                switch result {
                case let .success(snapshot):
                    states[provider] = .available(snapshot, isStale: false)
                case let .failure(error):
                    if let old = states[provider]?.snapshot {
                        states[provider] = .available(old, isStale: true)
                    } else {
                        states[provider] = .unavailable(error.localizedDescription)
                    }
                }
            }
        }

        let current = snapshots
        store.save(current)
        await alerts.evaluate(current, settings: settings)
    }

    func enableAlerts() async -> Bool { await alerts.requestPermission() }
}
