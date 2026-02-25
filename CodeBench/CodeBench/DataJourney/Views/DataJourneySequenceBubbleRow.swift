import LeetPulseDesignSystemCore
import SwiftUI

struct SequenceBubbleRow: View {
    let items: [TraceValue]
    let showIndices: Bool
    let cycleIndex: Int?
    let isTruncated: Bool
    let isDoubly: Bool
    let pointers: [PointerMarker]
    let pointerMotions: [PointerMotion]
    let sequenceLinks: [SequenceLink]
    let gapIndices: Set<Int>
    let highlightedIndices: Set<Int>
    let changeTypes: [ChangeType]
    let bubbleStyle: TraceBubble.Style

    let bubbleSize: CGFloat
    let pointerFontSize: CGFloat
    let pointerHorizontalPadding: CGFloat
    let pointerVerticalPadding: CGFloat
    let pointerSpacing: CGFloat
    @Environment(\.dsTheme) var theme

    var centerSpacing: CGFloat {
        bubbleSize * 1.9
    }

    var labelHeight: CGFloat {
        bubbleSize * 0.4
    }

    let labelSpacing: CGFloat = 4
    var arrowGap: CGFloat {
        bubbleSize * 0.04
    }

    var arrowLineWidth: CGFloat {
        max(1.8, bubbleSize * 0.067)
    }

    var arrowHeadSize: CGFloat {
        bubbleSize * 0.27
    }

    var pointerMotionInset: CGFloat {
        pointerMotions.isEmpty ? 0 : max(12, bubbleSize * 0.55)
    }

    var sequenceInset: CGFloat {
        sequenceLinks.isEmpty ? 0 : max(14, bubbleSize * 0.85)
    }

    var sequenceClearance: CGFloat {
        bubbleSize * 0.25
    }

    var motionInset: CGFloat {
        pointerMotionInset + sequenceInset
    }

    var gapSpacing: CGFloat {
        max(10, bubbleSize * 0.8)
    }

    var arrowColor: Color {
        theme.vizColors.quinary.opacity(0.8)
    }

    var loopArrowHeight: CGFloat {
        bubbleSize * 0.6
    }

    var loopArrowColor: Color {
        theme.vizColors.quinary.opacity(0.95)
    }

    var doublyOffset: CGFloat {
        bubbleSize * 0.32
    }

    var pointerHeight: CGFloat {
        pointerFontSize + pointerVerticalPadding * 2 + 4
    }

    init(
        items: [TraceValue],
        showIndices: Bool,
        cycleIndex: Int?,
        isTruncated: Bool,
        isDoubly: Bool,
        pointers: [PointerMarker],
        pointerMotions: [PointerMotion] = [],
        sequenceLinks: [SequenceLink] = [],
        gapIndices: Set<Int> = [],
        highlightedIndices: Set<Int> = [],
        changeTypes: [ChangeType] = [],
        bubbleStyle: TraceBubble.Style = .solid,
        bubbleSize: CGFloat = 30,
        pointerFontSize: CGFloat = 8,
        pointerHorizontalPadding: CGFloat = 6,
        pointerVerticalPadding: CGFloat = 2,
        pointerSpacing: CGFloat = 2
    ) {
        self.items = items
        self.showIndices = showIndices
        self.cycleIndex = cycleIndex
        self.isTruncated = isTruncated
        self.isDoubly = isDoubly
        self.pointers = pointers
        self.pointerMotions = pointerMotions
        self.sequenceLinks = sequenceLinks
        self.gapIndices = gapIndices
        self.highlightedIndices = highlightedIndices
        self.changeTypes = changeTypes
        self.bubbleStyle = bubbleStyle
        self.bubbleSize = bubbleSize
        self.pointerFontSize = pointerFontSize
        self.pointerHorizontalPadding = pointerHorizontalPadding
        self.pointerVerticalPadding = pointerVerticalPadding
        self.pointerSpacing = pointerSpacing
    }

    var body: some View {
        let bubbleItems = bubbleItems(for: renderItems)
        let cycleTarget = resolvedCycleIndex
        let loopInset = cycleTarget == nil ? 0 : loopArrowHeight
        let motionInset = motionInset
        let maxPointerCount = pointersByIndex.values.map(\.count).max() ?? 0
        let pointerInset = maxPointerCount == 0
            ? 0
            : CGFloat(maxPointerCount) * (pointerHeight + pointerSpacing) + 4
        let groupHeight = bubbleSize + (showIndices ? (labelHeight + labelSpacing) : 0)
        let totalWidth = (xPositions.last ?? bubbleSize / 2) + bubbleSize / 2
        let sequenceOffsets = sequenceLaneOffsets(for: sequenceLinks)
        let baseRowTop = loopInset + pointerInset + motionInset
        let baseHeight = groupHeight + loopInset + pointerInset + motionInset + (isDoubly ? doublyOffset : 0)
        let arcBaseOffset = bubbleSize / 2 + arrowGap
        let (minOffset, maxOffset) = sequenceArcOffsets(
            links: sequenceLinks,
            laneOffsets: sequenceOffsets,
            arcBaseOffset: arcBaseOffset
        )
        let extraTop = max(0, -(baseRowTop + bubbleSize / 2 + minOffset))
        let extraBottom = max(0, baseRowTop + bubbleSize / 2 + maxOffset - baseHeight)
        let rowHeight = baseHeight + extraTop + extraBottom
        let rowCenterY = baseRowTop + extraTop + bubbleSize / 2
        let topBaseY = rowCenterY - arcBaseOffset
        let bottomBaseY = rowCenterY + arcBaseOffset

        return ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    guard renderItems.count > 1 else { return }
                    let y = loopInset + pointerInset + motionInset + extraTop + bubbleSize / 2
                    let bubbleRadius = bubbleSize / 2
                    for index in 0 ..< (renderItems.count - 1) {
                        if gapIndices.contains(index) { continue }
                        let start = CGPoint(
                            x: xPosition(for: index) + bubbleRadius + arrowGap,
                            y: y
                        )
                        let end = CGPoint(
                            x: xPosition(for: index + 1) - bubbleRadius - arrowGap,
                            y: y
                        )
                        guard end.x > start.x else { continue }
                        var path = Path()
                        path.move(to: start)
                        path.addLine(to: end)
                        context.stroke(path, with: .color(arrowColor), lineWidth: arrowLineWidth)
                        drawArrowHead(context: &context, from: start, to: end, color: arrowColor)

                        if isDoubly {
                            let backY = y + doublyOffset
                            let backStart = CGPoint(
                                x: xPosition(for: index + 1) - bubbleRadius - arrowGap,
                                y: backY
                            )
                            let backEnd = CGPoint(
                                x: xPosition(for: index) + bubbleRadius + arrowGap,
                                y: backY
                            )
                            guard backStart.x > backEnd.x else { continue }
                            var backPath = Path()
                            backPath.move(to: backStart)
                            backPath.addLine(to: backEnd)
                            context.stroke(backPath, with: .color(arrowColor.opacity(0.75)), lineWidth: arrowLineWidth)
                            drawArrowHead(
                                context: &context,
                                from: backStart,
                                to: backEnd,
                                color: arrowColor.opacity(0.85)
                            )
                        }
                    }

                    if let cycleTarget {
                        let tailIndex = max(items.count - 1, 0)
                        let startX = xPosition(for: tailIndex)
                        let endX = xPosition(for: cycleTarget)
                        drawCycleArrow(
                            context: &context,
                            startX: startX,
                            endX: endX,
                            y: y,
                            bubbleRadius: bubbleRadius,
                            loopInset: loopInset
                        )
                    }

                    let motionTop = loopInset + extraTop
                    if !sequenceLinks.isEmpty, sequenceInset > 0 {
                        for link in sequenceLinks {
                            drawSequenceLink(
                                context: &context,
                                link: link,
                                topBaseY: topBaseY,
                                bottomBaseY: bottomBaseY,
                                laneOffset: sequenceOffsets[link.id] ?? 0
                            )
                        }
                    }
                    if !pointerMotions.isEmpty, pointerMotionInset > 0 {
                        let pointerY = motionTop
                            + sequenceInset
                            + min(
                                pointerMotionInset - 6,
                                max(8, pointerMotionInset * 0.55)
                            )
                        for motion in pointerMotions {
                            drawPointerMotion(
                                context: &context,
                                motion: motion,
                                baseY: pointerY
                            )
                        }
                    }
                }
                .frame(width: totalWidth, height: rowHeight)

                ForEach(Array(bubbleItems.enumerated()), id: \.element.id) { index, item in
                    let model = TraceBubbleModel.from(item.value, theme: theme)
                    let fill = model.fill
                    let isHighlighted = highlightedIndices.contains(index)
                    let elementChangeType: ChangeType? = index < changeTypes.count
                        ? changeTypes[index]
                        : nil
                    ZStack(alignment: .top) {
                        VStack(spacing: showIndices ? labelSpacing : 0) {
                            TraceBubble(
                                text: model.text,
                                fill: fill,
                                size: bubbleSize,
                                style: bubbleStyle,
                                highlighted: isHighlighted,
                                changeType: elementChangeType,
                                isNull: model.isNull
                            )
                            if showIndices {
                                Text("\(index)")
                                    .font(VizTypography.indexLabel(size: bubbleSize))
                                    .foregroundColor(theme.colors.textSecondary)
                                    .frame(height: labelHeight)
                            }
                        }
                        if let pointerStack = pointersByIndex[index] {
                            VStack(spacing: pointerSpacing) {
                                ForEach(pointerStack) { pointer in
                                    PointerBadge(
                                        text: pointer.name,
                                        color: pointer.color,
                                        fontSize: pointerFontSize,
                                        horizontalPadding: pointerHorizontalPadding,
                                        verticalPadding: pointerVerticalPadding,
                                        valueText: pointer.valueText
                                    )
                                    .frame(height: pointerHeight)
                                }
                            }
                            .offset(y: -pointerInset)
                        }
                    }
                    .frame(width: bubbleSize, height: groupHeight, alignment: .top)
                    .position(
                        x: xPosition(for: index),
                        y: loopInset + pointerInset + motionInset + extraTop + groupHeight / 2
                    )
                }
            }
            .frame(width: totalWidth, height: rowHeight)
            .padding(.vertical, DSLayout.spacing(2))
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: renderItems)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: pointers.map(\.id))
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: pointerMotions.map(\.id))
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: gapIndices)
    }

    var renderItems: [TraceValue] {
        if isTruncated {
            return items + [.string("...")]
        }
        return items
    }

    private var resolvedCycleIndex: Int? {
        guard let cycleIndex else { return nil }
        return (0 ..< items.count).contains(cycleIndex) ? cycleIndex : nil
    }

    private var pointersByIndex: [Int: [PointerMarker]] {
        var grouped: [Int: [PointerMarker]] = [:]
        for pointer in pointers {
            guard let index = pointer.index else { continue }
            grouped[index, default: []].append(pointer)
        }
        for key in grouped.keys {
            grouped[key]?.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return grouped
    }
}

struct TraceBubbleItem: Identifiable {
    let id: String
    let value: TraceValue
}
