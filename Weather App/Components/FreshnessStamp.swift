import SwiftUI

struct FreshnessStamp: View {
    let fetchedAt: Date
    let freshness: ForecastFreshness
    let isConnected: Bool
    let timeZone: TimeZone

    var body: some View {
        HStack(spacing: 8) {
            Label(statusTitle, systemImage: statusSymbol)
                .font(DesignTokens.mono(size: 10, weight: .medium))
                .foregroundStyle(statusColor)

            Text(timestampText)
                .font(DesignTokens.mono(size: 10))
                .foregroundStyle(DesignTokens.secondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DesignTokens.chromeFill)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(DesignTokens.border, lineWidth: 0.8))
    }

    private var statusTitle: String {
        if !isConnected { return "Offline" }

        switch freshness {
        case .fresh: return "Aktuell"
        case .aging: return "Heute"
        case .stale: return "Alt"
        }
    }

    private var statusSymbol: String {
        if !isConnected { return "wifi.slash" }

        switch freshness {
        case .fresh: return "checkmark.circle.fill"
        case .aging: return "clock"
        case .stale: return "exclamationmark.triangle"
        }
    }

    private var statusColor: Color {
        if !isConnected { return DesignTokens.darkAccent }

        switch freshness {
        case .fresh: return DesignTokens.rain
        case .aging: return DesignTokens.sun
        case .stale: return DesignTokens.darkAccent
        }
    }

    private var timestampText: String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "HH:mm"
        return "Stand \(formatter.string(from: fetchedAt))"
    }
}
