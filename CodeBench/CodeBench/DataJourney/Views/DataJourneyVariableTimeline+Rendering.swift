import LeetPulseDesignSystemCore
import SwiftUI

// MARK: - Rendering Views

extension VariableTimelineView {
    // MARK: - Sparkline (numeric values)

    func sparklineView(
        series: [TimelinePoint]
    ) -> some View {
        let values = series.map { $0.numericValue ?? 0 }
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 1
        let range = max(maxVal - minVal, 1)
        let width = CGFloat(series.count) * 12
        let height: CGFloat = 24

        return ZStack(alignment: .topLeading) {
            Canvas { context, size in
                guard values.count > 1 else { return }
                var path = Path()
                for (index, value) in values.enumerated() {
                    let xPos = CGFloat(index)
                        / CGFloat(max(values.count - 1, 1))
                        * size.width
                    let yPos = size.height
                        - ((value - minVal) / range)
                        * size.height
                    if index == 0 {
                        path.move(to: CGPoint(x: xPos, y: yPos))
                    } else {
                        path.addLine(to: CGPoint(x: xPos, y: yPos))
                    }
                }
                context.stroke(
                    path,
                    with: .color(
                        theme.vizColors.secondary.opacity(0.7)
                    ),
                    lineWidth: 1.5
                )

                if currentIndex < values.count {
                    let cx = CGFloat(currentIndex)
                        / CGFloat(max(values.count - 1, 1))
                        * size.width
                    let cy = size.height
                        - ((values[currentIndex] - minVal) / range)
                        * size.height
                    var dot = Path()
                    dot.addEllipse(
                        in: CGRect(
                            x: cx - 3, y: cy - 3,
                            width: 6, height: 6
                        )
                    )
                    context.fill(
                        dot,
                        with: .color(theme.vizColors.secondary)
                    )
                }
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .onTapGesture { location in
                let index = Int(
                    (location.x / width)
                        * CGFloat(series.count)
                )
                let clamped = max(0, min(series.count - 1, index))
                onSelectIndex(clamped)
            }
        }
        .frame(width: width, height: height)
    }

    // MARK: - Bar Chart (collection sizes)

    func barChartView(
        series: [TimelinePoint]
    ) -> some View {
        let sizes = series.map { $0.collectionSize ?? 0 }
        let maxSize = CGFloat(sizes.max() ?? 1)
        let barWidth: CGFloat = 8
        let spacing: CGFloat = 3
        let height: CGFloat = 24

        return HStack(alignment: .bottom, spacing: spacing) {
            ForEach(
                Array(sizes.enumerated()), id: \.offset
            ) { index, size in
                let barHeight = max(
                    2,
                    (CGFloat(size) / max(maxSize, 1)) * height
                )
                let isCurrent = index == currentIndex
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        isCurrent
                            ? theme.vizColors.secondary
                            : theme.vizColors.quinary.opacity(0.5)
                    )
                    .frame(width: barWidth, height: barHeight)
                    .onTapGesture { onSelectIndex(index) }
            }
        }
        .frame(height: height, alignment: .bottom)
    }

    // MARK: - Dot View (mixed/boolean)

    func dotView(
        series: [TimelinePoint]
    ) -> some View {
        HStack(spacing: DSLayout.spacing(4)) {
            ForEach(
                Array(series.enumerated()), id: \.offset
            ) { index, point in
                let isCurrent = index == currentIndex
                Circle()
                    .fill(dotColor(for: point))
                    .frame(
                        width: isCurrent ? 8 : 6,
                        height: isCurrent ? 8 : 6
                    )
                    .overlay(
                        isCurrent
                            ? Circle().stroke(
                                theme.colors.foregroundOnViz,
                                lineWidth: 1
                            )
                            : nil
                    )
                    .onTapGesture { onSelectIndex(index) }
            }
        }
    }

    func dotColor(for point: TimelinePoint) -> Color {
        switch point.kind {
        case .boolTrue:
            theme.vizColors.tertiary
        case .boolFalse:
            theme.vizColors.senary
        case .null:
            theme.colors.textSecondary.opacity(0.85)
        default:
            theme.vizColors.primary.opacity(0.6)
        }
    }
}
