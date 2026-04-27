import SwiftUI

struct OfflineBanner: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignTokens.sun)

            Text(text)
                .font(DesignTokens.mono(size: 11))
                .foregroundStyle(DesignTokens.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(DesignTokens.sun.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DesignTokens.sun.opacity(0.35), lineWidth: 0.8)
        )
    }
}

