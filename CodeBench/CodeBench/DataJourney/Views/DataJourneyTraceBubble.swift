
import LeetPulseDesignSystemCore
import SwiftUI

struct TraceBubble: View {
    enum Style {
        case solid
    }

    let text: String
    let fill: Color
    let size: CGFloat
    let style: Style
    let highlighted: Bool
    let changeType: ChangeType?
    let isNull: Bool
    @Environment(\.dsTheme) var theme
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor

    init(
        text: String,
        fill: Color,
        size: CGFloat = 30,
        style: Style = .solid,
        highlighted: Bool = false,
        changeType: ChangeType? = nil,
        isNull: Bool = false
    ) {
        self.text = text
        self.fill = fill
        self.size = size
        self.style = style
        self.highlighted = highlighted
        self.changeType = changeType
        self.isNull = isNull
    }

    var body: some View {
        ZStack {
            bubbleBackground
            Text(text)
                .font(VizTypography.bubbleText(size: size))
                .foregroundColor(
                    isNull
                        ? theme.colors.textSecondary.opacity(0.5)
                        : theme.colors.foregroundOnViz
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, DSLayout.spacing(4))
        }
        .frame(width: size, height: size)
        .overlay(nullBorderOverlay)
        .overlay(highlightOverlay)
    }

    @ViewBuilder
    private var nullBorderOverlay: some View {
        if isNull {
            Circle()
                .strokeBorder(
                    theme.colors.textSecondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        switch style {
        case .solid:
            Circle()
                .fill(fill)
        }
    }

    @ViewBuilder
    private var highlightOverlay: some View {
        if highlighted {
            // Comparison highlight: distinct from change glow
            ZStack {
                Circle()
                    .fill(theme.colors.primary.opacity(0.15))
                Circle()
                    .stroke(theme.colors.primary, lineWidth: 2)
                    .shadow(
                        color: theme.colors.primary.opacity(0.5),
                        radius: 4
                    )
            }
        }
        if let changeType {
            changeTypeOverlay(changeType)
        }
    }

    @ViewBuilder
    private func changeTypeOverlay(_ type: ChangeType) -> some View {
        switch type {
        case .added:
            ZStack {
                Circle()
                    .fill(theme.colors.success.opacity(0.1))
                Circle()
                    .stroke(theme.colors.success, lineWidth: 2)
                    .shadow(
                        color: theme.colors.success.opacity(0.5),
                        radius: 4
                    )
                if differentiateWithoutColor {
                    changeIcon(
                        "plus.circle",
                        color: theme.colors.success
                    )
                }
            }
        case .removed:
            ZStack {
                Circle()
                    .fill(theme.colors.danger.opacity(0.25))
                if differentiateWithoutColor {
                    changeIcon(
                        "minus.circle",
                        color: theme.colors.danger
                    )
                }
            }
        case .modified:
            ZStack {
                Circle()
                    .fill(theme.colors.warning.opacity(0.1))
                Circle()
                    .stroke(theme.colors.warning, lineWidth: 2)
                    .shadow(
                        color: theme.colors.warning.opacity(0.5),
                        radius: 4
                    )
                if differentiateWithoutColor {
                    changeIcon(
                        "arrow.triangle.2.circlepath",
                        color: theme.colors.warning
                    )
                }
            }
        case .unchanged:
            EmptyView()
        }
    }

    private func changeIcon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(VizTypography.changeIcon(size: size))
            .foregroundColor(color)
            .offset(x: size * 0.35, y: -size * 0.35)
    }
}

struct TraceBubbleModel {
    let text: String
    let fill: Color
    let isNull: Bool

    init(text: String, fill: Color, isNull: Bool = false) {
        self.text = text
        self.fill = fill
        self.isNull = isNull
    }

    /// Delegates to the centralized `TraceValue.bubbleModel(theme:compact:)` extension.
    static func from(
        _ value: TraceValue,
        theme: DSTheme,
        compact: Bool = false
    ) -> TraceBubbleModel {
        value.bubbleModel(theme: theme, compact: compact)
    }

    static func dictionaryPreview(
        map: [String: TraceValue],
        seed: String?,
        theme: DSTheme
    ) -> String {
        guard !map.isEmpty else { return "[:]" }
        let keys = map.keys.sorted()
        let index = stableIndex(seed: seed ?? keys.joined(separator: "|"), count: keys.count)
        let key = keys[index]
        let keyInitial = initialCharacter(from: key)
        let value = map[key] ?? .null
        let valueInitial = initialCharacter(for: value, theme: theme)
        return "[\(keyInitial):\(valueInitial)]"
    }

    static func arrayInitialPreview(items: [TraceValue], theme: DSTheme) -> String {
        guard let first = items.first else { return "[]" }
        let initial = initialCharacter(for: first, theme: theme)
        return "[\(initial)]"
    }

    static func initialCharacter(for value: TraceValue, theme: DSTheme) -> String {
        switch value {
        case let .string(stringValue):
            return initialCharacter(from: stringValue)
        case let .array(items):
            guard let first = items.first else { return "?" }
            return initialCharacter(for: first, theme: theme)
        case let .list(list):
            guard let first = list.nodes.first?.value else { return "?" }
            return initialCharacter(for: first, theme: theme)
        case let .object(map):
            return initialCharacter(from: dictionaryPreview(map: map, seed: nil, theme: theme))
        case let .typed(_, inner):
            return initialCharacter(for: inner, theme: theme)
        default:
            let text = from(value, theme: theme, compact: true).text
            return initialCharacter(from: text)
        }
    }

    static func initialCharacter(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for char in trimmed {
            if char.isLetter || char.isNumber {
                return String(char)
            }
        }
        return "?"
    }

    static func stableIndex(seed: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let sum = seed.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return abs(sum) % count
    }
}
