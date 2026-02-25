import LeetPulseDesignSystemCore
import SwiftUI

/// Displays a string as a full label above a row of character bubbles with index pointers.
/// Supports sliding window highlighting via pointer ranges.
struct StringSequenceView: View {
    let fullString: String
    let characters: [TraceValue]
    let pointers: [PointerMarker]
    let highlightedIndices: Set<Int>
    let bubbleSize: CGFloat
    let pointerFontSize: CGFloat
    let pointerHorizontalPadding: CGFloat
    let pointerVerticalPadding: CGFloat
    @Environment(\.dsTheme) var theme

    init(
        fullString: String,
        characters: [TraceValue],
        pointers: [PointerMarker] = [],
        highlightedIndices: Set<Int> = [],
        bubbleSize: CGFloat = 40,
        pointerFontSize: CGFloat = 10,
        pointerHorizontalPadding: CGFloat = 9,
        pointerVerticalPadding: CGFloat = 3
    ) {
        self.fullString = fullString
        self.characters = characters
        self.pointers = pointers
        self.highlightedIndices = highlightedIndices
        self.bubbleSize = bubbleSize
        self.pointerFontSize = pointerFontSize
        self.pointerHorizontalPadding = pointerHorizontalPadding
        self.pointerVerticalPadding = pointerVerticalPadding
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing(8)) {
            // Full string label
            HStack(spacing: DSLayout.spacing(6)) {
                Text("string")
                    .font(VizTypography.secondaryInfo)
                    .foregroundColor(theme.vizColors.tertiary)
                    .padding(.horizontal, DSLayout.spacing(6))
                    .padding(.vertical, DSLayout.spacing(2))
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.vizColors.tertiary.opacity(0.15))
                    )

                let displayString = fullString.count > 50
                    ? String(fullString.prefix(47)) + "..."
                    : fullString
                Text("\"\(displayString)\"")
                    .font(VizTypography.sectionMono)
                    .foregroundColor(theme.vizColors.tertiary.opacity(0.85))
                    .lineLimit(1)
            }

            // Sliding window highlight bar
            if let windowRange = slidingWindowRange {
                windowHighlightBar(range: windowRange)
            }

            // Character bubbles with indices
            SequenceBubbleRow(
                items: characters,
                showIndices: true,
                cycleIndex: nil,
                isTruncated: false,
                isDoubly: false,
                pointers: pointers,
                highlightedIndices: highlightedIndices.union(windowHighlightIndices),
                bubbleStyle: .solid,
                bubbleSize: bubbleSize,
                pointerFontSize: pointerFontSize,
                pointerHorizontalPadding: pointerHorizontalPadding,
                pointerVerticalPadding: pointerVerticalPadding
            )
        }
    }

    /// Detects a sliding window from pointer pairs like (left, right), (start, end), (i, j).
    private var slidingWindowRange: ClosedRange<Int>? {
        let windowPairs: [(String, String)] = [
            ("left", "right"),
            ("start", "end"),
            ("lo", "hi"),
            ("i", "j")
        ]
        let pointerMap = Dictionary(
            uniqueKeysWithValues: pointers.compactMap { pointer -> (String, Int)? in
                guard let index = pointer.index else { return nil }
                return (pointer.name.lowercased(), index)
            }
        )
        for (startName, endName) in windowPairs {
            if let startIdx = pointerMap[startName],
               let endIdx = pointerMap[endName],
               startIdx <= endIdx,
               characters.indices.contains(startIdx),
               characters.indices.contains(endIdx) {
                return startIdx ... endIdx
            }
        }
        return nil
    }

    /// Indices within the detected sliding window for highlighting.
    private var windowHighlightIndices: Set<Int> {
        guard let range = slidingWindowRange else { return [] }
        return Set(range)
    }

    /// Visual bar showing the sliding window extent.
    @ViewBuilder
    private func windowHighlightBar(range: ClosedRange<Int>) -> some View {
        let charCount = characters.count
        if charCount > 0 {
            let totalChars = CGFloat(charCount)
            let startFraction = CGFloat(range.lowerBound) / totalChars
            let widthFraction = CGFloat(range.count) / totalChars
            HStack(spacing: DSLayout.spacing(0)) {
                Color.clear
                    .frame(width: startFraction * 100, height: 3)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(theme.vizColors.secondary.opacity(0.6))
                    .frame(width: max(4, widthFraction * 100), height: 3)
                Spacer(minLength: 0)
            }
            .frame(height: 3)
        }
    }
}
