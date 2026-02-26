import Foundation
import TestResultsBundle

@Observable
final class ResultsLoader {
    var summary: TestSummary?
    var topicResults: [String: TopicResults] = [:]
    var isLoaded = false
    var errorMessage: String?

    /// The bundle containing test result JSON files from TestCaseEvaluator.
    private var resourceBundle: Bundle {
        TestResultsBundle.bundle
    }

    /// Problem metadata (leetCodeNumber, difficulty) loaded from problem-metadata.json
    private(set) var problemMetadata: [String: ProblemMetadataEntry] = [:]

    struct ProblemMetadataEntry: Codable {
        let n: Int
        let d: String
    }

    /// Load from bundled sample data (precomputed test results)
    func loadFromBundle() {
        guard let summaryURL = resourceBundle.url(forResource: "summary", withExtension: "json") else {
            errorMessage = "No bundled results found. Use 'Load from Files' to select a test_results directory."
            return
        }

        do {
            // Load metadata from the app bundle (CodeBench-specific, not in TestResultsBundle)
            if let metaURL = Bundle.main.url(forResource: "problem-metadata", withExtension: "json") {
                let metaData = try Data(contentsOf: metaURL)
                problemMetadata = try JSONDecoder().decode([String: ProblemMetadataEntry].self, from: metaData)
            }

            let summaryData = try Data(contentsOf: summaryURL)
            summary = try JSONDecoder().decode(TestSummary.self, from: summaryData)

            // Enrich summary problems with metadata
            if var s = summary {
                s.problems = s.problems.map { enrichProblem($0) }
                summary = s
            }

            // Load each topic file
            for topicSummary in summary?.topics ?? [] {
                let topicName = topicSummary.topic
                if let topicURL = resourceBundle.url(forResource: topicName, withExtension: "json") {
                    let topicData = try Data(contentsOf: topicURL)
                    var results = try JSONDecoder().decode(TopicResults.self, from: topicData)
                    results.problems = results.problems.map { enrichProblem($0) }
                    topicResults[topicName] = results
                }
            }
            isLoaded = true
        } catch {
            errorMessage = "Failed to load bundled results: \(error.localizedDescription)"
        }
    }

    private func enrichProblem(_ problem: ProblemMeta) -> ProblemMeta {
        var p = problem
        if let meta = problemMetadata[problem.slug] {
            p.leetCodeNumber = meta.n
            p.difficulty = meta.d
        }
        return p
    }

    /// Load from a user-selected directory (live test results)
    func loadFromDirectory(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let summaryURL = url.appendingPathComponent("summary.json")
        guard FileManager.default.fileExists(atPath: summaryURL.path) else {
            errorMessage = "No summary.json found in selected directory."
            return
        }

        do {
            let summaryData = try Data(contentsOf: summaryURL)
            summary = try JSONDecoder().decode(TestSummary.self, from: summaryData)

            topicResults.removeAll()
            for topicSummary in summary?.topics ?? [] {
                let topicName = topicSummary.topic
                let topicURL = url.appendingPathComponent("\(topicName).json")
                if FileManager.default.fileExists(atPath: topicURL.path) {
                    let topicData = try Data(contentsOf: topicURL)
                    let results = try JSONDecoder().decode(TopicResults.self, from: topicData)
                    topicResults[topicName] = results
                }
            }
            isLoaded = true
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load results: \(error.localizedDescription)"
        }
    }

    /// Get test results for a specific problem
    func resultsForProblem(_ slug: String, topic: String) -> [TestResult] {
        topicResults[topic]?.testResults.filter { $0.slug == slug } ?? []
    }
}
