import LeetPulseDesignSystem
import SwiftUI

private struct SequenceLane {
    var lastEndX: CGFloat
    let offset: CGFloat
}

private struct SequenceSpan {
    let start: CGFloat
    let end: CGFloat
}

private struct SequenceLinkSpan {
    let link: SequenceLink
    let start: CGFloat
    let end: CGFloat

    var length: CGFloat {
        end - start
    }
}

private struct SequenceLaneContext {
    let minGap: CGFloat
    let baseOffset: CGFloat
    let unit: CGFloat
}

extension SequenceBubbleRow {
    func xPosition(for index: Int) -> CGFloat {
        guard xPositions.indices.contains(index) else { return bubbleSize / 2 }
        return xPositions[index]
    }

    var xPositions: [CGFloat] {
        guard !renderItems.isEmpty else { return [] }
        var positions: [CGFloat] = []
        var current = bubbleSize / 2
        positions.append(current)
        for index in 1 ..< renderItems.count {
            let previousIndex = index - 1
            var spacing = centerSpacing
            if gapIndices.contains(previousIndex) {
                spacing += gapSpacing
            }
            current += spacing
            positions.append(current)
        }
        return positions
    }

    func drawArrowHead(context: inout GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = max(sqrt(dx * dx + dy * dy), 0.001)
        let ux = dx / length
        let uy = dy / length
        let base = CGPoint(x: to.x - ux * arrowHeadSize, y: to.y - uy * arrowHeadSize)
        let perp = CGPoint(x: -uy, y: ux)
        let halfWidth = arrowHeadSize * 0.6
        let left = CGPoint(x: base.x + perp.x * halfWidth, y: base.y + perp.y * halfWidth)
        let right = CGPoint(x: base.x - perp.x * halfWidth, y: base.y - perp.y * halfWidth)
        var head = Path()
        head.move(to: to)
        head.addLine(to: left)
        head.addLine(to: right)
        head.closeSubpath()
        context.fill(head, with: .color(color))
    }

    func drawCycleArrow(
        context: inout GraphicsContext,
        startX: CGFloat,
        endX: CGFloat,
        y: CGFloat,
        bubbleRadius: CGFloat,
        loopInset: CGFloat
    ) {
        let start = CGPoint(x: startX, y: y - bubbleRadius - 2)
        let end = CGPoint(x: endX, y: y - bubbleRadius - 2)
        if abs(start.x - end.x) < 1 {
            let radius = bubbleRadius * 0.7
            let center = CGPoint(x: start.x, y: start.y - radius - 2)
            let startAngle = Angle.degrees(20)
            let endAngle = Angle.degrees(340)
            var path = Path()
            path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            context.stroke(path, with: .color(loopArrowColor), lineWidth: arrowLineWidth)
            let endPoint = point(on: center, radius: radius, angle: endAngle)
            let tangentPoint = point(on: center, radius: radius, angle: Angle.degrees(330))
            drawArrowHead(context: &context, from: tangentPoint, to: endPoint, color: loopArrowColor)
            return
        }
        let span = abs(start.x - end.x)
        let additionalLift = min(36, max(12, span * 0.2))
        let controlY = max(2, y - bubbleRadius - loopInset - additionalLift)
        let control = CGPoint(x: (start.x + end.x) / 2, y: controlY)
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        context.stroke(path, with: .color(loopArrowColor), lineWidth: arrowLineWidth)
        drawArrowHead(context: &context, from: control, to: end, color: loopArrowColor)
    }

    func drawPointerMotion(
        context: inout GraphicsContext,
        motion: PointerMotion,
        baseY: CGFloat
    ) {
        let fromIndex = motion.fromIndex
        let toIndex = motion.toIndex
        guard renderItems.indices.contains(fromIndex),
              renderItems.indices.contains(toIndex),
              fromIndex != toIndex else { return }
        let bubbleRadius = bubbleSize / 2
        let direction: CGFloat = toIndex > fromIndex ? 1 : -1
        let start = CGPoint(
            x: xPosition(for: fromIndex) + direction * bubbleRadius,
            y: baseY
        )
        let end = CGPoint(
            x: xPosition(for: toIndex) - direction * bubbleRadius,
            y: baseY
        )
        let span = abs(end.x - start.x)
        let lift = min(28, max(12, span * 0.25))
        let control = CGPoint(x: (start.x + end.x) / 2, y: max(6, baseY - lift))
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        let motionLineWidth = max(1.5, arrowLineWidth - 1.0)
        context.stroke(path, with: .color(motion.color.opacity(0.75)), lineWidth: motionLineWidth)
        drawArrowHead(context: &context, from: control, to: end, color: motion.color.opacity(0.9))
        // Draw pointer name label at curve midpoint
        let midPoint = CGPoint(x: (start.x + end.x) / 2, y: control.y - 6)
        let label = Text(motion.name)
            .font(VizTypography.secondaryLabel)
            .foregroundColor(motion.color)
        context.draw(context.resolve(label), at: midPoint)
    }

    func drawSequenceLink(
        context: inout GraphicsContext,
        link: SequenceLink,
        topBaseY: CGFloat,
        bottomBaseY: CGFloat,
        laneOffset: CGFloat
    ) {
        guard renderItems.indices.contains(link.fromIndex),
              renderItems.indices.contains(link.toIndex),
              link.fromIndex != link.toIndex else { return }
        let useBottom = laneOffset >= 0
        let offsetMagnitude = max(abs(laneOffset), sequenceClearance)
        let adjustedY = useBottom
            ? bottomBaseY + offsetMagnitude
            : topBaseY - offsetMagnitude
        let direction: CGFloat = link.toIndex >= link.fromIndex ? 1 : -1
        let surfaceGap = bubbleSize * 0.04
        let inset = bubbleSize / 2 + surfaceGap
        let endInset = inset + arrowHeadSize * 0.5
        let start = CGPoint(
            x: xPosition(for: link.fromIndex) + direction * inset,
            y: adjustedY
        )
        let end = CGPoint(
            x: xPosition(for: link.toIndex) - direction * endInset,
            y: adjustedY
        )
        let span = abs(end.x - start.x)
        let liftBase = min(28, max(10, span * 0.24))
        let lift = liftBase + offsetMagnitude * 0.35
        let bendDirection: CGFloat = useBottom ? 1 : -1
        let controlY = adjustedY + bendDirection * lift
        let control = CGPoint(x: (start.x + end.x) / 2, y: controlY)
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        context.stroke(path, with: .color(link.color.opacity(0.85)), lineWidth: arrowLineWidth)
        drawArrowHead(context: &context, from: control, to: end, color: link.color.opacity(0.95))
    }

    func sequenceLaneOffsets(for links: [SequenceLink]) -> [String: CGFloat] {
        guard !links.isEmpty else { return [:] }

        let unit = max(8, min(sequenceInset * 0.22, bubbleSize * 0.4))
        let startInset = bubbleSize * 0.33
        let endInset = startInset + arrowHeadSize * 0.55
        let context = SequenceLaneContext(
            minGap: bubbleSize * 0.45,
            baseOffset: sequenceClearance,
            unit: unit
        )
        var topLanes: [SequenceLane] = []
        var bottomLanes: [SequenceLane] = []
        var topSpans: [SequenceSpan] = []
        var assignments: [String: CGFloat] = [:]

        let spans = buildSequenceSpans(for: links, startInset: startInset, endInset: endInset)
        for span in spans {
            let spanRange = SequenceSpan(start: span.start, end: span.end)
            let overlapCount = topSpans.filter { spansOverlap($0, spanRange) }.count
            let useBottom = overlapCount >= 2
            if useBottom {
                let offset = assignSequenceLane(
                    start: span.start,
                    end: span.end,
                    lanes: &bottomLanes,
                    direction: 1,
                    context: context
                )
                assignments[span.link.id] = offset
            } else {
                let offset = assignSequenceLane(
                    start: span.start,
                    end: span.end,
                    lanes: &topLanes,
                    direction: -1,
                    context: context
                )
                assignments[span.link.id] = offset
                topSpans.append(spanRange)
            }
        }
        return assignments
    }

    private func spansOverlap(_ leftSpan: SequenceSpan, _ rightSpan: SequenceSpan) -> Bool {
        leftSpan.start < rightSpan.end && leftSpan.end > rightSpan.start
    }

    private func buildSequenceSpans(
        for links: [SequenceLink],
        startInset: CGFloat,
        endInset: CGFloat
    ) -> [SequenceLinkSpan] {
        links.compactMap { link -> SequenceLinkSpan? in
            let direction: CGFloat = link.toIndex >= link.fromIndex ? 1 : -1
            let startX = xPosition(for: link.fromIndex) + direction * startInset
            let endX = xPosition(for: link.toIndex) - direction * endInset
            let normalizedStart = min(startX, endX)
            let normalizedEnd = max(startX, endX)
            guard normalizedEnd > normalizedStart else { return nil }
            return SequenceLinkSpan(link: link, start: normalizedStart, end: normalizedEnd)
        }
        .sorted { lhs, rhs in
            if lhs.length != rhs.length { return lhs.length > rhs.length }
            return lhs.start < rhs.start
        }
    }

    private func assignSequenceLane(
        start: CGFloat,
        end: CGFloat,
        lanes: inout [SequenceLane],
        direction: CGFloat,
        context: SequenceLaneContext
    ) -> CGFloat {
        var laneIndex: Int?
        for index in lanes.indices where start > lanes[index].lastEndX + context.minGap {
            laneIndex = index
            break
        }
        if laneIndex == nil {
            let idx = lanes.count
            let magnitude = context.baseOffset + CGFloat(idx) * context.unit
            lanes.append(SequenceLane(lastEndX: end, offset: direction * magnitude))
            laneIndex = idx
        } else if let index = laneIndex {
            lanes[index].lastEndX = max(lanes[index].lastEndX, end)
        }
        return lanes[laneIndex ?? 0].offset
    }

    func sequenceArcOffsets(
        links: [SequenceLink],
        laneOffsets: [String: CGFloat],
        arcBaseOffset: CGFloat
    ) -> (min: CGFloat, max: CGFloat) {
        guard !links.isEmpty else { return (0, 0) }
        let inset = bubbleSize / 2 + arrowGap
        let endInset = inset + arrowHeadSize * 0.6
        var minOffset: CGFloat = 0
        var maxOffset: CGFloat = 0
        for link in links {
            guard renderItems.indices.contains(link.fromIndex),
                  renderItems.indices.contains(link.toIndex),
                  link.fromIndex != link.toIndex else { continue }
            let laneOffset = laneOffsets[link.id] ?? 0
            let useBottom = laneOffset >= 0
            let offsetMagnitude = max(abs(laneOffset), sequenceClearance)
            let baseOffset = arcBaseOffset + offsetMagnitude
            let direction: CGFloat = link.toIndex >= link.fromIndex ? 1 : -1
            let startX = xPosition(for: link.fromIndex) + direction * inset
            let endX = xPosition(for: link.toIndex) - direction * endInset
            let span = abs(endX - startX)
            let liftBase = min(28, max(10, span * 0.24))
            let lift = liftBase + offsetMagnitude * 0.35
            let offset = useBottom ? baseOffset : -baseOffset
            let controlOffset = useBottom ? offset + lift : offset - lift
            minOffset = min(minOffset, offset, controlOffset)
            maxOffset = max(maxOffset, offset, controlOffset)
        }
        return (minOffset, maxOffset)
    }

    func point(on center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        let radians = CGFloat(angle.radians)
        return CGPoint(
            x: center.x + cos(radians) * radius,
            y: center.y + sin(radians) * radius
        )
    }

    func bubbleItems(for items: [TraceValue]) -> [TraceBubbleItem] {
        var counts: [String: Int] = [:]
        return items.map { value in
            let key = value.identityKey
            let occurrence = (counts[key] ?? 0) + 1
            counts[key] = occurrence
            return TraceBubbleItem(id: "\(key)#\(occurrence)", value: value)
        }
    }
}
