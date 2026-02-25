
import LeetPulseDesignSystem
import SwiftUI

struct TreeGraphView: View {
    let tree: TraceTree
    let pointers: [PointerMarker]
    let pointerMotions: [TreePointerMotion]
    let highlightedNodeIds: Set<String>
    let nodeSize: CGFloat
    let pointerFontSize: CGFloat
    let pointerHorizontalPadding: CGFloat
    let pointerVerticalPadding: CGFloat
    let bubbleStyle: TraceBubble.Style
    private let levelSpacing: CGFloat = 60
    private let pointerSpacing: CGFloat = 2
    @Environment(\.dsTheme) var theme
    @State private var cachedTreeLayout: TraceTreeLayout?
    @State private var overflowNodeCount = 0

    private let maxVisualizationNodes = 40

    private var pointerHeight: CGFloat {
        pointerFontSize + pointerVerticalPadding * 2 + 4
    }

    init(
        tree: TraceTree,
        pointers: [PointerMarker],
        pointerMotions: [TreePointerMotion] = [],
        highlightedNodeIds: Set<String> = [],
        bubbleStyle: TraceBubble.Style = .solid,
        nodeSize: CGFloat = 30,
        pointerFontSize: CGFloat = 8,
        pointerHorizontalPadding: CGFloat = 6,
        pointerVerticalPadding: CGFloat = 2
    ) {
        self.tree = tree
        self.pointers = pointers
        self.pointerMotions = pointerMotions
        self.highlightedNodeIds = highlightedNodeIds
        self.nodeSize = nodeSize
        self.pointerFontSize = pointerFontSize
        self.pointerHorizontalPadding = pointerHorizontalPadding
        self.pointerVerticalPadding = pointerVerticalPadding
        self.bubbleStyle = bubbleStyle
    }

    var body: some View {
        let layout = cachedTreeLayout ?? makeTreeLayout()
        let topPadding = pointerMotions.isEmpty ? 0 : nodeSize * 0.8
        let bottomPadding = pointerMotions.count >= 3 ? nodeSize * 0.6 : 0
        let yOffset = topPadding
        let pointersById = groupedPointers
        let positions = Dictionary(uniqueKeysWithValues: layout.nodes.map {
            ($0.id, CGPoint(x: $0.position.x, y: $0.position.y + yOffset))
        })
        let totalHeight = layout.height + topPadding + bottomPadding
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack {
                    Canvas { context, _ in
                        for edge in layout.edges {
                            let from = CGPoint(x: edge.from.x, y: edge.from.y + yOffset)
                            let to = CGPoint(x: edge.to.x, y: edge.to.y + yOffset)
                            let controlX = (from.x + to.x) / 2
                            let controlY = from.y + (to.y - from.y) * 0.3
                            var path = Path()
                            path.move(to: from)
                            path.addQuadCurve(
                                to: to,
                                control: CGPoint(x: controlX, y: controlY)
                            )
                            context.stroke(
                                path,
                                with: .color(theme.vizColors.quinary.opacity(0.55)),
                                lineWidth: 1.5
                            )
                        }

                        for (index, motion) in pointerMotions.enumerated() {
                            guard let from = positions[motion.fromId],
                                  let to = positions[motion.toId],
                                  from != to else { continue }
                            let useBottom = index >= 2
                            let laneIndex = max(0, useBottom ? index - 2 : index)
                            drawPointerMotion(
                                context: &context,
                                motion: motion,
                                from: from,
                                to: to,
                                laneIndex: laneIndex,
                                useBottom: useBottom
                            )
                        }
                    }

                    ForEach(layout.nodes) { node in
                        ZStack(alignment: .top) {
                            TraceValueNode(
                                value: node.value,
                                size: nodeSize,
                                style: bubbleStyle,
                                highlighted: highlightedNodeIds.contains(node.id)
                            )
                            if let pointerStack = pointersById[node.id] {
                                let stackHeight = CGFloat(pointerStack.count) * pointerHeight +
                                    CGFloat(max(pointerStack.count - 1, 0)) * pointerSpacing
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
                                    }
                                }
                                .offset(y: -(nodeSize / 2 + stackHeight))
                            }
                        }
                        .position(CGPoint(x: node.position.x, y: node.position.y + yOffset))
                    }
                }
                .frame(width: layout.width, height: totalHeight)
            }
            .frame(height: totalHeight)
            if overflowNodeCount > 0 {
                Text("...and \(overflowNodeCount) more")
                    .font(VizTypography.secondaryLabel)
                    .foregroundStyle(theme.colors.textSecondary)
                    .padding(.top, 4)
            }
        }
        .onAppear {
            cachedTreeLayout = makeTreeLayout()
        }
        .onChange(of: tree) { _, _ in
            cachedTreeLayout = makeTreeLayout()
        }
    }

    private func makeTreeLayout() -> TraceTreeLayout {
        let totalNodeCount = tree.nodes.count
        let layout = TraceTreeLayout(tree: tree, nodeSize: nodeSize, levelSpacing: levelSpacing, maxNodes: maxVisualizationNodes)
        let renderedCount = layout.nodes.count
        overflowNodeCount = max(0, totalNodeCount - renderedCount)
        return layout
    }

    private func drawPointerMotion(
        context: inout GraphicsContext,
        motion: TreePointerMotion,
        from: CGPoint,
        to: CGPoint,
        laneIndex: Int,
        useBottom: Bool
    ) {
        let direction: CGFloat = from.x <= to.x ? 1 : -1
        let surfaceOffset = nodeSize * 0.5
        let yShift = useBottom ? surfaceOffset : -surfaceOffset
        let start = CGPoint(
            x: from.x + direction * nodeSize * 0.35,
            y: from.y + yShift
        )
        let end = CGPoint(
            x: to.x - direction * nodeSize * 0.35,
            y: to.y + yShift
        )
        let span = abs(end.x - start.x)
        let baseLift = min(56, max(16, span * 0.25))
        let lift = baseLift + CGFloat(laneIndex) * 12
        let controlY = useBottom
            ? max(start.y, end.y) + lift
            : min(start.y, end.y) - lift
        let control = CGPoint(x: (start.x + end.x) / 2, y: controlY)
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        context.stroke(
            path, with: .color(motion.color.opacity(0.85)), lineWidth: 1.8
        )
        drawArrowHead(
            context: &context, from: control, to: end,
            color: motion.color.opacity(0.95)
        )
        // Draw pointer name label at curve midpoint
        let labelY = useBottom ? control.y + 8 : control.y - 8
        let label = Text(motion.name)
            .font(VizTypography.secondaryLabel)
            .foregroundColor(motion.color)
        context.draw(
            context.resolve(label),
            at: CGPoint(x: control.x, y: labelY)
        )
    }

    private func drawArrowHead(
        context: inout GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        color: Color
    ) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = max(sqrt(dx * dx + dy * dy), 0.001)
        let ux = dx / length
        let uy = dy / length
        let arrowSize: CGFloat = 6
        let base = CGPoint(x: to.x - ux * arrowSize, y: to.y - uy * arrowSize)
        let perp = CGPoint(x: -uy, y: ux)
        let halfWidth = arrowSize * 0.6
        let left = CGPoint(x: base.x + perp.x * halfWidth, y: base.y + perp.y * halfWidth)
        let right = CGPoint(x: base.x - perp.x * halfWidth, y: base.y - perp.y * halfWidth)
        var head = Path()
        head.move(to: to)
        head.addLine(to: left)
        head.addLine(to: right)
        head.closeSubpath()
        context.fill(head, with: .color(color))
    }

    private var groupedPointers: [String: [PointerMarker]] {
        var grouped: [String: [PointerMarker]] = [:]
        for pointer in pointers {
            guard let nodeId = pointer.nodeId else { continue }
            grouped[nodeId, default: []].append(pointer)
        }
        return grouped
    }
}

struct TraceValueNode: View {
    let value: TraceValue
    let size: CGFloat
    let style: TraceBubble.Style
    let highlighted: Bool
    @Environment(\.dsTheme) var theme

    init(
        value: TraceValue,
        size: CGFloat = 30,
        style: TraceBubble.Style = .solid,
        highlighted: Bool = false
    ) {
        self.value = value
        self.size = size
        self.style = style
        self.highlighted = highlighted
    }

    var body: some View {
        let model = TraceBubbleModel.from(value, theme: theme, compact: true)
        return TraceBubble(
            text: model.text,
            fill: model.fill,
            size: size,
            style: style,
            highlighted: highlighted,
            isNull: model.isNull
        )
    }
}

struct TraceTreeLayout {
    struct Node: Identifiable {
        let id: String
        let value: TraceValue
        let position: CGPoint
    }

    struct Edge: Identifiable {
        let id: String
        let from: CGPoint
        let to: CGPoint
    }

    private struct QueueEntry {
        let id: String
        let level: Int
        let heapIndex: Int
    }

    struct LayoutResult {
        let nodes: [Node]
        let positions: [String: CGPoint]
        let maxLevel: Int
    }

    let nodes: [Node]
    let edges: [Edge]
    let width: CGFloat
    let height: CGFloat

    init(
        tree: TraceTree,
        nodeSize: CGFloat,
        levelSpacing: CGFloat,
        maxNodes: Int = .max
    ) {
        guard let rootId = tree.rootId else {
            nodes = []
            edges = []
            width = nodeSize
            height = nodeSize
            return
        }
        var nodeMap: [String: TraceTreeNode] = [:]
        tree.nodes.forEach { nodeMap[$0.id] = $0 }

        let effectiveWidth = Self.computeEffectiveWidth(
            rootId: rootId, nodeMap: nodeMap,
            nodeSize: nodeSize
        )

        let result = Self.layoutNodes(
            rootId: rootId, nodeMap: nodeMap,
            effectiveWidth: effectiveWidth,
            levelSpacing: levelSpacing, nodeSize: nodeSize,
            maxNodes: maxNodes
        )

        let layoutEdges = Self.buildEdges(
            tree: tree, positions: result.positions,
            nodeSize: nodeSize
        )

        nodes = result.nodes
        edges = layoutEdges
        width = effectiveWidth
        height = CGFloat(result.maxLevel + 1) * levelSpacing
            + nodeSize
    }

    private static func computeEffectiveWidth(
        rootId: String,
        nodeMap: [String: TraceTreeNode],
        nodeSize: CGFloat
    ) -> CGFloat {
        let treeDepth = computeDepth(
            rootId: rootId, nodeMap: nodeMap
        )
        let nodeCount = nodeMap.count
        let maxLeafSlots = CGFloat(1 << max(treeDepth - 1, 0))
        let isSkewed = nodeCount > 2
            && treeDepth > Int(log2(Double(nodeCount))) + 2
        let spacing: CGFloat = isSkewed
            ? nodeSize * 1.4
            : nodeSize * 1.8
        return max(
            (maxLeafSlots + 1) * spacing,
            nodeSize * 4
        )
    }

    private static func layoutNodes(
        rootId: String,
        nodeMap: [String: TraceTreeNode],
        effectiveWidth: CGFloat,
        levelSpacing: CGFloat,
        nodeSize: CGFloat,
        maxNodes: Int = .max
    ) -> LayoutResult {
        var nodes: [Node] = []
        var positions: [String: CGPoint] = [:]
        var maxLevel = 0
        var queue: [QueueEntry] = [
            QueueEntry(id: rootId, level: 0, heapIndex: 1)
        ]
        var visited = Set<String>()

        while !queue.isEmpty {
            let entry = queue.removeFirst()
            guard let node = nodeMap[entry.id],
                  !visited.contains(entry.id) else { continue }
            guard nodes.count < maxNodes else { continue }
            visited.insert(entry.id)
            maxLevel = max(maxLevel, entry.level)
            let countAtLevel = 1 << entry.level
            let indexInLevel = entry.heapIndex
                - (1 << entry.level)
            let x = CGFloat(indexInLevel + 1)
                * effectiveWidth / CGFloat(countAtLevel + 1)
            let y = CGFloat(entry.level) * levelSpacing
                + nodeSize / 2
            let position = CGPoint(x: x, y: y)
            nodes.append(Node(
                id: node.id,
                value: node.value,
                position: position
            ))
            positions[node.id] = position

            if let leftId = node.left {
                queue.append(QueueEntry(
                    id: leftId,
                    level: entry.level + 1,
                    heapIndex: entry.heapIndex * 2
                ))
            }
            if let rightId = node.right {
                queue.append(QueueEntry(
                    id: rightId,
                    level: entry.level + 1,
                    heapIndex: entry.heapIndex * 2 + 1
                ))
            }
        }

        return LayoutResult(
            nodes: nodes, positions: positions,
            maxLevel: maxLevel
        )
    }

    private static func buildEdges(
        tree: TraceTree,
        positions: [String: CGPoint],
        nodeSize: CGFloat
    ) -> [Edge] {
        var edges: [Edge] = []
        for node in tree.nodes {
            guard let parentPos = positions[node.id]
            else { continue }
            if let leftId = node.left,
               let leftPos = positions[leftId] {
                edges.append(Edge(
                    id: "tree-edge-\(node.id)-\(leftId)",
                    from: CGPoint(
                        x: parentPos.x,
                        y: parentPos.y + nodeSize / 2
                    ),
                    to: CGPoint(
                        x: leftPos.x,
                        y: leftPos.y - nodeSize / 2
                    )
                ))
            }
            if let rightId = node.right,
               let rightPos = positions[rightId] {
                edges.append(Edge(
                    id: "tree-edge-\(node.id)-\(rightId)",
                    from: CGPoint(
                        x: parentPos.x,
                        y: parentPos.y + nodeSize / 2
                    ),
                    to: CGPoint(
                        x: rightPos.x,
                        y: rightPos.y - nodeSize / 2
                    )
                ))
            }
        }
        return edges
    }

    /// Compute tree depth from root using DFS.
    private static func computeDepth(
        rootId: String,
        nodeMap: [String: TraceTreeNode]
    ) -> Int {
        guard nodeMap[rootId] != nil else { return 0 }
        var maxDepth = 0
        var stack: [(id: String, depth: Int)] = [
            (rootId, 1)
        ]
        var visited = Set<String>()
        while !stack.isEmpty {
            let (currentId, depth) = stack.removeLast()
            guard let node = nodeMap[currentId],
                  visited.insert(currentId).inserted
            else { continue }
            maxDepth = max(maxDepth, depth)
            if let leftId = node.left {
                stack.append((leftId, depth + 1))
            }
            if let rightId = node.right {
                stack.append((rightId, depth + 1))
            }
        }
        return maxDepth
    }
}
