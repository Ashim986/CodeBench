import Foundation

/// Standalone utility for detecting and resolving data structure types from trace events.
/// Decoupled from any View -- can be called without instantiating a SwiftUI view.
enum StructureResolver {
    // MARK: - Public API

    /// Resolve the best structure to display given the available events.
    /// Replaces the old `DataJourneyStructureCanvasView.structure` computed property.
    static func resolve(
        inputEvent: DataJourneyEvent?,
        selectedEvent: DataJourneyEvent?,
        outputEvent: DataJourneyEvent?,
        override: TraceStructure? = nil
    ) -> TraceStructure? {
        if let override { return override }
        let candidates = structureCandidates(
            inputEvent: inputEvent,
            selectedEvent: selectedEvent,
            outputEvent: outputEvent
        )
        guard !candidates.isEmpty else { return nil }

        if let selectedEvent {
            let selectedPointers = pointerCandidates(in: selectedEvent)
            if !selectedPointers.isEmpty,
               let resolved = bestPointerStructure(
                   from: candidates,
                   pointerCandidates: selectedPointers
               ) {
                return resolved
            }
        }

        return fallbackStructure(from: candidates)
    }

    /// Detect a structure from a single event's values.
    static func structure(
        in event: DataJourneyEvent?
    ) -> TraceStructure? {
        guard let event else { return nil }
        let keys = event.values.keys.sorted()

        var lists: [NamedTraceList] = []
        var fallback: TraceStructure?
        for key in keys {
            guard let value = event.values[key] else { continue }
            if handleList(value: value, name: key, lists: &lists) {
                continue
            }
            if handleTyped(value: value, fallback: &fallback) {
                continue
            }
            if handleArray(
                value: value, name: key, fallback: &fallback
            ) { continue }
            if handleTree(value: value, fallback: &fallback) {
                continue
            }
            if handleTrie(value: value, fallback: &fallback) {
                continue
            }
            if handleObject(value: value, fallback: &fallback) {
                continue
            }
            if handleString(value: value, fallback: &fallback) {
                continue
            }
        }
        return finalizeStructure(lists: lists, fallback: fallback)
    }

    // MARK: - Shared Detection Helpers

    static func dictionaryEntries(
        from map: [String: TraceValue]
    ) -> [DictionaryEntry] {
        map.keys.sorted().compactMap { key in
            guard let value = map[key] else { return nil }
            return DictionaryEntry(key: key, value: value)
        }
    }

    static func matrixStructure(
        from items: [TraceValue],
        name: String
    ) -> [[TraceValue]]? {
        guard items.count >= 2 else { return nil }
        var rows: [[TraceValue]] = []
        for item in items {
            guard case let .array(inner) = item, !inner.isEmpty
            else { return nil }
            rows.append(inner)
        }
        let colCount = rows[0].count
        guard rows.allSatisfy({ $0.count == colCount })
        else { return nil }
        let matrixNames = [
            "grid", "board", "matrix", "dp",
            "table", "maze", "map"
        ]
        let nameHint = matrixNames.contains(
            where: { name.contains($0) }
        )
        if nameHint { return rows }
        let allPrimitive = rows.allSatisfy { row in
            row.allSatisfy { isPrimitive($0) }
        }
        guard allPrimitive else { return nil }
        let allBinaryInt = rows.allSatisfy { row in
            row.allSatisfy { value in
                guard case let .number(num, isInt) = value,
                      isInt else { return false }
                return num == 0 || num == 1
            }
        }
        if allBinaryInt, colCount == rows.count {
            return nil
        }
        return rows
    }

    // MARK: - List Structure Detection

    static func handleList(
        value: TraceValue,
        name: String,
        lists: inout [NamedTraceList]
    ) -> Bool {
        guard case let .list(list) = value else { return false }
        lists.append(NamedTraceList(id: name, name: name, list: list))
        return true
    }

    static func listArrayStructure(
        from items: [TraceValue]
    ) -> ListArrayStructure? {
        guard !items.isEmpty else { return nil }
        var lists: [NamedTraceList] = []
        var heads: [TraceValue] = []
        for (index, item) in items.enumerated() {
            switch item {
            case let .list(list):
                let name = "list[\(index)]"
                lists.append(
                    NamedTraceList(
                        id: name, name: name, list: list
                    )
                )
                heads.append(list.nodes.first?.value ?? .null)
            case .null:
                let emptyList = TraceList(
                    nodes: [], cycleIndex: nil,
                    isTruncated: false, isDoubly: false
                )
                let name = "list[\(index)]"
                lists.append(
                    NamedTraceList(
                        id: name, name: name, list: emptyList
                    )
                )
                heads.append(.null)
            default:
                return nil
            }
        }
        return ListArrayStructure(heads: heads, lists: lists)
    }

    static func finalizeStructure(
        lists: [NamedTraceList],
        fallback: TraceStructure?
    ) -> TraceStructure? {
        if lists.count > 1 {
            return .listGroup(lists)
        }
        if let list = lists.first {
            return .list(list.list)
        }
        return fallback
    }

    // MARK: - Tree / Graph Structure Detection

    static func handleTree(
        value: TraceValue,
        fallback: inout TraceStructure?
    ) -> Bool {
        guard case let .tree(tree) = value else { return false }
        fallback = fallback ?? .tree(tree)
        return true
    }

    static func handleTrie(
        value: TraceValue,
        fallback: inout TraceStructure?
    ) -> Bool {
        guard case let .trie(trieData) = value else { return false }
        fallback = fallback ?? .trie(trieData)
        return true
    }

    static func graphAdjacency(
        from items: [TraceValue]
    ) -> [[Int]]? {
        guard !items.isEmpty else { return nil }
        var rows: [[Int]] = []
        for item in items {
            guard case let .array(inner) = item else { return nil }
            var row: [Int] = []
            for value in inner {
                guard case let .number(number, isInt) = value
                else { return nil }
                let intValue = Int(number)
                if !isInt, Double(intValue) != number {
                    return nil
                }
                row.append(intValue)
            }
            rows.append(row)
        }
        let nodeCount = rows.count
        // Binary adjacency matrix (N x N of 0s and 1s)
        let isMatrix = rows.allSatisfy { $0.count == nodeCount }
            && rows.flatMap { $0 }.allSatisfy { $0 == 0 || $0 == 1 }
        if isMatrix {
            var adjacency: [[Int]] = Array(
                repeating: [], count: nodeCount
            )
            for rowIdx in 0 ..< nodeCount {
                for colIdx in 0 ..< nodeCount
                    where rows[rowIdx][colIdx] != 0 {
                    adjacency[rowIdx].append(colIdx)
                }
            }
            return adjacency
        }
        // Validate as adjacency list: values must be valid
        // node indices (non-negative, within reasonable range).
        guard passesAdjacencyListValidation(rows) else {
            return nil
        }
        return rows
    }

    // MARK: - Adjacency List Validation

    /// Validates that a `[[Int]]` looks like a genuine adjacency
    /// list rather than bucket sort output, DP tables, etc.
    ///
    /// Rejects when:
    /// - All rows have the same fixed length > 2 (likely a matrix)
    /// - Any value is negative (not a valid node index)
    /// - Values exceed a generous upper bound relative to node count
    /// - Rows are too uniform in length with large values (bucket sort)
    private static func passesAdjacencyListValidation(
        _ rows: [[Int]]
    ) -> Bool {
        let nodeCount = rows.count
        guard nodeCount >= 2 else { return false }
        let nonEmptyRows = rows.filter { !$0.isEmpty }
        // Reject if all non-empty rows have the same fixed length
        // > 2. Adjacency lists typically have varying row lengths;
        // uniform fixed-width rows suggest a matrix or table.
        if nonEmptyRows.count >= 2 {
            let lengths = Set(nonEmptyRows.map(\.count))
            if lengths.count == 1, let fixedLen = lengths.first,
               fixedLen > 2 {
                return false
            }
        }
        // Upper bound for valid node indices: allow references
        // up to 2x the outer array length to handle graphs
        // where node IDs exceed the array size slightly.
        let maxAllowed = max(nodeCount * 2, 10)
        let allValues = rows.flatMap { $0 }
        // All values must be non-negative
        guard allValues.allSatisfy({ $0 >= 0 }) else {
            return false
        }
        // All values must be within the generous upper bound
        guard allValues.allSatisfy({ $0 < maxAllowed }) else {
            return false
        }
        // Adjacency lists should reference actual nodes. If the
        // vast majority of values exceed nodeCount, this is
        // likely data (bucket sort), not graph edges.
        let outOfRange = allValues.count(where: {
            $0 >= nodeCount
        })
        let total = allValues.count
        if total > 0, Double(outOfRange) / Double(total) > 0.5 {
            return false
        }
        return true
    }
}
