import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var coordinator: UsageCoordinator

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("VibeMeter").font(.headline)
                    Text("AI usage at a glance").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await coordinator.refresh() }
                } label: {
                    if coordinator.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .help("Refresh usage")
                .disabled(coordinator.isRefreshing)
            }

            ForEach(ProviderID.allCases) { provider in
                ProviderCardView(provider: provider, state: coordinator.states[provider] ?? .loading)
            }

            Divider()
            HStack {
                SettingsLink { Label("Settings", systemImage: "gear") }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 360)
    }
}
