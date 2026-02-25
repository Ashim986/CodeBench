import LeetPulseDesignSystem
import SwiftUI

struct DictionaryEntry: Identifiable {
    let key: String
    let value: TraceValue
    var id: String {
        key
    }
}

/// Clean two-column key-value table layout for hash map rendering.
struct DictionaryStructureRow: View {
    let entries: [DictionaryEntry]
    let pointers: [PointerMarker]
    let bubbleStyle: TraceBubble.Style

    let bubbleSize: CGFloat
    let pointerFontSize: CGFloat
    let pointerHorizontalPadding: CGFloat
    let pointerVerticalPadding: CGFloat
    private let pointerSpacing: CGFloat = 2
    @Environment(\.dsTheme) var theme

    private var pointerHeight: CGFloat {
        pointerFontSize + pointerVerticalPadding * 2 + 4
    }

    init(
        entries: [DictionaryEntry],
        pointers: [PointerMarker],
        bubbleStyle: TraceBubble.Style = .solid,
        bubbleSize: CGFloat = 30,
        pointerFontSize: CGFloat = 8,
        pointerHorizontalPadding: CGFloat = 6,
        pointerVerticalPadding: CGFloat = 2
    ) {
        self.entries = entries
        self.pointers = pointers
        self.bubbleStyle = bubbleStyle
        self.bubbleSize = bubbleSize
        self.pointerFontSize = pointerFontSize
        self.pointerHorizontalPadding = pointerHorizontalPadding
        self.pointerVerticalPadding = pointerVerticalPadding
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(
                Array(entries.enumerated()),
                id: \.element.id
            ) { index, entry in
                let pointerStack = pointersByIndex[index] ?? []
                tableRow(
                    entry: entry,
                    pointerStack: pointerStack,
                    isLast: index == entries.count - 1
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    theme.colors.border.opacity(0.3),
                    lineWidth: 1
                )
        )
    }

    @ViewBuilder
    private func tableRow(
        entry: DictionaryEntry,
        pointerStack: [PointerMarker],
        isLast: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !pointerStack.isEmpty {
                HStack(spacing: pointerSpacing) {
                    ForEach(pointerStack) { pointer in
                        PointerBadge(
                            text: pointer.name,
                            color: pointer.color,
                            fontSize: pointerFontSize,
                            horizontalPadding: pointerHorizontalPadding,
                            verticalPadding: pointerVerticalPadding
                        )
                        .frame(height: pointerHeight)
                    }
                }
                .padding(.leading, DSLayout.spacing(8))
            }

            HStack(spacing: 0) {
                // Key column
                Text(entry.key)
                    .font(theme.typography.mono)
                    .foregroundColor(theme.colors.textSecondary)
                    .frame(
                        minWidth: 60,
                        alignment: .trailing
                    )
                    .padding(.horizontal, DSLayout.spacing(8))
                    .padding(.vertical, DSLayout.spacing(6))

                // Separator
                Rectangle()
                    .fill(theme.colors.border.opacity(0.3))
                    .frame(width: 1)

                // Value column
                Text(valueText(for: entry.value))
                    .font(theme.typography.mono)
                    .foregroundColor(theme.colors.textPrimary)
                    .frame(
                        minWidth: 80,
                        alignment: .leading
                    )
                    .padding(.horizontal, DSLayout.spacing(8))
                    .padding(.vertical, DSLayout.spacing(6))
            }
        }
        .padding(.top, pointerStack.isEmpty ? 0 : 4)

        if !isLast {
            Rectangle()
                .fill(theme.colors.border.opacity(0.2))
                .frame(height: 1)
        }
    }

    private func valueText(for value: TraceValue) -> String {
        switch value {
        case .null:
            return "null"
        case let .bool(boolValue):
            return boolValue ? "true" : "false"
        case let .number(num, isInt):
            return isInt ? "\(Int(num))" : "\(num)"
        case let .string(str):
            return str
        case let .array(items):
            let preview = items.prefix(3)
                .map(\.shortDescription)
                .joined(separator: ", ")
            return "[\(preview)]"
        case let .object(map):
            let preview = map.keys.sorted().prefix(2)
                .joined(separator: ", ")
            return "{\(preview)}"
        default:
            return value.shortDescription
        }
    }

    private var pointersByIndex: [Int: [PointerMarker]] {
        var grouped: [Int: [PointerMarker]] = [:]
        for pointer in pointers {
            guard let index = pointer.index else { continue }
            grouped[index, default: []].append(pointer)
        }
        return grouped
    }
}
