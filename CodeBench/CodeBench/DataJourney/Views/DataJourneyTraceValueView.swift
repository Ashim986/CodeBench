
import SwiftUI

struct TraceValueView: View {
    let value: TraceValue
    @Environment(\.dsTheme) var theme

    var body: some View {
        switch value {
        case .null:
            bubble(for: value)
        case let .bool(boolValue):
            bubble(for: .bool(boolValue))
        case let .number(number, isInt):
            bubble(for: .number(number, isInt: isInt))
        case let .string(stringValue):
            arrayView(stringCharacters(from: stringValue))
        case let .array(items):
            arrayView(items)
        case let .object(map):
            objectView(map)
        case let .list(list):
            listView(list)
        case .listPointer:
            bubble(for: .string("ptr"))
        case let .tree(tree):
            treeView(tree)
        case .treePointer:
            bubble(for: .string("ptr"))
        case .trie:
            bubble(for: .string("trie"))
        case let .typed(type, inner):
            typedView(type: type, value: inner)
        }
    }

    @ViewBuilder
    private func arrayView(_ items: [TraceValue]) -> some View {
        if let adjacency = adjacencyList(from: items) {
            GraphView(adjacency: adjacency, pointers: [])
        } else {
            sequenceView(items, showIndices: true)
        }
    }

    private func objectView(_ map: [String: TraceValue]) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing(6)) {
            ForEach(map.keys.sorted(), id: \.self) { key in
                if let value = map[key] {
                    HStack(spacing: DSLayout.spacing(6)) {
                        Text(key)
                            .font(VizTypography.secondaryLabel)
                            .foregroundColor(theme.colors.textSecondary.opacity(0.9))
                        TraceValueView(value: value)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func typedView(type: String, value: TraceValue) -> some View {
        let lowered = type.lowercased()
        switch lowered {
        case "list":
            listView(value)
        case "tree":
            treeView(value)
        case "set":
            setView(value)
        case "stack":
            stackView(value)
        case "queue":
            queueView(value)
        default:
            TraceValueView(value: value)
        }
    }

    @ViewBuilder
    private func listView(_ value: TraceValue) -> some View {
        if case let .array(items) = value {
            sequenceView(items, showIndices: false)
        } else {
            TraceValueView(value: value)
        }
    }

    private func listView(_ list: TraceList) -> some View {
        let items = list.nodes.map(\.value)
        return sequenceView(
            items,
            showIndices: false,
            cycleIndex: list.cycleIndex,
            isTruncated: list.isTruncated,
            isDoubly: list.isDoubly
        )
    }

    @ViewBuilder
    private func treeView(_ value: TraceValue) -> some View {
        if case let .array(items) = value {
            TreeGraphView(tree: TraceTree.fromLevelOrder(items), pointers: [])
        } else {
            TraceValueView(value: value)
        }
    }

    private func treeView(_ tree: TraceTree) -> some View {
        TreeGraphView(tree: tree, pointers: [])
    }

    private func sequenceView(
        _ items: [TraceValue],
        showIndices: Bool,
        cycleIndex: Int? = nil,
        isTruncated: Bool = false,
        isDoubly: Bool = false,
        pointers: [PointerMarker] = [],
        gapIndices: Set<Int> = []
    ) -> some View {
        SequenceBubbleRow(
            items: items,
            showIndices: showIndices,
            cycleIndex: cycleIndex,
            isTruncated: isTruncated,
            isDoubly: isDoubly,
            pointers: pointers,
            gapIndices: gapIndices
        )
    }

    private func bubble(for value: TraceValue) -> some View {
        let model = TraceBubbleModel.from(value, theme: theme)
        return TraceBubble(text: model.text, fill: model.fill, isNull: model.isNull)
    }

    private func stringCharacters(from value: String) -> [TraceValue] {
        value.map { TraceValue.string(String($0)) }
    }

    @ViewBuilder
    private func setView(_ value: TraceValue) -> some View {
        if case let .array(items) = value {
            sequenceView(
                items, showIndices: false,
                gapIndices: Set(items.indices.dropLast())
            )
        } else {
            TraceValueView(value: value)
        }
    }

    @ViewBuilder
    private func stackView(_ value: TraceValue) -> some View {
        if case let .array(items) = value {
            sequenceView(
                items, showIndices: false,
                pointers: stackPointers(for: items)
            )
        } else {
            TraceValueView(value: value)
        }
    }

    @ViewBuilder
    private func queueView(_ value: TraceValue) -> some View {
        if case let .array(items) = value {
            sequenceView(
                items, showIndices: false,
                pointers: queuePointers(for: items)
            )
        } else {
            TraceValueView(value: value)
        }
    }

    private func stackPointers(for items: [TraceValue]) -> [PointerMarker] {
        guard let topIndex = items.indices.last else { return [] }
        return [PointerMarker(name: "top", index: topIndex, theme: theme)]
    }

    private func queuePointers(for items: [TraceValue]) -> [PointerMarker] {
        guard let firstIndex = items.indices.first else { return [] }
        let lastIndex = items.indices.last ?? firstIndex
        if firstIndex == lastIndex {
            return [PointerMarker(name: "front/back", index: firstIndex, theme: theme)]
        }
        return [
            PointerMarker(name: "front", index: firstIndex, theme: theme),
            PointerMarker(name: "back", index: lastIndex, theme: theme)
        ]
    }

    private func adjacencyList(from items: [TraceValue]) -> [[Int]]? {
        guard !items.isEmpty else { return nil }
        var lists: [[Int]] = []
        var allCounts: [Int] = []

        for item in items {
            guard case let .array(inner) = item else { return nil }
            var neighbors: [Int] = []
            for value in inner {
                guard case let .number(number, isInt) = value else { return nil }
                let intValue = Int(number)
                if isInt == false, Double(intValue) != number { return nil }
                neighbors.append(intValue)
            }
            lists.append(neighbors)
            allCounts.append(inner.count)
        }

        let nodeCount = items.count
        if allCounts.allSatisfy({ $0 == nodeCount }) {
            let matrixValues = lists.flatMap(\.self)
            if matrixValues.allSatisfy({ $0 == 0 || $0 == 1 }) {
                return nil
            }
        }

        return lists
    }
}
