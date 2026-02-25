import LeetPulseDesignSystem
import SwiftUI

// MARK: - Diff Highlighting Helpers

extension DataJourneyStructureCanvasView {
    /// Finds the primary structure value from an event for diff computation.
    private func primaryStructureValue(
        in event: DataJourneyEvent?
    ) -> TraceValue? {
        guard let event else { return nil }
        for key in event.values.keys.sorted() {
            guard let value = event.values[key] else { continue }
            switch value {
            case .array, .list, .tree, .object, .typed:
                return value
            default:
                continue
            }
        }
        return nil
    }

    /// Highlighted array indices from diff between previous and current.
    func structureArrayHighlights(
        items: [TraceValue]
    ) -> Set<Int> {
        guard previousEvent != nil else { return [] }
        let prevValue = primaryStructureValue(in: previousEvent)
        let currValue = primaryStructureValue(in: selectedEvent)
        return TraceValueDiff.changedIndices(
            previous: prevValue,
            current: currValue
        )
    }

    /// Highlighted tree node IDs from diff between previous and current.
    var structureTreeHighlights: Set<String> {
        guard previousEvent != nil else { return [] }
        let prevValue = primaryStructureValue(in: previousEvent)
        let currValue = primaryStructureValue(in: selectedEvent)
        return TraceValueDiff.changedTreeNodeIds(
            previous: prevValue,
            current: currValue
        )
    }

    /// Per-element change types from diff between previous and current.
    func structureElementChanges(
        items: [TraceValue]
    ) -> [ChangeType] {
        guard previousEvent != nil else { return [] }
        let prevValue = primaryStructureValue(in: previousEvent)
        let currValue = primaryStructureValue(in: selectedEvent)
        return TraceValueDiff.elementChanges(
            previous: prevValue,
            current: currValue
        )
    }

    /// Highlighted matrix cells from diff between previous and current.
    var structureMatrixHighlights: Set<MatrixCell> {
        guard previousEvent != nil else { return [] }
        let prevValue = primaryStructureValue(in: previousEvent)
        let currValue = primaryStructureValue(in: selectedEvent)
        return TraceValueDiff.changedMatrixCells(
            previous: prevValue,
            current: currValue
        )
    }
}
