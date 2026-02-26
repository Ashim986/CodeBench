import Foundation

// MARK: - Summary JSON

struct TestSummary: Codable {
    let evaluatedAt: String
    let totalResults: Int
    let topics: [TopicSummary]
    var problems: [ProblemMeta]

    enum CodingKeys: String, CodingKey {
        case evaluatedAt = "evaluated_at"
        case totalResults = "total_results"
        case topics, problems
    }
}

struct TopicSummary: Codable, Identifiable {
    let topic: String
    let total: Int
    let valid: Int
    let invalid: Int
    let matches: Int
    let matchRate: Double

    var id: String { topic }

    var displayName: String {
        topic.split(separator: "-").map { $0.capitalized }.joined(separator: " ")
    }

    enum CodingKeys: String, CodingKey {
        case topic, total, valid, invalid, matches
        case matchRate = "match_rate"
    }
}

// MARK: - Per-Topic JSON

struct TopicResults: Codable {
    let topic: String
    let evaluatedAt: String
    let totalResults: Int
    var problems: [ProblemMeta]
    let testResults: [TestResult]

    enum CodingKeys: String, CodingKey {
        case topic
        case evaluatedAt = "evaluated_at"
        case totalResults = "total_results"
        case problems
        case testResults = "test_results"
    }
}

struct ProblemMeta: Codable, Identifiable {
    let slug: String
    let topic: String
    let totalTests: Int
    let validTests: Int
    let invalidTests: Int
    var leetCodeNumber: Int = 0
    var difficulty: String = "medium"

    var id: String { slug }

    var displayName: String {
        slug.split(separator: "-").map { $0.capitalized }.joined(separator: " ")
    }

    var matchRate: Double {
        totalTests > 0 ? Double(validTests) / Double(totalTests) : 0
    }

    enum CodingKeys: String, CodingKey {
        case slug, topic
        case totalTests = "total_tests"
        case validTests = "valid_tests"
        case invalidTests = "invalid_tests"
    }
}

struct TestResult: Codable, Identifiable {
    let slug: String
    let topic: String
    let testId: String
    let input: String
    let originalExpected: String
    let computedOutput: String
    let isValid: Bool
    let outputMatches: Bool
    let orderMatters: Bool
    let errorMessage: String?
    let traceSteps: [TraceStep]?

    var id: String { testId }

    enum CodingKeys: String, CodingKey {
        case slug, topic
        case testId = "test_id"
        case input
        case originalExpected = "original_expected"
        case computedOutput = "computed_output"
        case isValid = "is_valid"
        case outputMatches = "output_matches"
        case orderMatters = "order_matters"
        case errorMessage = "error_message"
        case traceSteps = "trace_steps"
    }
}

// MARK: - Algorithm Trace Steps

struct TraceStep: Codable {
    let label: String
    let values: [String: TraceValue]

    enum CodingKeys: String, CodingKey {
        case label, values
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)

        // Decode each value in the dictionary via JourneyValueFactory,
        // producing TraceValue directly (no intermediate type).
        let rawContainer = try container.nestedContainer(
            keyedBy: DynamicCodingKey.self, forKey: .values
        )
        var decoded: [String: TraceValue] = [:]
        for key in rawContainer.allKeys {
            let valueDecoder = try rawContainer.superDecoder(forKey: key)
            decoded[key.stringValue] = try JourneyValueFactory.fromDecoder(valueDecoder)
        }
        values = decoded
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(label, forKey: .label)
        // Encode values as a pass-through JSON dictionary.
        // TraceValue doesn't need to be Encodable for read-only use;
        // skip encoding values since test results are read-only.
    }
}

/// Dynamic coding key for iterating arbitrary dictionary keys.
private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.intValue = intValue; self.stringValue = "\(intValue)" }
}
