import Foundation

/// Converts `TestResult` data into `DataJourneyEvent` arrays for visualization.
///
/// Uses `JourneyValueFactory` for all value parsing — input, expected, output,
/// and trace steps all flow through the same factory.
enum TestResultBridge {
    /// Creates a DataJourney event sequence from a `TestResult`.
    ///
    /// When `traceSteps` is present, produces: Input → N algorithm steps → Expected → Output.
    /// Otherwise falls back to: Input → Expected → Output (2-3 events).
    static func events(from result: TestResult) -> [DataJourneyEvent] {
        var events: [DataJourneyEvent] = []

        // 1. Input event — parsed via factory
        let inputValues = JourneyValueFactory.parseInputParameters(result.input)
        if !inputValues.isEmpty {
            events.append(DataJourneyEvent(
                id: "event-0-input-0-Input",
                kind: .input,
                line: nil,
                label: "Input",
                values: inputValues
            ))
        }

        // 2. Algorithm trace steps — values already decoded as TraceValue by TraceStep
        if let traceSteps = result.traceSteps, !traceSteps.isEmpty {
            for (idx, step) in traceSteps.enumerated() {
                events.append(DataJourneyEvent(
                    id: "event-\(events.count)-step-\(idx)-\(step.label)",
                    kind: .step,
                    line: nil,
                    label: step.label,
                    values: step.values
                ))
            }
        }

        // 3. Expected output — parsed via factory
        let expectedValue = JourneyValueFactory.fromString(
            result.originalExpected.trimmingCharacters(in: .whitespaces)
        )
        events.append(DataJourneyEvent(
            id: "event-\(events.count)-step-expected-Expected",
            kind: .step,
            line: nil,
            label: "Expected",
            values: ["expected": expectedValue]
        ))

        // 4. Computed output — parsed via factory
        let computedValue = JourneyValueFactory.fromString(
            result.computedOutput.trimmingCharacters(in: .whitespaces)
        )
        let outputLabel = result.outputMatches ? "Match" : "Mismatch"
        events.append(DataJourneyEvent(
            id: "event-\(events.count)-output-\(outputLabel)",
            kind: .output,
            line: nil,
            label: outputLabel,
            values: ["result": computedValue]
        ))

        return events
    }
}
