import SwiftUI

struct ProviderCardView: View {
    let provider: ProviderID
    let state: ProviderAvailability

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                switch state {
                case .loading:
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Loading usage…").foregroundStyle(.secondary)
                    }
                case let .available(snapshot, isStale):
                    ForEach(snapshot.windows) { window in
                        UsageWindowRow(window: window)
                        if window.id != snapshot.windows.last?.id { Divider() }
                    }
                    HStack {
                        if let plan = snapshot.planName {
                            Text(plan.capitalized)
                        }
                        Spacer()
                        if isStale {
                            Text("Last update failed · showing saved data")
                        } else {
                            MinuteUpdatedLabel(date: snapshot.fetchedAt)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(isStale ? Color.orange : Color.secondary)
                case let .unavailable(message):
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(provider.displayName, systemImage: provider == .claude ? "sparkles" : "terminal")
                .font(.headline)
        }
    }
}

private struct MinuteUpdatedLabel: View {
    let date: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let minutes = max(0, Int(context.date.timeIntervalSince(date) / 60))
            Text(minutes == 0 ? "Updated now" : "Updated \(minutes) min ago")
        }
    }
}
