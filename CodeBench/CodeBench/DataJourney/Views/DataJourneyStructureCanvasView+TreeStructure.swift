
import SwiftUI

// MARK: - Tree / Graph / Trie View Builders

extension DataJourneyStructureCanvasView {
    @ViewBuilder
    func treeView(tree: TraceTree) -> some View {
        let motions = treePointerMotions(
            from: previousEvent, to: selectedEvent
        )
        let treeHighlights = structureTreeHighlights
        TreeGraphView(
            tree: tree,
            pointers: pointerMarkers,
            pointerMotions: motions,
            highlightedNodeIds: treeHighlights,
            bubbleStyle: .solid,
            nodeSize: structureBubbleSize,
            pointerFontSize: structurePointerFontSize,
            pointerHorizontalPadding: structurePointerHorizontalPadding,
            pointerVerticalPadding: structurePointerVerticalPadding
        )
    }

    func graphView(adjacency: [[Int]]) -> some View {
        GraphView(
            adjacency: adjacency,
            pointers: pointerMarkers,
            bubbleStyle: .solid,
            nodeSize: structureBubbleSize,
            pointerFontSize: structurePointerFontSize,
            pointerHorizontalPadding: structurePointerHorizontalPadding,
            pointerVerticalPadding: structurePointerVerticalPadding
        )
    }

    func trieView(trieData: TraceTrie) -> some View {
        TrieGraphView(
            trie: trieData,
            pointers: pointerMarkers,
            nodeSize: structureBubbleSize,
            pointerFontSize: structurePointerFontSize,
            pointerHorizontalPadding: structurePointerHorizontalPadding,
            pointerVerticalPadding: structurePointerVerticalPadding
        )
    }
}
