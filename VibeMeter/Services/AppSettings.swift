import Foundation
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    enum MenuDisplayMode: String, CaseIterable, Identifiable {
        case lowest
        case providers
        case iconOnly

        var id: String { rawValue }
        var title: String {
            switch self {
            case .lowest: "Lowest remaining"
            case .providers: "Claude and Codex"
            case .iconOnly: "Icon only"
            }
        }
    }

    private enum Key {
        static let menuMode = "menuDisplayMode"
        static let codexPath = "codexExecutablePath"
        static let alerts = "alertsEnabled"
        static let thresholds = "alertThresholds"
    }

    private let defaults: UserDefaults

    @Published var menuDisplayMode: MenuDisplayMode {
        didSet { defaults.set(menuDisplayMode.rawValue, forKey: Key.menuMode) }
    }
    @Published var codexExecutablePath: String {
        didSet { defaults.set(codexExecutablePath, forKey: Key.codexPath) }
    }
    @Published var alertsEnabled: Bool {
        didSet { defaults.set(alertsEnabled, forKey: Key.alerts) }
    }
    @Published var alertThresholds: [String: Double] {
        didSet {
            if let data = try? JSONEncoder().encode(alertThresholds) {
                defaults.set(data, forKey: Key.thresholds)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        menuDisplayMode = MenuDisplayMode(rawValue: defaults.string(forKey: Key.menuMode) ?? "") ?? .lowest
        codexExecutablePath = defaults.string(forKey: Key.codexPath) ?? ""
        alertsEnabled = defaults.bool(forKey: Key.alerts)
        if let data = defaults.data(forKey: Key.thresholds),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            alertThresholds = decoded
        } else {
            alertThresholds = [:]
        }
    }

    func threshold(for window: UsageWindow) -> Double {
        alertThresholds[window.id] ?? 20
    }

    func setThreshold(_ value: Double, for window: UsageWindow) {
        alertThresholds[window.id] = value
    }

    var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() }
        else { try SMAppService.mainApp.unregister() }
        objectWillChange.send()
    }
}
