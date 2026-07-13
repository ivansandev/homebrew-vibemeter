import SwiftUI

struct UsageWindowRow: View {
    let window: UsageWindow

    private var color: Color {
        switch window.remainingPercent {
        case ..<10: .red
        case ..<25: .orange
        default: .accentColor
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.displayName)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(window.remainingPercent.rounded()))%")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            }
            ProgressView(value: window.remainingPercent, total: 100)
                .tint(color)
                .accessibilityLabel("\(window.displayName) remaining")
                .accessibilityValue("\(Int(window.remainingPercent.rounded())) percent")
            if let reset = window.resetsAt {
                Text("Resets \(reset, style: .relative) · \(reset, format: .dateTime.weekday(.abbreviated).hour().minute())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
