import Foundation

/// Protocol for the Data Journey subsystem interactor.
///
/// Handles processing of trace events for the Data Journey visualization.
/// This is a lightweight interactor -- Data Journey is primarily a
/// visualization feature. The interactor handles event filtering and
/// truncation logic.
protocol DataJourneyInteracting: AnyObject {
    /// Filters and processes trace events (e.g. deduplication, capping).
    func processTraceEvents(
        _ events: [DataJourneyEvent]
    ) -> [DataJourneyEvent]

    /// Checks whether the trace exceeds the given step limit.
    func shouldTruncate(
        events: [DataJourneyEvent],
        limit: Int
    ) -> Bool
}

/// Concrete interactor for the Data Journey subsystem.
///
/// NOT `@MainActor` -- operates on trace data passed from execution results.
/// No service injection needed; Data Journey processes in-memory event data.
final class DataJourneyInteractor: DataJourneyInteracting {
    private let maxSteps: Int

    init(maxSteps: Int = 40) {
        self.maxSteps = maxSteps
    }

    // MARK: - Event Processing

    func processTraceEvents(
        _ events: [DataJourneyEvent]
    ) -> [DataJourneyEvent] {
        var stepCount = 0
        var processed: [DataJourneyEvent] = []

        for event in events {
            if event.kind == .step {
                guard stepCount < maxSteps else { continue }
                stepCount += 1
            }
            processed.append(event)
        }

        return processed
    }

    func shouldTruncate(
        events: [DataJourneyEvent],
        limit: Int
    ) -> Bool {
        var stepCount = 0
        for event in events where event.kind == .step {
            stepCount += 1
            if stepCount > limit {
                return true
            }
        }
        return false
    }
}
