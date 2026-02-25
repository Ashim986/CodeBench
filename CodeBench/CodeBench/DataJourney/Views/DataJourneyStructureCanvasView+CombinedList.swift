import LeetPulseDesignSystem
import SwiftUI

extension DataJourneyStructureCanvasView {
    func combinedListViewModel(for lists: [NamedTraceList]) -> CombinedListViewModel {
        var items: [TraceValue] = []
        var pointers: [PointerMarker] = []
        var gapIndices: Set<Int> = []
        var offset = 0
        var truncated = false

        for (index, entry) in lists.enumerated() {
            let values = entry.list.nodes.map(\.value)
            if items.count + values.count > combinedMaxItems {
                let remaining = max(combinedMaxItems - items.count, 0)
                if remaining > 0 {
                    items.append(contentsOf: values.prefix(remaining))
                }
                truncated = true
                break
            } else {
                items.append(contentsOf: values)
            }

            if let selectedEvent {
                let listMarkers = listPointers(in: selectedEvent, list: entry.list)
                for marker in listMarkers {
                    if let indexValue = marker.index {
                        pointers.append(
                            PointerMarker(
                                name: marker.name,
                                index: indexValue + offset,
                                theme: theme
                            )
                        )
                    }
                }
            }

            offset += values.count

            // Insert gap indices between lists for visual separation
            if !values.isEmpty, index < lists.count - 1 {
                let hasFutureValues = lists[(index + 1)...].contains { !$0.list.nodes.isEmpty }
                if hasFutureValues {
                    gapIndices.insert(items.count - 1)
                }
            }
        }

        if lists.contains(where: \.list.isTruncated) {
            truncated = true
        }

        return CombinedListViewModel(
            items: items,
            pointers: pointers.sorted { $0.name < $1.name },
            isTruncated: truncated,
            gapIndices: gapIndices
        )
    }

    func outputSequenceLinks(for lists: [NamedTraceList]) -> [SequenceLink] {
        guard let outputList = outputList(from: outputEvent) else { return [] }
        var idToIndex: [String: Int] = [:]
        var offset = 0
        for entry in lists {
            for (index, node) in entry.list.nodes.enumerated() {
                idToIndex[node.id] = index + offset
            }
            offset += entry.list.nodes.count
        }
        var indices: [Int] = []
        for node in outputList.nodes {
            if let index = idToIndex[node.id] {
                indices.append(index)
            }
        }
        guard indices.count > 1 else { return [] }
        let linkPalette: [Color] = [
            theme.vizColors.tertiary,
            theme.vizColors.secondary,
            theme.vizColors.primary,
            theme.vizColors.quinary
        ]
        var links: [SequenceLink] = []
        for (index, pair) in zip(indices, indices.dropFirst()).enumerated() {
            let color = linkPalette[index % linkPalette.count]
            links.append(SequenceLink(fromIndex: pair.0, toIndex: pair.1, color: color))
        }
        return visibleSequenceLinks(
            links,
            outputList: outputList,
            idToIndex: idToIndex
        )
    }

    func visibleSequenceLinks(
        _ links: [SequenceLink],
        outputList: TraceList,
        idToIndex: [String: Int]
    ) -> [SequenceLink] {
        guard !links.isEmpty else { return links }
        guard let selectedEvent else { return links }
        if selectedEvent.kind == .output {
            return links
        }
        if selectedEvent.kind == .input {
            return []
        }
        if let maxPointerIndex = maxPointerIndex(
            in: selectedEvent,
            outputList: outputList,
            idToIndex: idToIndex
        ) {
            let count = min(links.count, max(0, maxPointerIndex))
            return Array(links.prefix(count))
        }
        let offset = beginsAtZero ? 0 : 1
        let count = min(links.count, max(0, playbackIndex + offset))
        return Array(links.prefix(count))
    }

    func maxPointerIndex(
        in event: DataJourneyEvent,
        outputList: TraceList,
        idToIndex: [String: Int]
    ) -> Int? {
        var maxIndex: Int?
        let candidates = pointerCandidates(in: event)
        for candidate in candidates {
            guard case let .listPointer(id) = candidate.value,
                  outputList.nodes.contains(where: { $0.id == id }),
                  let index = idToIndex[id] else { continue }
            maxIndex = max(maxIndex ?? -1, index)
        }
        return maxIndex
    }

    func outputList(from event: DataJourneyEvent?) -> TraceList? {
        guard let event else { return nil }
        if let value = event.values["result"],
           let list = firstList(in: value) {
            return list
        }
        for key in event.values.keys.sorted() {
            guard let value = event.values[key],
                  let list = firstList(in: value) else { continue }
            return list
        }
        return nil
    }

    func firstList(in value: TraceValue) -> TraceList? {
        switch value {
        case let .list(list):
            return list
        case let .typed(_, inner):
            return firstList(in: inner)
        case let .array(items):
            for item in items {
                if let list = firstList(in: item) {
                    return list
                }
            }
            return nil
        case let .object(map):
            for key in map.keys.sorted() {
                if let nested = map[key],
                   let list = firstList(in: nested) {
                    return list
                }
            }
            return nil
        default:
            return nil
        }
    }
}
