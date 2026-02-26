import Foundation

/// Single factory for converting raw data into `TraceValue`.
///
/// Consolidates three parsing paths that previously lived in separate files:
/// - String parsing (from `TestResultBridge.parseValue`)
/// - JSON parsing (from `TraceValue.from(json:)`)
/// - Codable decoding (from `TraceStepValue.toTraceValue()`)
///
/// All Data Journey input/expected/output flows through this factory.
enum JourneyValueFactory {

    // MARK: - From String (test result input/output fields)

    /// Parses a serialized string value into a `TraceValue`.
    ///
    /// Handles: null, bool, int, float, quoted strings, arrays, and unquoted strings.
    static func fromString(_ str: String) -> TraceValue {
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
        if let intVal = Int(trimmed) {
            return .number(Double(intVal), isInt: true)
        }
        if let doubleVal = Double(trimmed) {
            return .number(doubleVal, isInt: false)
        }
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return .string(String(trimmed.dropFirst().dropLast()))
        }
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            return parseArray(trimmed)
        }
        return .string(trimmed)
    }

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
                result[name] = fromString(valueStr)
            } else {
                let trimmed = assignment.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    result["arg\(result.count)"] = fromString(trimmed)
                }
            }
        }
        return result
    }

    // MARK: - From JSON (runtime trace data via JSONSerialization)

    /// Converts a JSON object (`Any` from JSONSerialization) into a `TraceValue`.
    static func fromJSON(_ json: Any) -> TraceValue {
        TraceValue.from(json: json)
    }

    // MARK: - From Decoder (Codable trace step values)

    /// Decodes a single JSON value from a `Decoder` into a `TraceValue`.
    ///
    /// Replaces the old `TraceStepValue` enum — handles all the same cases
    /// but produces `TraceValue` directly, eliminating the intermediate type.
    static func fromDecoder(_ decoder: Decoder) throws -> TraceValue {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            return .null
        }
        if let v = try? container.decode(Bool.self) {
            return .bool(v)
        }
        if let v = try? container.decode(Int.self) {
            return .number(Double(v), isInt: true)
        }
        if let v = try? container.decode(Double.self) {
            return .number(v, isInt: false)
        }
        if let v = try? container.decode(String.self) {
            return .string(v)
        }
        if let v = try? container.decode([Int].self) {
            return .array(v.map { .number(Double($0), isInt: true) })
        }
        if let v = try? container.decode([[Int]].self) {
            return .array(v.map { row in .array(row.map { .number(Double($0), isInt: true) }) })
        }
        if let v = try? container.decode([String].self) {
            return .array(v.map { .string($0) })
        }
        if let v = try? container.decode([String: Int].self) {
            let obj = v.reduce(into: [String: TraceValue]()) { $0[$1.key] = .number(Double($1.value), isInt: true) }
            return .object(obj)
        }
        throw DecodingError.typeMismatch(
            TraceValue.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Unsupported trace step value type")
        )
    }

    // MARK: - String Parsing Helpers

    private static func parseArray(_ str: String) -> TraceValue {
        let inner = String(str.dropFirst().dropLast())
            .trimmingCharacters(in: .whitespaces)
        if inner.isEmpty {
            return .array([])
        }
        let elements = splitArrayElements(inner)
        return .array(elements.map { fromString($0) })
    }

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
}
