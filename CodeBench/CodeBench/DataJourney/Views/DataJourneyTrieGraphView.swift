
import LeetPulseDesignSystemCore
import SwiftUI

/// Renders a trie as an N-ary tree layout with character-labeled edges and isEnd highlighting.
struct TrieGraphView: View {
    let trie: TraceTrie
    let pointers: [PointerMarker]
    let nodeSize: CGFloat
    let pointerFontSize: CGFloat
    let pointerHorizontalPadding: CGFloat
    let pointerVerticalPadding: CGFloat
    @Environment(\.dsTheme) var theme
    @State private var cachedTrieLayout: TrieLayout?
    @State private var overflowNodeCount = 0

    private let maxVisualizationNodes = 40
    private let horizontalSpacing: CGFloat = 16
    private let verticalSpacing: CGFloat = 60
    private var pointerHeight: CGFloat {
        pointerFontSize + pointerVerticalPadding * 2 + 4
    }

    init(
        trie: TraceTrie,
        pointers: [PointerMarker] = [],
        nodeSize: CGFloat = 40,
        pointerFontSize: CGFloat = 10,
        pointerHorizontalPadding: CGFloat = 9,
        pointerVerticalPadding: CGFloat = 3
    ) {
        self.trie = trie
        self.pointers = pointers
        self.nodeSize = nodeSize
        self.pointerFontSize = pointerFontSize
        self.pointerHorizontalPadding = pointerHorizontalPadding
        self.pointerVerticalPadding = pointerVerticalPadding
    }

    var body: some View {
        let layout = cachedTrieLayout ?? makeTrieLayout()
        let pointerMap = groupedPointers
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    Canvas { context, _ in
                        let halfNode = nodeSize / 2
                        for edge in layout.edges {
                            let from = CGPoint(
                                x: edge.from.x, y: edge.from.y + halfNode
                            )
                            let to = CGPoint(
                                x: edge.to.x, y: edge.to.y - halfNode
                            )
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
                            // Edge character label at curve midpoint
                            let midX = (from.x + to.x) / 2
                            let midY = (from.y + to.y) / 2
                            let text = Text(edge.character)
                                .font(VizTypography.secondaryLabel)
                                .foregroundColor(theme.vizColors.secondary)
                            context.draw(
                                context.resolve(text),
                                at: CGPoint(x: midX - 8, y: midY)
                            )
                        }
                    }
                    .frame(width: layout.totalWidth, height: layout.totalHeight)

                    ForEach(layout.nodes) { node in
                        ZStack(alignment: .top) {
                            let fill = node.isEnd ? theme.vizColors.tertiary.opacity(0.7) : theme.colors.surfaceElevated
                            let label = node.character.isEmpty ? "root" : node.character
                            TraceBubble(
                                text: label,
                                fill: fill,
                                size: nodeSize,
                                style: .solid
                            )
                            if node.isEnd {
                                Circle()
                                    .stroke(theme.vizColors.tertiary, lineWidth: 2)
                                    .frame(width: nodeSize + 4, height: nodeSize + 4)
                            }
                            if let pointerStack = pointerMap[node.id] {
                                let stackHeight = CGFloat(pointerStack.count) * pointerHeight
                                VStack(spacing: DSLayout.spacing(2)) {
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
                        .position(node.position)
                    }
                }
                .frame(width: layout.totalWidth, height: layout.totalHeight)
            }
            if overflowNodeCount > 0 {
                Text("...and \(overflowNodeCount) more")
                    .font(VizTypography.secondaryLabel)
                    .foregroundStyle(theme.colors.textSecondary)
                    .padding(.top, 4)
            }
        }
        .onAppear {
            cachedTrieLayout = makeTrieLayout()
        }
        .onChange(of: trie) { _, _ in
            cachedTrieLayout = makeTrieLayout()
        }
    }

    private func makeTrieLayout() -> TrieLayout {
        let totalNodeCount = trie.nodes.count
        let layout = TrieLayout(trie: trie, nodeSize: nodeSize, hSpacing: horizontalSpacing, vSpacing: verticalSpacing, maxNodes: maxVisualizationNodes)
        let renderedCount = layout.nodes.count
        overflowNodeCount = max(0, totalNodeCount - renderedCount)
        return layout
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

// MARK: - Trie Layout Engine

struct TrieLayout {
    struct LayoutNode: Identifiable {
        let id: String
        let character: String
        let isEnd: Bool
        let position: CGPoint
    }

    struct LayoutEdge: Identifiable {
        let id: String
        let from: CGPoint
        let to: CGPoint
        let character: String
    }

    let nodes: [LayoutNode]
    let edges: [LayoutEdge]
    let totalWidth: CGFloat
    let totalHeight: CGFloat

    init(trie: TraceTrie, nodeSize: CGFloat, hSpacing: CGFloat, vSpacing: CGFloat, maxNodes: Int = .max) {
        let nodeById = Dictionary(uniqueKeysWithValues: trie.nodes.map { ($0.id, $0) })
        guard let rootId = trie.rootId, nodeById[rootId] != nil else {
            nodes = []
            edges = []
            totalWidth = nodeSize
            totalHeight = nodeSize
            return
        }

        // First, determine which node IDs to include via BFS (up to maxNodes)
        var allowedIds = Set<String>()
        var bfsQueue: [String] = [rootId]
        while !bfsQueue.isEmpty, allowedIds.count < maxNodes {
            let nodeId = bfsQueue.removeFirst()
            guard nodeById[nodeId] != nil, !allowedIds.contains(nodeId) else { continue }
            allowedIds.insert(nodeId)
            if let node = nodeById[nodeId] {
                for childId in node.children {
                    if allowedIds.count < maxNodes {
                        bfsQueue.append(childId)
                    }
                }
            }
        }

        var layoutNodes: [LayoutNode] = []
        var layoutEdges: [LayoutEdge] = []

        /// Compute subtree widths considering only allowed nodes
        func subtreeWidth(_ nodeId: String) -> CGFloat {
            guard let node = nodeById[nodeId], allowedIds.contains(nodeId) else { return nodeSize }
            let allowedChildren = node.children.filter { allowedIds.contains($0) }
            if allowedChildren.isEmpty { return nodeSize }
            let childrenWidth = allowedChildren.reduce(CGFloat(0)) { sum, childId in
                sum + subtreeWidth(childId)
            }
            let gaps = CGFloat(max(allowedChildren.count - 1, 0)) * hSpacing
            return max(nodeSize, childrenWidth + gaps)
        }

        func layoutNode(_ nodeId: String, x: CGFloat, y: CGFloat) {
            guard let node = nodeById[nodeId], allowedIds.contains(nodeId) else { return }
            let pos = CGPoint(x: x, y: y)
            layoutNodes.append(LayoutNode(
                id: node.id,
                character: node.character,
                isEnd: node.isEnd,
                position: pos
            ))

            let allowedChildren = node.children.filter { allowedIds.contains($0) }
            let totalChildWidth = allowedChildren.reduce(CGFloat(0)) { sum, childId in
                sum + subtreeWidth(childId)
            }
            let gaps = CGFloat(max(allowedChildren.count - 1, 0)) * hSpacing
            let allChildWidth = totalChildWidth + gaps
            var childX = x - allChildWidth / 2

            for childId in allowedChildren {
                let childWidth = subtreeWidth(childId)
                let childCenterX = childX + childWidth / 2
                let childY = y + vSpacing
                let childNode = nodeById[childId]
                layoutEdges.append(LayoutEdge(
                    id: "trie-edge-\(nodeId)-\(childId)",
                    from: pos,
                    to: CGPoint(x: childCenterX, y: childY),
                    character: childNode?.character ?? ""
                ))
                layoutNode(childId, x: childCenterX, y: childY)
                childX += childWidth + hSpacing
            }
        }

        let rootWidth = subtreeWidth(rootId)
        let rootX = max(nodeSize, rootWidth / 2)
        let rootY = nodeSize
        layoutNode(rootId, x: rootX, y: rootY)

        /// Compute depth for height (only among allowed nodes)
        func maxDepth(_ nodeId: String, depth: Int) -> Int {
            guard let node = nodeById[nodeId], allowedIds.contains(nodeId) else { return depth }
            let allowedChildren = node.children.filter { allowedIds.contains($0) }
            if allowedChildren.isEmpty { return depth }
            return allowedChildren.map { maxDepth($0, depth: depth + 1) }.max() ?? depth
        }

        let depth = maxDepth(rootId, depth: 0)
        let height = CGFloat(depth + 1) * vSpacing + nodeSize * 2

        nodes = layoutNodes
        edges = layoutEdges
        totalWidth = max(nodeSize * 2, rootWidth + nodeSize)
        totalHeight = max(nodeSize * 2, height)
    }
}
