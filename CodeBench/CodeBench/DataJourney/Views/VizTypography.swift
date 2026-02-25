import SwiftUI

/// Font constants for DataJourney visualization labels.
/// Dense visualization text (7-10pt) has no design system token equivalent.
/// For Canvas GraphicsContext rendering, use the CGFloat size constants.
enum VizTypography {
    // MARK: - Fixed Font Constants

    /// 10pt semibold -- section headers, structure labels
    static let nodeLabel: Font = .system(size: 10, weight: .semibold)

    /// 10pt regular -- secondary info text
    static let nodeInfo: Font = .system(size: 10)

    /// 9pt semibold -- key labels, list labels, pointer badges
    static let secondaryLabel: Font = .system(size: 9, weight: .semibold)

    /// 9pt medium -- category badges, variable names, secondary text
    static let secondaryInfo: Font = .system(size: 9, weight: .medium)

    /// 9pt medium monospaced -- matrix headers, index labels
    static let secondaryMono: Font = .system(size: 9, weight: .medium, design: .monospaced)

    /// 8pt bold -- compact card titles
    static let compactBold: Font = .system(size: 8, weight: .bold)

    /// 8pt semibold -- compact key labels
    static let compactLabel: Font = .system(size: 8, weight: .semibold)

    /// 8pt medium monospaced -- compact comparison values
    static let compactMono: Font = .system(size: 8, weight: .medium, design: .monospaced)

    /// 8pt regular -- compact fallback text
    static let compactInfo: Font = .system(size: 8)

    /// 7pt medium -- micro annotations, flow card detail keys
    static let micro: Font = .system(size: 7, weight: .medium)

    /// 7pt semibold monospaced -- flow card detail values
    static let microMono: Font = .system(size: 7, weight: .semibold, design: .monospaced)

    /// 7pt regular -- overflow count labels
    static let microInfo: Font = .system(size: 7)

    /// 6pt regular -- flow arrow icon, very small annotations
    static let nano: Font = .system(size: 6)

    /// 11pt medium -- empty state hint, section labels
    static let sectionLabel: Font = .system(size: 11, weight: .medium)

    /// 11pt medium monospaced -- full string display
    static let sectionMono: Font = .system(size: 11, weight: .medium, design: .monospaced)

    // MARK: - Dynamic Font Helpers

    /// Bubble text scaled to container: max(8, size * 0.33) semibold
    static func bubbleText(size: CGFloat) -> Font {
        .system(size: max(8, size * 0.33), weight: .semibold)
    }

    /// Change icon scaled to container: max(8, size * 0.25) bold
    static func changeIcon(size: CGFloat) -> Font {
        .system(size: max(8, size * 0.25), weight: .bold)
    }

    /// Index label scaled to container: max(8, size * 0.28) semibold
    static func indexLabel(size: CGFloat) -> Font {
        .system(size: max(8, size * 0.28), weight: .semibold)
    }

    /// Edge/trie label scaled to container: max(8, size * 0.28) bold monospaced
    static func edgeLabelMono(size: CGFloat) -> Font {
        .system(size: max(8, size * 0.28), weight: .bold, design: .monospaced)
    }

    /// Matrix cell text scaled to container: max(8, size * 0.3) semibold monospaced
    static func matrixCell(size: CGFloat) -> Font {
        .system(size: max(8, size * 0.3), weight: .semibold, design: .monospaced)
    }

    /// Pointer badge text at given size: semibold
    static func pointerBadge(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }

    /// Bold icon at given size
    static func iconBold(size: CGFloat) -> Font {
        .system(size: size, weight: .bold)
    }

    /// Semibold text at given size (step labels, chip text)
    static func labelSemibold(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }

    /// Medium text at given size (truncation messages)
    static func labelMedium(size: CGFloat) -> Font {
        .system(size: size, weight: .medium)
    }

    // MARK: - Canvas GraphicsContext Sizes

    /// For Canvas text rendering which requires CGFloat, not Font
    static let canvasNodeSize: CGFloat = 10
    static let canvasPointerSize: CGFloat = 8
    static let canvasIndexSize: CGFloat = 8
}
