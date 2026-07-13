import SwiftUI

struct SettingsView: View {
    @ObservedObject var coordinator: UsageCoordinator
    @ObservedObject var settings: AppSettings
    @State private var launchError: String?

    var body: some View {
        TabView {
            Form {
                Picker("Menu-bar display", selection: $settings.menuDisplayMode) {
                    ForEach(AppSettings.MenuDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Toggle("Launch VibeMeter at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { value in
                        do { try settings.setLaunchAtLogin(value) }
                        catch { launchError = error.localizedDescription }
                    }
                ))
                if let launchError {
                    Text(launchError).font(.caption).foregroundStyle(.red)
                }
                LabeledContent("Refresh interval", value: "5 minutes")
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gear") }

            Form {
                TextField("Codex executable", text: $settings.codexExecutablePath,
                          prompt: Text("Automatically detected"))
                Text("VibeMeter checks Homebrew, ~/.local/bin, NVM installations, and PATH before using this override.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Refresh providers") { Task { await coordinator.refresh() } }
            }
            .formStyle(.grouped)
            .tabItem { Label("Providers", systemImage: "terminal") }

            Form {
                Toggle("Notify when remaining usage is low", isOn: Binding(
                    get: { settings.alertsEnabled },
                    set: { enabled in
                        if enabled {
                            Task {
                                let allowed = await coordinator.enableAlerts()
                                settings.alertsEnabled = allowed
                            }
                        } else {
                            settings.alertsEnabled = false
                        }
                    }
                ))
                if coordinator.allWindows.isEmpty {
                    Text("Thresholds appear after usage loads.").foregroundStyle(.secondary)
                }
                ForEach(coordinator.allWindows) { window in
                    VStack(alignment: .leading) {
                        HStack {
                            Text("\(window.provider.displayName) · \(window.displayName)")
                            Spacer()
                            Text("\(Int(settings.threshold(for: window)))%")
                                .monospacedDigit().foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { settings.threshold(for: window) },
                            set: { settings.setThreshold($0, for: window) }
                        ), in: 5...50, step: 5)
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Alerts", systemImage: "bell") }

            VStack(spacing: 12) {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 52)).foregroundStyle(.tint)
                Text("VibeMeter").font(.title2.bold())
                Text("Version 0.1.0")
                Text("Credentials remain in the macOS Keychain and are never cached or logged.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
            .padding(30)
            .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 420)
    }
}
