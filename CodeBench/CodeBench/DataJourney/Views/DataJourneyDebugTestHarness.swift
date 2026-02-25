#if DEBUG

import Combine
import LeetPulseDesignSystem
import SwiftUI

// MARK: - Debug Test Harness

/// A debug-only view that rapidly cycles through step transitions for all structure types.
/// Used for visual verification of smooth animations, stable identity, and DS theming.
///
/// Access via the debug menu in DEBUG builds. Exercises all 8 visualization renderers
/// with synthetic data and a fast auto-advancing timer (0.3s per step).
struct DataJourneyDebugTestHarness: View {
    @Environment(\.dsTheme) var theme
    @State private var currentStepIndex: Int = 0
    @State private var isRunning: Bool = true

    private let totalSteps = 6
    private let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                // 1. Array
                sectionHeader("Array: Bubble Sort Steps")
                arraySectionView

                // 2. Linked List
                sectionHeader("Linked List: Pointer Traversal")
                linkedListSectionView

                // 3. Binary Tree
                sectionHeader("Binary Tree: Inorder Traversal")
                treeSectionView

                // 4. Graph
                sectionHeader("Graph: BFS Visited Nodes")
                graphSectionView

                // 5. Trie
                sectionHeader("Trie: Insert \"cat\", \"car\", \"cap\"")
                trieSectionView

                // 6. Matrix
                sectionHeader("Matrix: Cell Updates")
                matrixSectionView

                // 7. Heap
                sectionHeader("Heap: Heapify Steps")
                heapSectionView

                // 8. String
                sectionHeader("String: Palindrome Check")
                stringSectionView
            }
            .padding()
        }
        .navigationTitle("Debug Test Harness")
        .onReceive(timer) { _ in
            guard isRunning else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentStepIndex = (currentStepIndex + 1) % totalSteps
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phase 1 Verification")
                .font(.headline)
                .foregroundStyle(theme.colors.textPrimary)

            HStack {
                Text("Step \(currentStepIndex + 1) / \(totalSteps)")
                    .font(.subheadline)
                    .foregroundStyle(theme.colors.textSecondary)

                Spacer()

                Button("Reset") {
                    currentStepIndex = 0
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Section Header Helper

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(VizTypography.sectionLabel)
            .foregroundStyle(theme.colors.textPrimary)
            .padding(.top, 8)
    }

    // MARK: - 1. Array Section

    /// Synthetic array data: [3, 1, 4, 1, 5, 9] with bubble sort step progression
    private var arraySectionView: some View {
        let steps: [[TraceValue]] = [
            [.number(3, isInt: true), .number(1, isInt: true), .number(4, isInt: true), .number(1, isInt: true), .number(5, isInt: true), .number(9, isInt: true)],
            [.number(1, isInt: true), .number(3, isInt: true), .number(4, isInt: true), .number(1, isInt: true), .number(5, isInt: true), .number(9, isInt: true)],
            [.number(1, isInt: true), .number(3, isInt: true), .number(1, isInt: true), .number(4, isInt: true), .number(5, isInt: true), .number(9, isInt: true)],
            [.number(1, isInt: true), .number(1, isInt: true), .number(3, isInt: true), .number(4, isInt: true), .number(5, isInt: true), .number(9, isInt: true)],
            [.number(1, isInt: true), .number(1, isInt: true), .number(3, isInt: true), .number(4, isInt: true), .number(5, isInt: true), .number(9, isInt: true)],
            [.number(1, isInt: true), .number(1, isInt: true), .number(3, isInt: true), .number(4, isInt: true), .number(5, isInt: true), .number(9, isInt: true)]
        ]
        let items = steps[currentStepIndex % steps.count]
        let pointerIndex = currentStepIndex % items.count
        let pointer = PointerMarker(name: "i", index: pointerIndex, theme: theme)
        return SequenceBubbleRow(
            items: items,
            showIndices: true,
            cycleIndex: nil,
            isTruncated: false,
            isDoubly: false,
            pointers: [pointer],
            highlightedIndices: Set([pointerIndex]),
            bubbleStyle: .solid
        )
    }

    // MARK: - 2. Linked List Section

    /// 5-node linked list with pointer traversal steps
    private var linkedListSectionView: some View {
        let nodes: [TraceValue] = [
            .number(10, isInt: true),
            .number(20, isInt: true),
            .number(30, isInt: true),
            .number(40, isInt: true),
            .number(50, isInt: true)
        ]
        let pointerIndex = currentStepIndex % nodes.count
        let pointer = PointerMarker(name: "curr", index: pointerIndex, theme: theme)
        return SequenceBubbleRow(
            items: nodes,
            showIndices: false,
            cycleIndex: nil,
            isTruncated: false,
            isDoubly: false,
            pointers: [pointer],
            highlightedIndices: Set([pointerIndex]),
            bubbleStyle: .solid
        )
    }

    // MARK: - 3. Binary Tree Section

    /// 7-node tree with highlighted node visits (inorder traversal)
    private var treeSectionView: some View {
        // Level-order: [4, 2, 6, 1, 3, 5, 7]
        let treeItems: [TraceValue] = [
            .number(4, isInt: true), .number(2, isInt: true), .number(6, isInt: true),
            .number(1, isInt: true), .number(3, isInt: true), .number(5, isInt: true), .number(7, isInt: true)
        ]
        let tree = TraceTree.fromLevelOrder(treeItems)
        // Inorder visit order: i3(1), i1(2), i4(3), i0(4), i5(5), i2(6), i6(7)
        let visitOrder = ["i3", "i1", "i4", "i0", "i5", "i2", "i6"]
        let visitCount = min(currentStepIndex + 1, visitOrder.count)
        let highlighted = Set(visitOrder.prefix(visitCount))
        return TreeGraphView(
            tree: tree,
            pointers: [],
            highlightedNodeIds: highlighted,
            bubbleStyle: .solid
        )
    }

    // MARK: - 4. Graph Section

    /// 6-node undirected graph with BFS visited node progression
    private var graphSectionView: some View {
        // Adjacency list for a small connected graph
        let adjacency: [[Int]] = [
            [1, 2],    // node 0 -> 1, 2
            [0, 3],    // node 1 -> 0, 3
            [0, 4],    // node 2 -> 0, 4
            [1, 5],    // node 3 -> 1, 5
            [2, 5],    // node 4 -> 2, 5
            [3, 4]     // node 5 -> 3, 4
        ]
        // BFS from node 0: visit order [0, 1, 2, 3, 4, 5]
        let visitCount = min(currentStepIndex + 1, adjacency.count)
        let visitedIndices = Set(0..<visitCount)
        let pointers = visitedIndices.map { index in
            PointerMarker(name: "v\(index)", index: index, theme: theme)
        }
        return GraphView(
            adjacency: adjacency,
            pointers: pointers,
            bubbleStyle: .solid
        )
    }

    // MARK: - 5. Trie Section

    /// Trie with "cat", "car", "cap" -- progressive insertion
    private var trieSectionView: some View {
        let trieSteps: [TraceTrie] = buildTrieSteps()
        let step = currentStepIndex % trieSteps.count
        return TrieGraphView(
            trie: trieSteps[step],
            pointers: []
        )
    }

    private func buildTrieSteps() -> [TraceTrie] {
        // Step 0: root only
        let step0 = TraceTrie(
            nodes: [TraceTrieNode(id: "root", character: "", isEnd: false, children: [])],
            rootId: "root",
            isTruncated: false
        )
        // Step 1: root -> c
        let step1 = TraceTrie(
            nodes: [
                TraceTrieNode(id: "root", character: "", isEnd: false, children: ["c"]),
                TraceTrieNode(id: "c", character: "c", isEnd: false, children: [])
            ],
            rootId: "root",
            isTruncated: false
        )
        // Step 2: root -> c -> a
        let step2 = TraceTrie(
            nodes: [
                TraceTrieNode(id: "root", character: "", isEnd: false, children: ["c"]),
                TraceTrieNode(id: "c", character: "c", isEnd: false, children: ["ca"]),
                TraceTrieNode(id: "ca", character: "a", isEnd: false, children: [])
            ],
            rootId: "root",
            isTruncated: false
        )
        // Step 3: root -> c -> a -> t (end) -- "cat" inserted
        let step3 = TraceTrie(
            nodes: [
                TraceTrieNode(id: "root", character: "", isEnd: false, children: ["c"]),
                TraceTrieNode(id: "c", character: "c", isEnd: false, children: ["ca"]),
                TraceTrieNode(id: "ca", character: "a", isEnd: false, children: ["cat"]),
                TraceTrieNode(id: "cat", character: "t", isEnd: true, children: [])
            ],
            rootId: "root",
            isTruncated: false
        )
        // Step 4: + "car" -- c -> a branches to t and r
        let step4 = TraceTrie(
            nodes: [
                TraceTrieNode(id: "root", character: "", isEnd: false, children: ["c"]),
                TraceTrieNode(id: "c", character: "c", isEnd: false, children: ["ca"]),
                TraceTrieNode(id: "ca", character: "a", isEnd: false, children: ["cat", "car"]),
                TraceTrieNode(id: "cat", character: "t", isEnd: true, children: []),
                TraceTrieNode(id: "car", character: "r", isEnd: true, children: [])
            ],
            rootId: "root",
            isTruncated: false
        )
        // Step 5: + "cap" -- c -> a branches to t, r, p
        let step5 = TraceTrie(
            nodes: [
                TraceTrieNode(id: "root", character: "", isEnd: false, children: ["c"]),
                TraceTrieNode(id: "c", character: "c", isEnd: false, children: ["ca"]),
                TraceTrieNode(id: "ca", character: "a", isEnd: false, children: ["cat", "car", "cap"]),
                TraceTrieNode(id: "cat", character: "t", isEnd: true, children: []),
                TraceTrieNode(id: "car", character: "r", isEnd: true, children: []),
                TraceTrieNode(id: "cap", character: "p", isEnd: true, children: [])
            ],
            rootId: "root",
            isTruncated: false
        )
        return [step0, step1, step2, step3, step4, step5]
    }

    // MARK: - 6. Matrix Section

    /// 3x3 grid with cell updates
    private var matrixSectionView: some View {
        let baseGrid: [[TraceValue]] = [
            [.number(1, isInt: true), .number(0, isInt: true), .number(0, isInt: true)],
            [.number(0, isInt: true), .number(1, isInt: true), .number(0, isInt: true)],
            [.number(0, isInt: true), .number(0, isInt: true), .number(1, isInt: true)]
        ]
        // Each step highlights a different cell as the "current" pointer
        let positions: [(Int, Int)] = [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (2, 2)]
        let pos = positions[currentStepIndex % positions.count]
        let pointer = MatrixPointerCell(row: pos.0, col: pos.1)
        let highlightedCell = MatrixCell(row: pos.0, col: pos.1)
        return MatrixGridView(
            grid: baseGrid,
            pointers: pointer,
            highlightedCells: Set([highlightedCell])
        )
    }

    // MARK: - 7. Heap Section

    /// 7-element min-heap with heapify step highlighting
    private var heapSectionView: some View {
        let heapSteps: [[TraceValue]] = [
            [.number(9, isInt: true), .number(5, isInt: true), .number(6, isInt: true), .number(2, isInt: true), .number(3, isInt: true), .number(8, isInt: true), .number(7, isInt: true)],
            [.number(9, isInt: true), .number(2, isInt: true), .number(6, isInt: true), .number(5, isInt: true), .number(3, isInt: true), .number(8, isInt: true), .number(7, isInt: true)],
            [.number(9, isInt: true), .number(2, isInt: true), .number(6, isInt: true), .number(5, isInt: true), .number(3, isInt: true), .number(8, isInt: true), .number(7, isInt: true)],
            [.number(2, isInt: true), .number(3, isInt: true), .number(6, isInt: true), .number(5, isInt: true), .number(9, isInt: true), .number(8, isInt: true), .number(7, isInt: true)],
            [.number(2, isInt: true), .number(3, isInt: true), .number(6, isInt: true), .number(5, isInt: true), .number(9, isInt: true), .number(8, isInt: true), .number(7, isInt: true)],
            [.number(2, isInt: true), .number(3, isInt: true), .number(6, isInt: true), .number(5, isInt: true), .number(9, isInt: true), .number(8, isInt: true), .number(7, isInt: true)]
        ]
        let items = heapSteps[currentStepIndex % heapSteps.count]
        let highlightIndex = currentStepIndex % items.count
        return HeapView(
            items: items,
            isMinHeap: true,
            pointers: [],
            highlightedIndices: Set([highlightIndex])
        )
    }

    // MARK: - 8. String Section

    /// "racecar" palindrome check with left/right pointers
    private var stringSectionView: some View {
        let word = "racecar"
        let characters: [TraceValue] = word.map { .string(String($0)) }
        // Palindrome check: left starts at 0, right starts at 6, converge
        let pointerSteps: [(Int, Int)] = [(0, 6), (1, 5), (2, 4), (3, 3), (3, 3), (3, 3)]
        let step = pointerSteps[currentStepIndex % pointerSteps.count]
        let leftPointer = PointerMarker(name: "left", index: step.0, theme: theme)
        let rightPointer = PointerMarker(name: "right", index: step.1, theme: theme)
        return StringSequenceView(
            fullString: word,
            characters: characters,
            pointers: [leftPointer, rightPointer],
            highlightedIndices: Set([step.0, step.1])
        )
    }
}

// MARK: - Preview

struct DataJourneyDebugTestHarness_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DataJourneyDebugTestHarness()
        }
    }
}

#endif
