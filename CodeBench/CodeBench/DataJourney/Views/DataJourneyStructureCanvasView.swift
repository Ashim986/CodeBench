
import LeetPulseDesignSystem
import SwiftUI

enum TraceStructure {
    case list(TraceList)
    case listGroup([NamedTraceList])
    case listArray(ListArrayStructure)
    case tree(TraceTree)
    case array([TraceValue])
    case matrix([[TraceValue]])
    case graph([[Int]])
    case dictionary([DictionaryEntry])
    case set([TraceValue])
    case stack([TraceValue])
    case queue([TraceValue])
    case heap([TraceValue], isMinHeap: Bool)
    case stringSequence(String, [TraceValue])
    case trie(TraceTrie)
}

struct NamedTraceList: Identifiable {
    let id: String
    let name: String
    let list: TraceList
}

struct CombinedListViewModel {
    let items: [TraceValue]
    let pointers: [PointerMarker]
    let isTruncated: Bool
    let gapIndices: Set<Int>
}

struct ListArrayStructure {
    let heads: [TraceValue]
    let lists: [NamedTraceList]
}

struct DataJourneyStructureCanvasView<Header: View, Footer: View>: View {
    let inputEvent: DataJourneyEvent?
    let selectedEvent: DataJourneyEvent?
    let previousEvent: DataJourneyEvent?
    let outputEvent: DataJourneyEvent?
    let structureOverride: TraceStructure?
    let playbackIndex: Int
    let beginsAtZero: Bool
    let header: Header?
    let footer: Footer?

    let structureBubbleSize: CGFloat = 40
    let structurePointerFontSize: CGFloat = 10
    let structurePointerHorizontalPadding: CGFloat = 9
    let structurePointerVerticalPadding: CGFloat = 3
    let combinedMaxItems = 40
    @Environment(\.dsTheme) var theme

    init(
        inputEvent: DataJourneyEvent?,
        selectedEvent: DataJourneyEvent?,
        previousEvent: DataJourneyEvent? = nil,
        outputEvent: DataJourneyEvent? = nil,
        structureOverride: TraceStructure? = nil,
        playbackIndex: Int = 0,
        beginsAtZero: Bool = false,
        header: Header? = nil,
        footer: Footer? = nil
    ) {
        self.inputEvent = inputEvent
        self.selectedEvent = selectedEvent
        self.previousEvent = previousEvent
        self.outputEvent = outputEvent
        self.structureOverride = structureOverride
        self.playbackIndex = playbackIndex
        self.beginsAtZero = beginsAtZero
        self.header = header
        self.footer = footer
    }

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        if let structure {
            let offGraphPointers = offGraphPointerBadges(for: structure)
            VStack(alignment: .leading, spacing: DSLayout.spacing(6)) {
                structureHeader(offGraphPointers: offGraphPointers)
                structureContent(structure)
                if let footer {
                    footer
                        .padding(.top, DSLayout.spacing(6))
                }
            }
            .padding(DSLayout.spacing(8))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.colors.surface)
            )
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                String(format: AppStrings.a11yDataJourneyCanvas, structureTypeName)
            )
            .accessibilityValue(canvasAccessibilityValue)
            .accessibilityIdentifier(AccessibilityID.DataJourney.canvas)
        }
    }

    /// Human-readable name for the current structure type.
    private var structureTypeName: String {
        guard let structure else { return "Empty" }
        switch structure {
        case .list: return "Linked List"
        case .listGroup: return "List Group"
        case .listArray: return "List Array"
        case .tree: return "Tree"
        case .array: return "Array"
        case .matrix: return "Matrix"
        case .graph: return "Graph"
        case .dictionary: return "Dictionary"
        case .set: return "Set"
        case .stack: return "Stack"
        case .queue: return "Queue"
        case .heap: return "Heap"
        case .stringSequence: return "String"
        case .trie: return "Trie"
        }
    }

    /// Accessibility value summarizing element count and content.
    private var canvasAccessibilityValue: String {
        guard let structure else { return "" }
        let count: Int
        let summary: String
        switch structure {
        case let .array(items):
            count = items.count
            summary = items.prefix(5).map(\.shortDescription).joined(separator: ", ")
        case let .stack(items), let .queue(items), let .set(items):
            count = items.count
            summary = items.prefix(5).map(\.shortDescription).joined(separator: ", ")
        case let .heap(items, _):
            count = items.count
            summary = items.prefix(5).map(\.shortDescription).joined(separator: ", ")
        case let .dictionary(entries):
            count = entries.count
            summary = entries.prefix(3).map { "\($0.key): \($0.value.shortDescription)" }
                .joined(separator: ", ")
        default:
            return ""
        }
        return String(format: AppStrings.a11yDataJourneyValue, count, summary)
    }

    // MARK: - Variable Name

    /// Extract the variable name for the displayed structure.
    /// Uses the first non-pointer key from the relevant event.
    private var structureVariableName: String {
        let event = selectedEvent ?? inputEvent ?? outputEvent
        guard let event else { return structureTypeName }
        let structureKeys = event.values.keys.sorted().filter { key in
            guard let value = event.values[key] else {
                return false
            }
            return !isPointerValue(value)
        }
        if let name = structureKeys.first {
            return name
        }
        return structureTypeName
    }

    private func isPointerValue(_ value: TraceValue) -> Bool {
        switch value {
        case .listPointer, .treePointer:
            true
        case let .number(_, isInt):
            isInt
        default:
            false
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func structureHeader(
        offGraphPointers: [PointerMarker]
    ) -> some View {
        HStack(alignment: .center, spacing: DSLayout.spacing(10)) {
            Text(structureVariableName)
                .font(VizTypography.nodeLabel)
                .foregroundColor(theme.colors.textSecondary)
                .fixedSize()
                .lineLimit(1)

            if let header {
                header
            }

            Spacer()
        }
        .zIndex(1)

        if !offGraphPointers.isEmpty {
            HStack(
                alignment: .center,
                spacing: DSLayout.spacing(6)
            ) {
                Text("Off-graph")
                    .font(VizTypography.secondaryLabel)
                    .foregroundColor(theme.colors.textSecondary)
                ForEach(offGraphPointers) { pointer in
                    PointerBadge(
                        text: pointer.name,
                        color: pointer.color,
                        fontSize: 8,
                        horizontalPadding: 6,
                        verticalPadding: 2
                    )
                }
            }
            .padding(.bottom, DSLayout.spacing(2))
        }
    }
}

// MARK: - Structure Content Dispatch

extension DataJourneyStructureCanvasView {
    @ViewBuilder
    func structureContent(
        _ structure: TraceStructure
    ) -> some View {
        switch structure {
        case let .list(list):
            listView(list: list)
        case let .listGroup(lists):
            listGroupView(lists: lists)
        case let .listArray(listArray):
            listArrayView(listArray: listArray)
        case let .tree(tree):
            treeView(tree: tree)
        case let .graph(adjacency):
            graphView(adjacency: adjacency)
        case let .trie(trieData):
            trieView(trieData: trieData)
        default:
            sequenceStructureContent(structure)
        }
    }

    @ViewBuilder
    func sequenceStructureContent(
        _ structure: TraceStructure
    ) -> some View {
        switch structure {
        case let .array(items):
            arrayContentView(items: items)
        case let .matrix(grid):
            matrixContentView(grid: grid)
        case let .dictionary(entries):
            dictionaryContentView(entries: entries)
        case let .set(items):
            setContentView(items: items)
        case let .stack(items):
            stackContentView(items: items)
        case let .queue(items):
            queueContentView(items: items)
        case let .heap(items, isMinHeap):
            heapContentView(items: items, isMinHeap: isMinHeap)
        case let .stringSequence(fullString, chars):
            stringContentView(
                fullString: fullString, chars: chars
            )
        default:
            EmptyView()
        }
    }
}

// MARK: - Sequence Structure Views

extension DataJourneyStructureCanvasView {
    @ViewBuilder
    func arrayContentView(items: [TraceValue]) -> some View {
        let highlights = structureArrayHighlights(items: items)
        let changes = structureElementChanges(items: items)
        SequenceBubbleRow(
            items: items,
            showIndices: true,
            cycleIndex: nil,
            isTruncated: false,
            isDoubly: false,
            pointers: pointerMarkers,
            highlightedIndices: highlights,
            changeTypes: changes,
            bubbleStyle: .solid,
            bubbleSize: structureBubbleSize,
            pointerFontSize: structurePointerFontSize,
            pointerHorizontalPadding: structurePointerHorizontalPadding,
            pointerVerticalPadding: structurePointerVerticalPadding
        )
    }

    @ViewBuilder
    func matrixContentView(
        grid: [[TraceValue]]
    ) -> some View {
        let highlights = structureMatrixHighlights
        MatrixGridView(
            grid: grid,
            pointers: matrixPointerCell(),
            highlightedCells: highlights,
            bubbleSize: structureBubbleSize
        )
    }

    func dictionaryContentView(
        entries: [DictionaryEntry]
    ) -> some View {
        DictionaryStructureRow(
            entries: entries,
            pointers: pointerMarkers,
            bubbleStyle: .solid,
            bubbleSize: structureBubbleSize,
            pointerFontSize: structurePointerFontSize,
            pointerHorizontalPadding: structurePointerHorizontalPadding,
            pointerVerticalPadding: structurePointerVerticalPadding
        )
    }

    @ViewBuilder
    func setContentView(items: [TraceValue]) -> some View {
        let gaps = Set(items.indices.dropLast())
        let changes = structureElementChanges(items: items)
        SequenceBubbleRow(
            items: items,
            showIndices: false,
            cycleIndex: nil,
            isTruncated: false,
            isDoubly: false,
            pointers: [],
            gapIndices: gaps,
            changeTypes: changes,
            bubbleStyle: .solid,
            bubbleSize: structureBubbleSize,
            pointerFontSize: structurePointerFontSize,
            pointerHorizontalPadding: structurePointerHorizontalPadding,
            pointerVerticalPadding: structurePointerVerticalPadding
        )
    }

    @ViewBuilder
    func stackContentView(
        items: [TraceValue]
    ) -> some View {
        let changes = structureElementChanges(items: items)
        HStack(alignment: .center, spacing: DSLayout.spacing(6)) {
            SequenceBubbleRow(
                items: items,
                showIndices: false,
                cycleIndex: nil,
                isTruncated: false,
                isDoubly: false,
                pointers: pointerMarkers,
                changeTypes: changes,
                bubbleStyle: .solid,
                bubbleSize: structureBubbleSize,
                pointerFontSize: structurePointerFontSize,
                pointerHorizontalPadding: structurePointerHorizontalPadding,
                pointerVerticalPadding: structurePointerVerticalPadding
            )
            stackDirectionArrows
        }
    }

    @ViewBuilder
    func queueContentView(
        items: [TraceValue]
    ) -> some View {
        let changes = structureElementChanges(items: items)
        HStack(alignment: .center, spacing: DSLayout.spacing(6)) {
            queueDequeueArrow
            SequenceBubbleRow(
                items: items,
                showIndices: false,
                cycleIndex: nil,
                isTruncated: false,
                isDoubly: false,
                pointers: pointerMarkers,
                changeTypes: changes,
                bubbleStyle: .solid,
                bubbleSize: structureBubbleSize,
                pointerFontSize: structurePointerFontSize,
                pointerHorizontalPadding: structurePointerHorizontalPadding,
                pointerVerticalPadding: structurePointerVerticalPadding
            )
            queueEnqueueArrow
        }
    }

    // MARK: - Stack Direction Arrows

    private var stackDirectionArrows: some View {
        VStack(spacing: DSLayout.spacing(6)) {
            VStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .font(VizTypography.indexLabel(size: structureBubbleSize))
                    .foregroundColor(theme.vizColors.quinary)
                Text("pop")
                    .font(VizTypography.indexLabel(size: structureBubbleSize))
                    .foregroundColor(theme.vizColors.quinary)
            }
            .fixedSize()
            VStack(spacing: 2) {
                Image(systemName: "arrow.down")
                    .font(VizTypography.indexLabel(size: structureBubbleSize))
                    .foregroundColor(theme.vizColors.quinary)
                Text("push")
                    .font(VizTypography.indexLabel(size: structureBubbleSize))
                    .foregroundColor(theme.vizColors.quinary)
            }
            .fixedSize()
        }
    }

    // MARK: - Queue Direction Arrows

    private var queueDequeueArrow: some View {
        VStack(spacing: 2) {
            Image(systemName: "arrow.left")
                .font(VizTypography.indexLabel(size: structureBubbleSize))
                .foregroundColor(theme.vizColors.quinary)
            Text("dequeue")
                .font(VizTypography.indexLabel(size: structureBubbleSize))
                .foregroundColor(theme.vizColors.quinary)
        }
        .fixedSize()
    }

    private var queueEnqueueArrow: some View {
        VStack(spacing: 2) {
            Image(systemName: "arrow.right")
                .font(VizTypography.indexLabel(size: structureBubbleSize))
                .foregroundColor(theme.vizColors.quinary)
            Text("enqueue")
                .font(VizTypography.indexLabel(size: structureBubbleSize))
                .foregroundColor(theme.vizColors.quinary)
        }
        .fixedSize()
    }

    @ViewBuilder
    func heapContentView(
        items: [TraceValue], isMinHeap: Bool
    ) -> some View {
        let highlights = structureArrayHighlights(items: items)
        HeapView(
            items: items,
            isMinHeap: isMinHeap,
            pointers: pointerMarkers,
            highlightedIndices: highlights,
            bubbleSize: structureBubbleSize,
            pointerFontSize: structurePointerFontSize,
            pointerHorizontalPadding: structurePointerHorizontalPadding,
            pointerVerticalPadding: structurePointerVerticalPadding
        )
    }

    @ViewBuilder
    func stringContentView(
        fullString: String, chars: [TraceValue]
    ) -> some View {
        let highlights = structureArrayHighlights(items: chars)
        StringSequenceView(
            fullString: fullString,
            characters: chars,
            pointers: pointerMarkers,
            highlightedIndices: highlights,
            bubbleSize: structureBubbleSize,
            pointerFontSize: structurePointerFontSize,
            pointerHorizontalPadding: structurePointerHorizontalPadding,
            pointerVerticalPadding: structurePointerVerticalPadding
        )
    }
}
