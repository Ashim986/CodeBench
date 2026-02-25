
import SwiftUI

/// Shows a compact 3-line code context above the visualization canvas.
///
/// Displays the active line (highlighted) plus one line above and one below,
/// providing code context without leaving the visualization view.
struct DataJourneyCodeContext: View {
    let code: String
    let activeLine: Int?

    @Environment(\.dsTheme) var theme

    var body: some View {
        DSCard(
            config: DSCardConfig(style: .elevated, padding: 8)
        ) {
            contextContent
        }
    }

    @ViewBuilder
    private var contextContent: some View {
        if let activeLine, activeLine > 0, !code.isEmpty {
            let lines = code.components(separatedBy: "\n")
            let lineIndex = min(activeLine - 1, max(0, lines.count - 1))
            let start = max(0, lineIndex - 1)
            let end = min(lines.count - 1, lineIndex + 1)

            if start <= end {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(start ... end, id: \.self) { index in
                        lineRow(
                            lineNumber: index + 1,
                            text: lines[index],
                            isActive: index == lineIndex
                        )
                    }
                }
            } else {
                placeholderView
            }
        } else {
            placeholderView
        }
    }

    private func lineRow(
        lineNumber: Int,
        text: String,
        isActive: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: DSLayout.spacing(6)) {
            Text("\(lineNumber)")
                .font(VizTypography.sectionMono)
                .foregroundColor(
                    theme.colors.textSecondary.opacity(0.5)
                )
                .frame(width: 24, alignment: .trailing)

            Text(text)
                .font(VizTypography.sectionMono)
                .foregroundColor(
                    isActive
                        ? theme.colors.textPrimary
                        : theme.colors.textSecondary
                )
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, DSLayout.spacing(4))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isActive
                ? RoundedRectangle(cornerRadius: 3)
                .fill(theme.colors.primary.opacity(0.15))
                : nil
        )
    }

    private var placeholderView: some View {
        Text("No active line")
            .font(VizTypography.secondaryInfo)
            .foregroundColor(theme.colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
