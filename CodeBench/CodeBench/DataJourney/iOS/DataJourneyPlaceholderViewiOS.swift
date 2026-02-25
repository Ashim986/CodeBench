
import SwiftUI

struct DataJourneyPlaceholderViewiOS: View {
    @Environment(\.dsTheme) var theme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(theme.colors.textSecondary)
            Text("Data Journey")
                .font(theme.typography.subtitle)
                .foregroundStyle(theme.colors.textPrimary)
            Text("Data structure visualization is not available on iOS.")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
