import LeetPulseDesignSystem
import SwiftUI

extension DataJourneyStructureCanvasView {
    var pointerMarkers: [PointerMarker] {
        guard let selectedEvent, let structure else { return [] }
        switch structure {
        case let .list(list):
            return listPointers(in: selectedEvent, list: list)
        case .listGroup:
            return []
        case let .listArray(listArray):
            return listArrayHeadPointers(for: listArray)
        case .tree:
            return treePointers(in: selectedEvent)
        case let .array(items):
            return arrayPointers(in: selectedEvent, items: items)
        case .matrix:
            return []
        case let .graph(adjacency):
            return graphPointers(in: selectedEvent, adjacency: adjacency)
        case let .dictionary(entries):
            return dictionaryPointers(in: selectedEvent, entries: entries)
        case .set:
            return []
        case let .stack(items):
            return stackPointers(for: items)
        case let .queue(items):
            return queuePointers(for: items)
        case let .heap(items, _):
            return arrayPointers(in: selectedEvent, items: items)
        case let .stringSequence(_, chars):
            return arrayPointers(in: selectedEvent, items: chars)
        case .trie:
            return []
        }
    }

    func pointerMarkers(for list: TraceList) -> [PointerMarker] {
        guard let selectedEvent else { return [] }
        return listPointers(in: selectedEvent, list: list)
    }

    func offGraphPointerBadges(for structure: TraceStructure) -> [PointerMarker] {
        guard let selectedEvent else { return [] }
        let pointerNames = Set(
            pointerCandidates(in: selectedEvent).compactMap { candidate -> String? in
                switch candidate.value {
                case .listPointer, .treePointer:
                    return candidate.name
                default:
                    return nil
                }
            }
        )
        guard !pointerNames.isEmpty else { return [] }
        let resolvedNames = resolvedPointerNames(in: selectedEvent, for: structure)
        let unresolved = pointerNames.subtracting(resolvedNames).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        return unresolved.map { PointerMarker(name: $0, valueText: nil, theme: theme) }
    }

    func resolvedPointerNames(in event: DataJourneyEvent, for structure: TraceStructure) -> Set<String> {
        switch structure {
        case let .list(list):
            return Set(listPointers(in: event, list: list).map(\.name))
        case let .listGroup(lists):
            return Set(combinedPointerIndices(in: event, lists: lists).keys)
        case let .listArray(listArray):
            let combined = Set(combinedPointerIndices(in: event, lists: listArray.lists).keys)
            let heads = Set(arrayPointers(in: event, items: listArray.heads).map(\.name))
            return combined.union(heads)
        case .tree:
            return Set(treePointers(in: event).map(\.name))
        case let .array(items):
            return Set(arrayPointers(in: event, items: items).map(\.name))
        case let .graph(adjacency):
            return Set(graphPointers(in: event, adjacency: adjacency).map(\.name))
        case let .dictionary(entries):
            return Set(dictionaryPointers(in: event, entries: entries).map(\.name))
        case let .heap(items, _):
            return Set(arrayPointers(in: event, items: items).map(\.name))
        case let .stringSequence(_, chars):
            return Set(arrayPointers(in: event, items: chars).map(\.name))
        case .matrix, .set, .stack, .queue, .trie:
            return []
        }
    }

    func arrayPointerMarkers(for items: [TraceValue]) -> [PointerMarker] {
        guard let selectedEvent else { return [] }
        return arrayPointers(in: selectedEvent, items: items)
    }

    func listArrayHeadPointers(for listArray: ListArrayStructure) -> [PointerMarker] {
        let indexMarkers = arrayPointerMarkers(for: listArray.heads)
        let headMarkers = listHeadPointers(for: listArray)
        return uniquePointerMarkers(indexMarkers + headMarkers)
    }

    func listHeadPointers(for listArray: ListArrayStructure) -> [PointerMarker] {
        guard let selectedEvent else { return [] }
        var headIdToIndex: [String: Int] = [:]
        for (index, entry) in listArray.lists.enumerated() {
            if let headId = entry.list.nodes.first?.id {
                headIdToIndex[headId] = index
            }
        }
        return pointerCandidates(in: selectedEvent).compactMap { name, value in
            guard case let .listPointer(id) = value,
                  let index = headIdToIndex[id] else { return nil }
            return PointerMarker(
                name: name, index: index, valueText: nil, theme: theme
            )
        }
    }

    func uniquePointerMarkers(_ markers: [PointerMarker]) -> [PointerMarker] {
        var seen: Set<String> = []
        let unique = markers.filter { marker in
            seen.insert(marker.id).inserted
        }
        return unique.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func pointerCandidates(in event: DataJourneyEvent) -> [(name: String, value: TraceValue)] {
        var result: [(name: String, value: TraceValue)] = []
        for key in event.values.keys.sorted() {
            guard let value = event.values[key] else { continue }
            collectPointerCandidates(path: key, value: value, into: &result)
        }
        return result
    }

    func collectPointerCandidates(
        path: String,
        value: TraceValue,
        into result: inout [(name: String, value: TraceValue)]
    ) {
        switch value {
        case .listPointer, .treePointer:
            result.append((path, value))
        case let .object(map):
            for key in map.keys.sorted() {
                guard let nested = map[key] else { continue }
                collectPointerCandidates(path: "\(path).\(key)", value: nested, into: &result)
            }
        case let .array(items):
            for (index, nested) in items.enumerated() {
                collectPointerCandidates(path: "\(path)[\(index)]", value: nested, into: &result)
            }
        case let .typed(_, inner):
            collectPointerCandidates(path: path, value: inner, into: &result)
        default:
            break
        }
    }

    func listPointerMotions(
        from previousEvent: DataJourneyEvent?,
        to currentEvent: DataJourneyEvent?,
        list: TraceList
    ) -> [PointerMotion] {
        guard let previousEvent, let currentEvent else { return [] }
        let previous = listPointerIndices(in: previousEvent, list: list)
        let current = listPointerIndices(in: currentEvent, list: list)
        return pointerMotions(from: previous, to: current)
    }

    func combinedPointerMotions(
        from previousEvent: DataJourneyEvent?,
        to currentEvent: DataJourneyEvent?,
        lists: [NamedTraceList]
    ) -> [PointerMotion] {
        guard let previousEvent, let currentEvent else { return [] }
        let previous = combinedPointerIndices(in: previousEvent, lists: lists)
        let current = combinedPointerIndices(in: currentEvent, lists: lists)
        return pointerMotions(from: previous, to: current)
    }

    func pointerMotions(
        from previous: [String: Int],
        to current: [String: Int]
    ) -> [PointerMotion] {
        var motions: [PointerMotion] = []
        for (name, toIndex) in current {
            guard let fromIndex = previous[name], fromIndex != toIndex else { continue }
            motions.append(
                PointerMotion(
                    name: name,
                    fromIndex: fromIndex,
                    toIndex: toIndex,
                    theme: theme
                )
            )
        }
        return motions.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func listPointerIndices(in event: DataJourneyEvent, list: TraceList) -> [String: Int] {
        var idToIndex: [String: Int] = [:]
        for (index, node) in list.nodes.enumerated() {
            idToIndex[node.id] = index
        }
        var indices: [String: Int] = [:]
        for candidate in pointerCandidates(in: event) {
            guard case let .listPointer(id) = candidate.value,
                  let index = idToIndex[id] else { continue }
            indices[candidate.name] = index
        }
        return indices
    }

    func combinedPointerIndices(in event: DataJourneyEvent, lists: [NamedTraceList]) -> [String: Int] {
        let candidates = pointerCandidates(in: event)
        var indices: [String: Int] = [:]
        var offset = 0
        for entry in lists {
            var idToIndex: [String: Int] = [:]
            for (index, node) in entry.list.nodes.enumerated() {
                idToIndex[node.id] = index
            }
            for candidate in candidates {
                guard case let .listPointer(id) = candidate.value,
                      let index = idToIndex[id] else { continue }
                indices[candidate.name] = index + offset
            }
            offset += entry.list.nodes.count
        }
        return indices
    }

    func listPointers(in event: DataJourneyEvent, list: TraceList) -> [PointerMarker] {
        var idToIndex: [String: Int] = [:]
        for (index, node) in list.nodes.enumerated() {
            idToIndex[node.id] = index
        }
        return pointerCandidates(in: event).compactMap { name, value in
            guard case let .listPointer(id) = value,
                  let index = idToIndex[id] else { return nil }
            return PointerMarker(
                name: name, index: index, valueText: nil, theme: theme
            )
        }
    }

    func treePointers(in event: DataJourneyEvent) -> [PointerMarker] {
        pointerCandidates(in: event).compactMap { name, value in
            guard case let .treePointer(id) = value else { return nil }
            return PointerMarker(name: name, nodeId: id, valueText: nil, theme: theme)
        }
    }

    func treePointerMotions(
        from previousEvent: DataJourneyEvent?,
        to currentEvent: DataJourneyEvent?
    ) -> [TreePointerMotion] {
        guard let previousEvent, let currentEvent else { return [] }
        let previous = treePointerNodes(in: previousEvent)
        let current = treePointerNodes(in: currentEvent)
        var motions: [TreePointerMotion] = []
        for (name, toId) in current {
            guard let fromId = previous[name], fromId != toId else { continue }
            motions.append(TreePointerMotion(name: name, fromId: fromId, toId: toId, theme: theme))
        }
        return motions.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func treePointerNodes(in event: DataJourneyEvent) -> [String: String] {
        var mapping: [String: String] = [:]
        for candidate in pointerCandidates(in: event) {
            guard case let .treePointer(id) = candidate.value else { continue }
            mapping[candidate.name] = id
        }
        return mapping
    }

    func arrayPointers(in event: DataJourneyEvent, items: [TraceValue]) -> [PointerMarker] {
        event.values.compactMap { key, value in
            guard case let .number(number, isInt) = value, isInt else { return nil }
            let index = Int(number)
            guard items.indices.contains(index), isIndexName(key) else { return nil }
            return PointerMarker(
                name: key, index: index, valueText: nil, theme: theme
            )
        }
        .sorted { $0.name < $1.name }
    }

    func graphPointers(in event: DataJourneyEvent, adjacency: [[Int]]) -> [PointerMarker] {
        event.values.compactMap { key, value in
            guard case let .number(number, isInt) = value, isInt else { return nil }
            let index = Int(number)
            guard adjacency.indices.contains(index), isIndexName(key) else { return nil }
            return PointerMarker(
                name: key, index: index, valueText: nil, theme: theme
            )
        }
        .sorted { $0.name < $1.name }
    }

    func dictionaryPointers(in event: DataJourneyEvent, entries: [DictionaryEntry]) -> [PointerMarker] {
        let keyToIndex = Dictionary(uniqueKeysWithValues: entries.enumerated().map { ($0.element.key, $0.offset) })
        return event.values.compactMap { key, value in
            switch value {
            case let .string(stringValue):
                guard let index = keyToIndex[stringValue] else { return nil }
                return PointerMarker(
                    name: key, index: index, valueText: nil, theme: theme
                )
            case let .number(number, isInt):
                guard isInt else { return nil }
                let stringValue = "\(Int(number))"
                guard let index = keyToIndex[stringValue] else { return nil }
                return PointerMarker(
                    name: key, index: index, valueText: nil, theme: theme
                )
            default:
                return nil
            }
        }
        .sorted { $0.name < $1.name }
    }

    func isIndexName(_ name: String) -> Bool {
        let lowered = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowered.hasSuffix("index") { return true }
        let allowed = ["i", "j", "k", "idx", "index", "left", "right", "mid", "lo", "hi", "start", "end"]
        return allowed.contains(lowered)
    }

    func stackPointers(for items: [TraceValue]) -> [PointerMarker] {
        guard let topIndex = items.indices.last else { return [] }
        return [PointerMarker(
            name: "top", index: topIndex, valueText: nil, theme: theme
        )]
    }

    func queuePointers(for items: [TraceValue]) -> [PointerMarker] {
        guard let firstIndex = items.indices.first else { return [] }
        let lastIndex = items.indices.last ?? firstIndex
        if firstIndex == lastIndex {
            return [PointerMarker(
                name: "front/back", index: firstIndex,
                valueText: nil, theme: theme
            )]
        }
        return [
            PointerMarker(
                name: "front", index: firstIndex,
                valueText: nil, theme: theme
            ),
            PointerMarker(
                name: "back", index: lastIndex,
                valueText: nil, theme: theme
            )
        ]
    }

    // MARK: - Matrix Pointers

    func matrixPointerCell() -> MatrixPointerCell? {
        guard let selectedEvent else { return nil }
        let rowNames = ["i", "r", "row", "x"]
        let colNames = ["j", "c", "col", "y"]
        var row: Int?
        var col: Int?
        for (key, value) in selectedEvent.values {
            guard case let .number(number, isInt) = value, isInt else { continue }
            let lowered = key.lowercased()
            if row == nil, rowNames.contains(lowered) {
                row = Int(number)
            } else if col == nil, colNames.contains(lowered) {
                col = Int(number)
            }
        }
        guard let row, let col else { return nil }
        return MatrixPointerCell(row: row, col: col)
    }
}
