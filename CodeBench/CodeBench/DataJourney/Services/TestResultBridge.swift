import Foundation

/// Converts `TestResult` data into `DataJourneyEvent` arrays for visualization.
///
/// Parses the textual input/output strings from test results into structured
/// `TraceValue` types so the DataJourney system can render them.
enum TestResultBridge {
    /// Creates a DataJourney event sequence from a `TestResult`.
    ///
    /// Returns 2-3 events:
    /// 1. `.input` — parsed parameters from the test input string
    /// 2. `.output` — the computed output
    /// 3. `.output` — the expected output (if different from computed)
    static func events(from result: TestResult) -> [DataJourneyEvent] {
        var events: [DataJourneyEvent] = []

        // Parse input parameters
        let inputValues = parseInputParameters(result.input)
        if !inputValues.isEmpty {
            events.append(DataJourneyEvent(
                kind: .input,
                line: nil,
                label: "Input",
                values: inputValues
            ))
        }

        // Parse expected output
        let expectedValue = parseValue(result.originalExpected.trimmingCharacters(in: .whitespaces))
        events.append(DataJourneyEvent(
            kind: .step,
            line: nil,
            label: "Expected",
            values: ["expected": expectedValue]
        ))

        // Parse computed output
        let computedValue = parseValue(result.computedOutput.trimmingCharacters(in: .whitespaces))
        events.append(DataJourneyEvent(
            kind: .output,
            line: nil,
            label: result.outputMatches ? "Output (Match)" : "Output (Mismatch)",
            values: ["result": computedValue]
        ))

        return events
    }

    // MARK: - Input Parsing

    /// Parses an input string like `"nums = [2,7,11,15], target = 9"` into
    /// a dictionary of parameter name → TraceValue.
    static func parseInputParameters(_ input: String) -> [String: TraceValue] {
        var result: [String: TraceValue] = [:]
        let assignments = splitAssignments(input)

        for assignment in assignments {
            let parts = assignment.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let name = parts[0].trimmingCharacters(in: .whitespaces)
                let valueStr = parts[1].trimmingCharacters(in: .whitespaces)
                result[name] = parseValue(valueStr)
            } else {
                // No `=` sign, treat the whole thing as a single unnamed parameter
                let trimmed = assignment.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    result["arg\(result.count)"] = parseValue(trimmed)
                }
            }
        }

        return result
    }

    /// Splits `"nums = [2,7,11,15], target = 9"` into
    /// `["nums = [2,7,11,15]", "target = 9"]`, respecting brackets.
    private static func splitAssignments(_ input: String) -> [String] {
        var segments: [String] = []
        var current = ""
        var depth = 0

        for char in input {
            if char == "[" || char == "(" || char == "{" {
                depth += 1
                current.append(char)
            } else if char == "]" || char == ")" || char == "}" {
                depth -= 1
                current.append(char)
            } else if char == "," && depth == 0 {
                // Check if this comma separates assignments (has `=` ahead)
                // vs. is inside a value
                let remaining = input[input.index(after: input.firstIndex(of: char)!)...]
                if remaining.contains("=") {
                    segments.append(current)
                    current = ""
                } else {
                    current.append(char)
                }
            } else {
                current.append(char)
            }
        }

        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            segments.append(current)
        }

        return segments
    }

    // MARK: - Value Parsing

    /// Parses a string value into a `TraceValue`.
    static func parseValue(_ str: String) -> TraceValue {
        let trimmed = str.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty || trimmed == "null" || trimmed == "None" || trimmed == "nil" {
            return .null
        }

        if trimmed == "true" || trimmed == "True" {
            return .bool(true)
        }
        if trimmed == "false" || trimmed == "False" {
            return .bool(false)
        }

        // Integer
        if let intVal = Int(trimmed) {
            return .number(Double(intVal), isInt: true)
        }

        // Float
        if let doubleVal = Double(trimmed) {
            return .number(doubleVal, isInt: false)
        }

        // Quoted string
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            let inner = String(trimmed.dropFirst().dropLast())
            return .string(inner)
        }

        // Array: [...]
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            return parseArray(trimmed)
        }

        // Unquoted string (parameter values like "hello")
        return .string(trimmed)
    }

    /// Parses `"[1, 2, [3, 4], 5]"` into `.array(...)`, handling nested arrays.
    private static func parseArray(_ str: String) -> TraceValue {
        let inner = String(str.dropFirst().dropLast())
            .trimmingCharacters(in: .whitespaces)

        if inner.isEmpty {
            return .array([])
        }

        let elements = splitArrayElements(inner)
        let values = elements.map { parseValue($0) }

        return .array(values)
    }

    /// Splits array elements respecting nested brackets.
    /// `"1, [2,3], 4"` → `["1", "[2,3]", "4"]`
    private static func splitArrayElements(_ str: String) -> [String] {
        var elements: [String] = []
        var current = ""
        var depth = 0

        for char in str {
            if char == "[" || char == "(" || char == "{" {
                depth += 1
                current.append(char)
            } else if char == "]" || char == ")" || char == "}" {
                depth -= 1
                current.append(char)
            } else if char == "," && depth == 0 {
                elements.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }

        let last = current.trimmingCharacters(in: .whitespaces)
        if !last.isEmpty {
            elements.append(last)
        }

        return elements
    }
}
