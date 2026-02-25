
import SwiftUI
import LeetPulseDesignSystem

struct PointerMarker: Identifiable, Hashable {
    let id: String
    let name: String
    let index: Int?
    let nodeId: String?
    let color: Color
    /// The raw pointer value text for display alongside curves (e.g. "node3", "5").
    let valueText: String?

    init(
        name: String,
        index: Int? = nil,
        nodeId: String? = nil,
        valueText: String? = nil,
        theme: DSTheme
    ) {
        id = "\(name)-\(index ?? -1)-\(nodeId ?? "none")"
        self.name = name
        self.index = index
        self.nodeId = nodeId
        self.valueText = valueText
        color = PointerPalette.color(for: name, theme: theme)
    }
}

struct PointerMotion: Identifiable {
    let id: String
    let name: String
    let fromIndex: Int
    let toIndex: Int
    let color: Color
    let valueText: String?

    init(name: String, fromIndex: Int, toIndex: Int, valueText: String? = nil, theme: DSTheme) {
        id = "\(name)-\(fromIndex)-\(toIndex)"
        self.name = name
        self.fromIndex = fromIndex
        self.toIndex = toIndex
        self.valueText = valueText
        color = PointerPalette.color(for: name, theme: theme)
    }
}

struct TreePointerMotion: Identifiable {
    let id: String
    let name: String
    let fromId: String
    let toId: String
    let color: Color
    let valueText: String?

    init(name: String, fromId: String, toId: String, valueText: String? = nil, theme: DSTheme) {
        id = "\(name)-\(fromId)-\(toId)"
        self.name = name
        self.fromId = fromId
        self.toId = toId
        self.valueText = valueText
        color = PointerPalette.color(for: name, theme: theme)
    }
}

struct SequenceLink: Identifiable {
    let id: String
    let fromIndex: Int
    let toIndex: Int
    let color: Color

    init(fromIndex: Int, toIndex: Int, color: Color) {
        id = "\(fromIndex)-\(toIndex)-\(color)"
        self.fromIndex = fromIndex
        self.toIndex = toIndex
        self.color = color
    }
}

enum PointerPalette {
    static func color(for name: String, theme: DSTheme) -> Color {
        let colors: [Color] = [
            theme.vizColors.secondary,
            theme.vizColors.quinary,
            theme.vizColors.tertiary,
            theme.vizColors.primary,
            theme.vizColors.senary
        ]
        let index = abs(name.lowercased().hashValue) % colors.count
        return colors[index].opacity(0.9)
    }
}

struct PointerBadge: View {
    let text: String
    let color: Color
    let fontSize: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let valueText: String?

    init(
        text: String,
        color: Color,
        fontSize: CGFloat = 8,
        horizontalPadding: CGFloat = 6,
        verticalPadding: CGFloat = 2,
        valueText: String? = nil
    ) {
        self.text = text
        self.color = color
        self.fontSize = fontSize
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.valueText = valueText
    }

    @Environment(\.dsTheme) var theme

    var body: some View {
        Text(text)
            .font(VizTypography.pointerBadge(size: fontSize))
            .foregroundColor(theme.colors.foregroundOnViz)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                Capsule()
                    .fill(color)
            )
    }
}
