# External Integrations

**Analysis Date:** 2026-02-24

## APIs & External Services

**LeetCode:**
- Source of algorithm problems, test cases, and solution code
- Integration method: Offline - data pre-downloaded as JSON files
- No active API calls; data embedded in repository

## Data Storage

**Databases:**
- None detected - no persistent database backend
- SQLite: Not used
- Core Data: Not used
- Realm: Not used

**File Storage:**
- Local filesystem only
  - iOS app loads test results from:
    - Bundled resources (JSON files via `Bundle.module` or `Bundle.main`)
    - User-selected directories via file picker (security-scoped URLs)
  - Test suite writes results to local JSON files
  - No cloud storage integration

**Caching:**
- In-memory caching via Swift Observable state
  - `ResultsLoader` class caches parsed results in memory
  - Location: `CodeBench/CodeBench/Services/ResultsLoader.swift`

## Authentication & Identity

**Auth Provider:**
- None - application is fully offline
- No user authentication required
- No API keys or tokens needed

## Monitoring & Observability

**Error Tracking:**
- None detected - no error reporting service

**Logs:**
- Local JSON result files serve as audit trail
- Each test execution records:
  - Input parameters
  - Expected vs. computed output
  - Pass/fail status
  - Error messages (if validation fails)
- Location: `test_results.json` or per-topic JSON files

**Structured Logging:**
- Test results recorded via `ResultRecorderActor` (Swift actor for thread safety)
- Location: `TestCaseEvaluator/Sources/LeetCodeHelpers/ResultRecorder.swift`

## CI/CD & Deployment

**Hosting:**
- iOS devices/simulators (app deployment)
- Local macOS for test suite execution

**CI Pipeline:**
- None detected - no GitHub Actions, Travis CI, or similar
- Manual build/test via:
  - Xcode IDE
  - `swift build` command
  - `swift test` command

## Environment Configuration

**Required env vars:**
- None detected - application is fully self-contained

**Secrets location:**
- No secrets management system - application has no external dependencies requiring credentials

## Data Files & Resources

**Bundled JSON Data:**
- `tc-*.json` files (17 topic-specific test case files)
  - Format: Problem slugs → test cases with input/output
  - Example files:
    - `tc-arrays-hashing.json`
    - `tc-trees.json`
    - `tc-dynamic-programming.json`
  - Location: Repository root `/Users/ashimdahal/Documents/CodeBench/`

**Solution Files:**
- `Solutions/` directory - JSON files organized by topic
  - Format: Problem slug → solution code with multiple approaches
  - Example: `Solutions/arrays-hashing.json`

**Results Output:**
- `summary.json` - Aggregate test results across all topics
- Topic-specific JSON files (e.g., `arrays-hashing.json`)
  - Structure includes problem metadata and individual test results
  - Generated during test execution by `ResultRecorderActor`

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

## Data Flow

**Test Execution Flow:**
1. Python scripts (`Scripts/generate_tests.py`) read `tc-*.json` and `Solutions/` files
2. Generate Swift test files in `Tests/` directories
3. Swift test runner executes tests via `swift test`
4. `ResultRecorderActor` (actor for thread-safe concurrency) records results
5. Results written to JSON files in `test_results/` directory
6. Python script (`Scripts/export_results.py`) reads JSON results and updates `tc-*.json` files

**App Data Loading:**
1. iOS app (`CodeBenchApp`) initializes `ResultsLoader` observable
2. Loader reads `summary.json` from bundle or user-selected directory
3. Loads topic-specific JSON files on demand
4. Displays results in UI via `SolutionView`

## Integration Points in Codebase

**Main App Entry:**
- `CodeBench/CodeBench/CodeBenchApp.swift` - App initialization with `ResultsLoader`

**Data Loading Service:**
- `CodeBench/CodeBench/Services/ResultsLoader.swift`
  - Handles bundle resource loading and user directory access
  - Uses FileManager for security-scoped URL access

**Models for JSON Decoding:**
- `CodeBench/CodeBench/Models/TestResultsModel.swift`
  - Defines all Codable structures matching JSON schema

**Test Recording:**
- `TestCaseEvaluator/Sources/LeetCodeHelpers/ResultRecorder.swift`
  - Thread-safe actor for accumulating test results
  - Exports final results as JSON

**Input/Output Serialization:**
- `TestCaseEvaluator/Sources/LeetCodeHelpers/InputParser.swift` - Parses JSON test input to Swift types
- `TestCaseEvaluator/Sources/LeetCodeHelpers/OutputSerializer.swift` - Serializes Swift results to JSON format

## Notable Absence of Integrations

- No backend API server
- No database (SQLite, PostgreSQL, etc.)
- No cloud services (AWS, Azure, GCP)
- No real-time sync or collaboration
- No push notifications
- No social/sharing features
- No analytics or telemetry

This is a fully offline, self-contained system focused on local algorithm problem solving and testing.

---

*Integration audit: 2026-02-24*
