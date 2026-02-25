import Foundation
import Observation

/// Presenter for the Data Journey subsystem.
///
/// Owns visualization state (5 properties) for the Data Journey
/// timeline. Compiles on BOTH platforms -- no `#if os()` guards needed.
/// On iOS, the presenter simply never gets updated since trace events
/// are not generated from LeetCode API execution.
@Observable @MainActor
final class DataJourneyPresenter {
    // MARK: - Published State (5 properties)

    /// Trace events for the Data Journey visualization.
    var dataJourney: [DataJourneyEvent] = []

    /// The currently selected event in the Data Journey timeline.
    var selectedJourneyEventID: String?

    /// The source line highlighted in the code editor for the selected event.
    var highlightedExecutionLine: Int?

    /// Whether the trace was truncated due to size limits.
    var isJourneyTruncated: Bool = false

    /// Source code from the code editor, used for the 3-line code context view.
    var sourceCode: String = ""

    // MARK: - Private

    private let interactor: DataJourneyInteracting

    // MARK: - Init

    init(interactor: DataJourneyInteracting) {
        self.interactor = interactor
    }

    // MARK: - Public Methods

    /// Processes and stores trace events from an execution run.
    /// Sets truncation flag if events exceeded the step limit.
    func updateFromExecution(traceEvents: [DataJourneyEvent]) {
        let shouldTruncate = interactor.shouldTruncate(
            events: traceEvents,
            limit: 40
        )
        let processed = interactor.processTraceEvents(traceEvents)
        dataJourney = processed
        isJourneyTruncated = shouldTruncate

        // Auto-select the first meaningful event
        if let step = processed.first(where: { $0.kind == .step }) {
            selectEvent(step.id)
        } else if let input = processed.first(
            where: { $0.kind == .input }
        ) {
            selectEvent(input.id)
        } else if let output = processed.first(
            where: { $0.kind == .output }
        ) {
            selectEvent(output.id)
        } else {
            selectedJourneyEventID = nil
            highlightedExecutionLine = nil
        }
    }

    /// Selects an event by ID and updates the highlighted line.
    func selectEvent(_ id: String?) {
        selectedJourneyEventID = id
        if let id,
           let event = dataJourney.first(where: { $0.id == id }) {
            highlightedExecutionLine = event.line
        } else {
            highlightedExecutionLine = nil
        }
    }

    /// Resets all Data Journey state.
    func clear() {
        dataJourney = []
        selectedJourneyEventID = nil
        highlightedExecutionLine = nil
        isJourneyTruncated = false
        sourceCode = ""
    }
}
