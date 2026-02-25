import SwiftUI

// MARK: - DSTheme

struct DSTheme {
    let colors = Colors()
    let vizColors = VizColors()
    let typography = Typography()

    struct Colors {
        let textPrimary: Color = .primary
        let textSecondary: Color = .secondary
        let primary: Color = .blue
        let warning: Color = .orange
        let danger: Color = .red
        let surface: Color = Color(white: 0.95)
        let surfaceElevated: Color = .white
        let foregroundOnViz: Color = .white
        let border: Color = Color.gray.opacity(0.3)
        let background: Color = Color(white: 0.98)
    }

    struct VizColors {
        let primary: Color = .blue
        let secondary: Color = .cyan
        let tertiary: Color = .green
        let quinary: Color = .gray
        let senary: Color = .red
    }

    struct Typography {
        let subtitle: Font = .headline
        let caption: Font = .caption
        let mono: Font = .system(size: 11, weight: .regular, design: .monospaced)
    }
}

// MARK: - DSTheme Environment Key

private struct DSThemeKey: EnvironmentKey {
    static let defaultValue = DSTheme()
}

extension EnvironmentValues {
    var dsTheme: DSTheme {
        get { self[DSThemeKey.self] }
        set { self[DSThemeKey.self] = newValue }
    }
}

// MARK: - DSLayout

enum DSLayout {
    static func spacing(_ value: CGFloat) -> CGFloat { value }
    static func padding(_ value: CGFloat) -> CGFloat { value }
}

// MARK: - DSCard

struct DSCard<Content: View>: View {
    let config: DSCardConfig
    @ViewBuilder let content: () -> Content

    init(config: DSCardConfig = DSCardConfig(), @ViewBuilder content: @escaping () -> Content) {
        self.config = config
        self.content = content
    }

    var body: some View {
        content()
            .padding(config.padding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: config.style == .elevated ? Color.black.opacity(0.08) : .clear, radius: 4, y: 2)
            )
    }
}

struct DSCardConfig {
    enum Style { case elevated, flat }
    let style: Style
    let padding: CGFloat
    init(style: Style = .flat, padding: CGFloat = 16) {
        self.style = style
        self.padding = padding
    }
}

// MARK: - DSButton

struct DSButton: View {
    let title: String
    let config: DSButtonConfig
    let action: () -> Void

    init(_ title: String, config: DSButtonConfig = DSButtonConfig(), action: @escaping () -> Void) {
        self.title = title
        self.config = config
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if config.iconPosition == .leading, let icon = config.icon {
                    icon
                }
                Text(title)
                if config.iconPosition == .trailing, let icon = config.icon {
                    icon
                }
            }
            .font(config.size == .small ? .caption : .body)
            .foregroundColor(buttonForeground)
            .padding(.horizontal, config.size == .small ? 8 : 12)
            .padding(.vertical, config.size == .small ? 4 : 8)
            .background(buttonBackground)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var buttonForeground: Color {
        switch config.style {
        case .primary: return .white
        case .secondary: return .blue
        case .ghost: return .primary
        }
    }

    private var buttonBackground: Color {
        switch config.style {
        case .primary: return .blue
        case .secondary: return Color.blue.opacity(0.1)
        case .ghost: return .clear
        }
    }
}

struct DSButtonConfig {
    enum Style { case primary, secondary, ghost }
    enum Size { case small, medium }
    enum IconPosition { case leading, trailing }
    let style: Style
    let size: Size
    let icon: Image?
    let iconPosition: IconPosition

    init(style: Style = .primary, size: Size = .medium, icon: Image? = nil, iconPosition: IconPosition = .trailing) {
        self.style = style
        self.size = size
        self.icon = icon
        self.iconPosition = iconPosition
    }
}

// MARK: - DSActionButton

struct DSActionButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) { label() }
            .buttonStyle(.plain)
    }
}

// MARK: - AccessibilityID

enum AccessibilityID {
    enum DataJourney {
        static let playbackControls = "datajourney.playback.controls"
        static let structureCanvas = "datajourney.structure.canvas"
        static let canvas = "datajourney.canvas"
    }
}

// MARK: - AppStrings

enum AppStrings {
    static let a11yDataJourneyCanvas = "Data journey canvas showing %@"
    static let a11yDataJourneyValue = "%d values: %@"
}
