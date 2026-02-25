import SwiftUI

/// Thin delegate: all structure detection and resolution logic lives in StructureResolver.
extension DataJourneyStructureCanvasView {
    /// Resolved structure for the current event combination.
    /// Delegates entirely to the standalone StructureResolver utility.
    var structure: TraceStructure? {
        StructureResolver.resolve(
            inputEvent: inputEvent,
            selectedEvent: selectedEvent,
            outputEvent: outputEvent,
            override: structureOverride
        )
    }
}
