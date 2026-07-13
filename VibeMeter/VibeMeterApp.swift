import SwiftUI

@main
struct VibeMeterApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var coordinator: UsageCoordinator

    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _coordinator = StateObject(wrappedValue: UsageCoordinator(settings: settings))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(coordinator: coordinator)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "waveform.path.ecg.rectangle")
                if !coordinator.menuBarTitle.isEmpty {
                    Text(coordinator.menuBarTitle).monospacedDigit()
                }
            }
            .accessibilityLabel("VibeMeter \(coordinator.menuBarTitle)")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(coordinator: coordinator, settings: settings)
        }
    }
}
