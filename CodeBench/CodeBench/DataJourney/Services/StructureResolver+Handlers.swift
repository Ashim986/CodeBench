import Foundation

// MARK: - Typed / Array / Object / String Handlers

extension StructureResolver {
    static func handleTyped(
        value: TraceValue,
        fallback: inout TraceStructure?
    ) -> Bool {
        guard case let .typed(type, inner) = value,
              let typedItems = typedSequenceItems(from: inner)
        else { return false }
        let lowered = type.lowercased()
        if lowered == "set" {
            fallback = fallback ?? .set(typedItems)
            return true
        }
        if lowered == "stack" {
            fallback = fallback ?? .stack(typedItems)
            return true
        }
        if lowered == "queue" {
            fallback = fallback ?? .queue(typedItems)
            return true
        }
        if isMinHeapName(lowered) {
            fallback = fallback ?? .heap(typedItems, isMinHeap: true)
            return true
        }
        if isMaxHeapName(lowered) {
            fallback = fallback ?? .heap(
                typedItems, isMinHeap: false
            )
            return true
        }
        if lowered == "heap" {
            fallback = fallback ?? .heap(typedItems, isMinHeap: true)
            return true
        }
        return false
    }

    static func isMinHeapName(_ name: String) -> Bool {
        name == "minheap" || name == "min-heap"
            || name == "min_heap"
    }

    static func isMaxHeapName(_ name: String) -> Bool {
        name == "maxheap" || name == "max-heap"
            || name == "max_heap"
    }

    static func handleArray(
        value: TraceValue,
        name: String,
        fallback: inout TraceStructure?
    ) -> Bool {
        guard case let .array(items) = value else { return false }
        let loweredName = name.lowercased()
        if loweredName.contains("heap") {
            let isMin = loweredName.contains("min")
            fallback = fallback ?? .heap(
                items,
                isMinHeap: isMin || !loweredName.contains("max")
            )
            return true
        }
        if loweredName.contains("stack") {
            fallback = fallback ?? .stack(items)
            return true
        }
        if loweredName.contains("queue") {
            fallback = fallback ?? .queue(items)
            return true
        }
        if let listArray = listArrayStructure(from: items) {
            fallback = .listArray(listArray)
            return true
        }
        if let grid = matrixStructure(
            from: items, name: loweredName
        ) {
            fallback = fallback ?? .matrix(grid)
            return true
        }
        if let adjacency = graphAdjacency(from: items) {
            fallback = fallback ?? .graph(adjacency)
        } else {
            fallback = fallback ?? .array(items)
        }
        return true
    }

    static func handleObject(
        value: TraceValue,
        fallback: inout TraceStructure?
    ) -> Bool {
        guard case let .object(map) = value else { return false }
        fallback = fallback ?? .dictionary(
            dictionaryEntries(from: map)
        )
        return true
    }

    static func handleString(
        value: TraceValue,
        fallback: inout TraceStructure?
    ) -> Bool {
        guard case let .string(stringValue) = value else {
            return false
        }
        guard stringValue.count >= 2 else { return false }
        let chars = stringValue.map {
            TraceValue.string(String($0))
        }
        fallback = fallback ?? .stringSequence(stringValue, chars)
        return true
    }

    static func typedSequenceItems(
        from value: TraceValue
    ) -> [TraceValue]? {
        switch value {
        case let .array(items):
            items
        case let .list(list):
            list.nodes.map(\.value)
        default:
            nil
        }
    }

    static func isPrimitive(_ value: TraceValue) -> Bool {
        switch value {
        case .null, .bool, .number, .string:
            true
        default:
            false
        }
    }
}

// MARK: - Resolution Internals

extension StructureResolver {
    enum StructureSource: Int {
        case output = 1
        case input = 2
        case selected = 3
    }

    struct StructureCandidate {
        let source: StructureSource
        let structure: TraceStructure
    }

    struct PointerStructureMatch {
        let coverage: Int
        let source: Int
        let structure: TraceStructure
    }

    static func structureCandidates(
        inputEvent: DataJourneyEvent?,
        selectedEvent: DataJourneyEvent?,
        outputEvent: DataJourneyEvent?
    ) -> [StructureCandidate] {
        let sources: [(StructureSource, DataJourneyEvent?)] = [
            (.selected, selectedEvent),
            (.output, outputEvent),
            (.input, inputEvent)
        ]
        return sources.compactMap { source, event in
            guard let detected = structure(in: event) else {
                return nil
            }
            return StructureCandidate(
                source: source, structure: detected
            )
        }
    }

    static func bestPointerStructure(
        from candidates: [StructureCandidate],
        pointerCandidates: [(name: String, value: TraceValue)]
    ) -> TraceStructure? {
        var best: PointerStructureMatch?
        for candidate in candidates {
            let coverage = pointerCoverage(
                of: candidate.structure,
                pointerCandidates: pointerCandidates
            )
            guard coverage > 0 else { continue }
            let sourcePriority = candidate.source.rawValue
            if let currentBest = best {
                if coverage > currentBest.coverage
                    || (coverage == currentBest.coverage
                        && sourcePriority > currentBest.source) {
                    best = PointerStructureMatch(
                        coverage: coverage,
                        source: sourcePriority,
                        structure: candidate.structure
                    )
                }
            } else {
                best = PointerStructureMatch(
                    coverage: coverage,
                    source: sourcePriority,
                    structure: candidate.structure
                )
            }
        }
        return best?.structure
    }

    static func fallbackStructure(
        from candidates: [StructureCandidate]
    ) -> TraceStructure? {
        if let selected = candidates.first(
            where: { $0.source == .selected }
        ) {
            return selected.structure
        }
        if let input = candidates.first(
            where: { $0.source == .input }
        ) {
            return input.structure
        }
        if let output = candidates.first(
            where: { $0.source == .output }
        ) {
            return output.structure
        }
        return nil
    }

    static func pointerCoverage(
        of structure: TraceStructure,
        pointerCandidates: [(name: String, value: TraceValue)]
    ) -> Int {
        let listIDs = listNodeIDs(in: structure)
        let treeIDs = treeNodeIDs(in: structure)

        var resolvedCount = 0
        for candidate in pointerCandidates {
            switch candidate.value {
            case let .listPointer(id):
                if listIDs.contains(id) {
                    resolvedCount += 1
                }
            case let .treePointer(id):
                if treeIDs.contains(id) {
                    resolvedCount += 1
                }
            default:
                break
            }
        }
        return resolvedCount
    }

    static func listNodeIDs(
        in structure: TraceStructure
    ) -> Set<String> {
        switch structure {
        case let .list(list):
            Set(list.nodes.map(\.id))
        case let .listGroup(lists):
            Set(
                lists.flatMap { $0.list.nodes.map(\.id) }
            )
        case let .listArray(listArray):
            Set(
                listArray.lists.flatMap {
                    $0.list.nodes.map(\.id)
                }
            )
        default:
            []
        }
    }

    static func treeNodeIDs(
        in structure: TraceStructure
    ) -> Set<String> {
        switch structure {
        case let .tree(tree):
            Set(tree.nodes.map(\.id))
        default:
            []
        }
    }
}

// MARK: - Pointer Candidates

extension StructureResolver {
    static func pointerCandidates(
        in event: DataJourneyEvent
    ) -> [(name: String, value: TraceValue)] {
        var result: [(name: String, value: TraceValue)] = []
        for key in event.values.keys.sorted() {
            guard let value = event.values[key] else { continue }
            collectPointerCandidates(
                path: key, value: value, into: &result
            )
        }
        return result
    }

    static func collectPointerCandidates(
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
                collectPointerCandidates(
                    path: "\(path).\(key)", value: nested,
                    into: &result
                )
            }
        case let .array(items):
            for (index, nested) in items.enumerated() {
                collectPointerCandidates(
                    path: "\(path)[\(index)]", value: nested,
                    into: &result
                )
            }
        default:
            break
        }
    }
}
