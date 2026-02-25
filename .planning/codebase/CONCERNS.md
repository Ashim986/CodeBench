# Codebase Concerns

**Analysis Date:** 2026-02-24

## Tech Debt

### Large View Files with Multiple Responsibilities

**Issue:** Multiple view files have crossed the 300+ line threshold, combining layout, state management, and business logic in single files.

**Files:**
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyStructureCanvasView.swift` (487 lines)
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyTreeGraphView.swift` (456 lines)
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyGraphView.swift` (382 lines)
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyStructureCanvasView+Pointers.swift` (380 lines)
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyView+Playback.swift` (365 lines)

**Impact:**
- Difficult to test individual layout concerns
- High complexity in view hierarchy makes refactoring risky
- Rendering performance may degrade with complex data structures
- State management across multiple extensions is error-prone

**Fix approach:**
- Extract reusable view components into standalone files (e.g., `TreeNodeView`, `GraphEdgeView`)
- Create separate view models for layout calculation and pointer positioning
- Split extension files by feature concern (layout, rendering, interaction)
- Introduce view builders for conditional rendering chains

### Minimal Error Handling in Data Loading Pipeline

**Issue:** `ResultsLoader.swift` uses silent failures with generic error messages. No retry logic, no detailed error context, and `try?` patterns suppress actual errors.

**Files:** `CodeBench/CodeBench/Services/ResultsLoader.swift`

**Current pattern:**
```swift
guard let summaryURL = resourceBundle.url(forResource: "summary", withExtension: "json") else {
    errorMessage = "No bundled results found. Use 'Load from Files' to select a test_results directory."
    return
}
// ...
} catch {
    errorMessage = "Failed to load bundled results: \(error.localizedDescription)"
}
```

**Impact:**
- Users cannot distinguish between file-not-found, permission errors, or corruption
- No logging for debugging failed loads
- Silent `try?` in line 75 masks underlying file system errors

**Fix approach:**
- Create typed `LoadError` enum with specific cases (fileNotFound, permissionDenied, corruptedJSON, etc.)
- Add detailed logging to `ResultsLoader` for troubleshooting
- Implement retry logic with exponential backoff for transient failures
- Provide structured error descriptions in UI

### Unsafe Casting in Event Parsing

**Issue:** `DataJourneyEvent.from(json:)` uses unsafe type casting with fallbacks that hide data integrity issues.

**Files:** `CodeBench/CodeBench/DataJourney/Models/DataJourneyModels.swift` (lines 18-36)

**Current pattern:**
```swift
let line: Int? = if let lineValue = dict["line"] as? Int {
    lineValue
} else if let lineNumber = dict["line"] as? NSNumber {
    lineNumber.intValue
} else {
    nil
}
```

**Impact:**
- Silently drops malformed event data
- No validation of required fields (e.g., `kind` must be valid)
- Incorrect event parsing propagates silently through visualization

**Fix approach:**
- Use `Decodable` protocol instead of manual JSON parsing
- Validate all required fields during initialization
- Log warnings for dropped events
- Provide validation errors with event indices for debugging

### Async Actor Usage Without Comprehensive Error Handling

**Issue:** `ResultRecorderActor` uses `try?` to suppress file I/O errors silently.

**Files:** `TestCaseEvaluator/Sources/LeetCodeHelpers/ResultRecorder.swift` (lines 109-114, 137-143)

**Current pattern:**
```swift
do {
    let data = try JSONSerialization.data(withJSONObject: topicOutput, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: URL(fileURLWithPath: topicPath))
} catch {
    print("[ResultRecorder] ERROR writing \(topicPath): \(error)")
}
```

**Impact:**
- Test results may be lost silently if disk is full or permissions change
- No fallback mechanism or cleanup on write failure
- Console logging is not suitable for production debugging

**Fix approach:**
- Create custom error type for result recording failures
- Implement result buffering in memory if disk writes fail
- Add completion handlers to signal success/failure to callers
- Consider writing to temporary file first, then atomic move

## Known Bugs

### Playback Control State Inconsistency

**Issue:** Multiple playback state properties can become out of sync.

**Files:** `CodeBench/CodeBench/DataJourney/Views/DataJourneyView+Playback.swift`

**Potential issue:**
The extension contains multiple state management functions (`stepControls`, `stepControlsHeader`, `stepControlsTimeline`) that recalculate similar parameters. The `ensurePlaybackSelection()` function may not be called consistently on all events.

**Trigger:**
When events are updated mid-playback or user quickly changes selection while animation is playing.

**Workaround:**
Pause playback and manually restart.

### Pointer Motion Calculation May Exceed Bounds

**Issue:** Graph and tree pointer positioning may fail for complex data structures.

**Files:**
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyGraphView.swift`
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyTreeGraphView.swift`

**Problem:**
Pointer positioning uses hardcoded multipliers for spacing. With many pointers or deeply nested structures, positioning calculations may produce negative coordinates or off-screen placement.

**Symptom:**
Pointers disappear or overlap incorrectly when tracing large graphs or pointer-dense algorithms.

**Fix approach:**
- Add bounds checking to pointer positioning calculations
- Implement adaptive spacing that scales with pointer count
- Add debug visualization to show pointer bounds

### Truncation Message Not Aligned with Actual Event Count

**Issue:** `DataJourneyInteractor.processTraceEvents()` truncates at `maxSteps` but UI may display incorrect counts.

**Files:**
- `CodeBench/CodeBench/DataJourney/Services/DataJourneyInteractor.swift`
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyView+Playback.swift` (line 74)

**Current display:**
```swift
Text("Step \(currentPlaybackIndex + 1) of \(playbackEvents.count)")
```

**Impact:**
User sees different step counts between `truncationMessage` and actual playback range, causing confusion.

## Security Considerations

### File System Access Without Sandbox Restrictions

**Issue:** `ResultsLoader.loadFromDirectory()` uses security-scoped resource access but does not validate directory contents before parsing.

**Files:** `CodeBench/CodeBench/Services/ResultsLoader.swift` (lines 47-76)

**Risk:**
Malicious JSON files in a compromised test_results directory could cause crashes or memory exhaustion through:
- Extremely large arrays in trace data
- Deeply nested JSON structures
- Invalid UTF-8 in string values

**Current mitigation:**
JSONDecoder default limits are applied, but no custom limits.

**Recommendations:**
- Implement streaming JSON parsing for large files
- Add file size limits before attempting to load
- Validate JSON structure before full deserialization
- Sanitize file paths to prevent directory traversal

### No Rate Limiting on Result Recording

**Issue:** `ResultRecorderActor.record()` has no bounds on the number of recorded results.

**Files:** `TestCaseEvaluator/Sources/LeetCodeHelpers/ResultRecorder.swift`

**Risk:**
Memory exhaustion if test suite runs millions of test cases without flushing results.

**Recommendations:**
- Implement automatic flush at result count threshold (e.g., 10,000 results)
- Add memory usage monitoring
- Provide warning logs when approaching limits

### InputParser Silent Defaults

**Issue:** Parse functions return default values (0, false, empty string) on malformed input rather than reporting errors.

**Files:** `TestCaseEvaluator/Sources/LeetCodeHelpers/InputParser.swift`

**Examples:**
```swift
public static func parseInt(_ s: String) -> Int {
    Int(s.trimmingCharacters(in: .whitespaces)) ?? 0  // Silent default to 0
}

public static func parseStringArray(_ s: String) -> [String] {
    // ... returns empty array on malformed input
}
```

**Risk:**
Test results incorrectly marked as passing when input parsing fails. The algorithm may be correct but operating on wrong data.

**Recommendations:**
- Return `Result<T, ParseError>` instead of optionals
- Log parsing failures with context (parameter name, attempted value)
- Fail test explicitly on parse error rather than silently substituting defaults

## Performance Bottlenecks

### JSON Data Files Loaded Entirely into Memory

**Issue:** Test result files (857 KB to 809 KB each) are loaded fully into memory for parsing.

**Files:**
- `/Users/ashimdahal/Documents/CodeBench/Solutions.json` (857 KB)
- `/Users/ashimdahal/Documents/CodeBench/tc-neetcode-150.json` (809 KB)
- `/Users/ashimdahal/Documents/CodeBench/tc-math-geometry.json` (550 KB)

**Current approach:** `Data(contentsOf:)` followed by `JSONDecoder().decode()`

**Impact:**
- Slow initial load with large result sets
- High memory footprint on memory-constrained devices
- UI becomes unresponsive during parsing

**Improvement path:**
- Implement lazy JSON streaming decoder
- Load test results incrementally, grouped by topic
- Cache parsed results with weak references for garbage collection
- Show progress indicator during large file parsing

### Canvas-Based Graph/Tree Rendering May Stall on Large Structures

**Issue:** `GraphView` and `TreeGraphView` use `Canvas` to draw edges for every connection, which scales poorly.

**Files:**
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyGraphView.swift` (edge drawing loop)
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyTreeGraphView.swift` (tree layout + edge drawing)

**Problem:**
A graph with 100+ nodes results in 1000+ edge calculations and Canvas draw calls. No culling or LOD (level-of-detail) rendering.

**Symptom:**
Scrolling and interaction lag when visualizing large data structures.

**Improvement path:**
- Implement viewport culling to skip off-screen edges
- Add level-of-detail rendering (simplify edges when zoomed out)
- Consider using Metal rendering for complex graphs instead of Canvas
- Cache layout calculations between renders

### Multiple Layout Recalculations During State Updates

**Issue:** `TraceTreeLayout` and `GraphLayout` are recreated on every view render.

**Files:**
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyTreeGraphView.swift` (line ~45)
- `CodeBench/CodeBench/DataJourney/Views/DataJourneyGraphView.swift` (line ~40)

**Current pattern:**
```swift
let layout = TraceTreeLayout(tree: tree, nodeSize: nodeSize, levelSpacing: levelSpacing)
```

**Impact:**
Layout calculations (O(n) or O(n log n)) run on every trivial state change (color, selection), not just when data changes.

**Fix approach:**
- Memoize layout calculations using `@Memo` or custom caching
- Track layout dependencies explicitly (tree structure, node count only)
- Separate layout computation from rendering

## Fragile Areas

### StructureResolver Pattern Matching Fragility

**Issue:** `StructureResolver.swift` and `StructureResolver+Handlers.swift` rely on name-based heuristics for type detection.

**Files:** `CodeBench/CodeBench/DataJourney/Services/StructureResolver.swift` (296 lines)

**Examples of fragility:**
- Heap detection checks variable names containing "heap" (line 60)
- Stack detection checks names containing "stack" (line 68)
- Min-heap vs max-heap determined by name substring matching

**Why fragile:**
- User-named variables that happen to contain keywords trigger incorrect rendering
- No type annotations from trace data itself to disambiguate
- Refactoring algorithm variable names breaks visualization

**Safe modification:**
- Add explicit type annotation system to trace events (e.g., `"type": "min-heap"`)
- Fall back to heuristics only when type is unknown
- Document naming conventions required for correct visualization

**Test coverage:**
- No unit tests for StructureResolver name matching logic
- High risk of regression if new data structure patterns are added

### DataJourneyEvent Deserialization Without Validation

**Issue:** Event parsing accepts any JSON structure and silently drops invalid fields.

**Files:** `CodeBench/CodeBench/DataJourney/Models/DataJourneyModels.swift`

**Fragility:**
- Missing `kind` field silently returns nil (line 21)
- Invalid `kind` value silently discarded without logging
- Events with no `values` silently use empty dict (line 32)

**Risk:**
Silently dropping events leads to visualization gaps. Users won't know some steps are missing.

**Safe modification:**
- Add validation during deserialization
- Log warnings for each rejected event with diagnostic info (JSON snippet, reason)
- Provide a validation report function for debugging

### Bundle Resource Lookup Fallback

**Issue:** `ResultsLoader` falls back from `Bundle.module` to `Bundle.main` with no validation.

**Files:** `CodeBench/CodeBench/Services/ResultsLoader.swift` (lines 12-18)

**Current pattern:**
```swift
private var resourceBundle: Bundle {
    #if SWIFT_PACKAGE
    Bundle.module
    #else
    Bundle.main
    #endif
}
```

**Fragility:**
- When running as app, may accidentally load resources from wrong location
- No warning if resources are missing from both bundles
- Silent failure to load leaves `isLoaded = false` without clear error

**Safe modification:**
- Assert that chosen bundle contains required resources
- Log which bundle is being used
- Provide explicit error if resources are missing from both locations

## Scaling Limits

### Maximum Step Count Hard-Coded

**Issue:** `DataJourneyInteractor` has hard-coded `maxSteps = 40` with no configurability.

**Files:** `CodeBench/CodeBench/DataJourney/Services/DataJourneyInteractor.swift` (line 27)

**Current capacity:**
- Max 40 steps visualized
- Silently truncates beyond 40

**Limit:**
Algorithms with many iterations (e.g., O(n) loops with n=100) cannot be fully visualized.

**Scaling path:**
- Make `maxSteps` configurable per problem
- Implement adaptive sampling for long traces (show every Nth step)
- Add UI control to adjust step display density

### Result Data Structure in Memory

**Issue:** All test results for a topic loaded as single `TopicResults` struct in memory.

**Files:** `CodeBench/CodeBench/Services/ResultsLoader.swift`

**Current capacity:**
- ~1000 test results per topic before noticeable lag
- ~5 topics × 1000 results = ~5 MB JSON in memory

**Limit:**
With 150+ problems × 10+ test cases per problem, memory usage becomes problematic on iOS.

**Scaling path:**
- Implement paged loading (load 50 results at a time)
- Add indexing to search results without full deserialization
- Consider database storage instead of JSON files

## Dependencies at Risk

### InputParser and OutputSerializer Duplicated Logic

**Issue:** Multiple parsers and serializers handle the same data types with slight variations.

**Files:**
- `TestCaseEvaluator/Sources/LeetCodeHelpers/InputParser.swift` (100+ lines of parsing logic)
- `TestCaseEvaluator/Sources/LeetCodeHelpers/OutputSerializer.swift` (97 lines of serialization logic)
- Manual parsing in `DataJourneyEvent.from(json:)` and other model types

**Risk:**
Inconsistencies between parsers lead to round-trip failures. Parser A produces string, Parser B expects different format, serialization fails.

**Migration plan:**
- Unify all parsing under single `TraceValueParser` enum with tests
- Create `TraceValueCodeable` protocol for consistent encoding/decoding
- Use `Codable` for all model types instead of manual JSON handling

### Console Logging Not Suitable for Production

**Issue:** `ResultRecorderActor` and other components use `print()` for error logging.

**Files:** `TestCaseEvaluator/Sources/LeetCodeHelpers/ResultRecorder.swift` (lines 113, 140, 142)

**Risk:**
- Console output not captured in production
- No log levels or filtering
- Cannot distinguish between info and error

**Migration plan:**
- Introduce logging protocol (e.g., `Logger`)
- Redirect logs to appropriate sinks (console in dev, file in prod)
- Add structured logging with context (problem slug, test count, etc.)

## Missing Critical Features

### No Input Validation Before Serialization

**Issue:** `OutputSerializer` assumes inputs are valid and formats them without validation.

**Files:** `TestCaseEvaluator/Sources/LeetCodeHelpers/OutputSerializer.swift`

**Example:**
```swift
public static func serialize(_ value: [Int]) -> String {
    "[" + value.map { "\($0)" }.joined(separator: ",") + "]"
}
```

**Problem:**
If array is malformed or contains unexpected values, serialization produces incorrect output but does not report error.

**Blocks:**
- Cannot guarantee correct test result reporting
- No way to detect algorithmic output corruption

**Recommendation:**
- Add optional validation step that logs warnings
- Provide `validateAndSerialize` variant that returns Result type
- Log invalid values before serialization

### No Mechanism for Partial Result Recovery

**Issue:** If test suite crashes mid-run, all unsaved results are lost.

**Files:** `TestCaseEvaluator/Sources/LeetCodeHelpers/ResultRecorder.swift`

**Current approach:**
- Results buffered in memory until explicit flush
- atexit handler flushes on process exit
- If process crashes, unsaved results lost

**Blocks:**
- Long-running test suites cannot resume
- No way to incrementally save progress

**Recommendation:**
- Implement checkpoint-based saving (flush results every N problems)
- Provide resume capability to skip completed problems
- Add result file locking to prevent duplicate test runs

## Test Coverage Gaps

### No Unit Tests for Structure Resolution Logic

**Issue:** `StructureResolver.swift` and `StructureResolver+Handlers.swift` have no dedicated unit tests.

**Files:** `CodeBench/CodeBench/DataJourney/Services/StructureResolver.swift` (296 lines)

**What's not tested:**
- Name-based type detection heuristics
- Fallback logic when multiple structures are possible
- Edge cases (empty arrays, null values, mixed types)
- Interaction between handlers (which takes precedence)

**Files:**
- No test target for `DataJourneyServices`
- Cannot verify detection accuracy for new data types

**Risk:**
High risk of regression when adding support for new data structures. Changes to heuristics may silently break existing visualizations.

**Priority:** High

**Recommendation:**
- Create `DataJourneyServicesTests` test target
- Add comprehensive tests for each handler (TreeHandler, GraphHandler, etc.)
- Test heuristic matching with name variations
- Add snapshot tests for expected structure outputs

### No Integration Tests for Data Loading Pipeline

**Issue:** End-to-end data loading (file → JSON → model → UI) has no test coverage.

**Files:**
- `CodeBench/CodeBench/Services/ResultsLoader.swift`
- `CodeBench/CodeBench/Models/TestResultsModel.swift`

**Untested:**
- Loading corrupted JSON files
- Missing required fields in test results
- Large file loading performance
- Memory cleanup after loading

**Risk:**
UI may crash on certain file formats or corrupted data that was never tested.

**Priority:** Medium

**Recommendation:**
- Create fixture JSON files for different test scenarios
- Test error handling paths (file not found, parse error, corrupt data)
- Add performance benchmarks for large file loading

### No Tests for Event Parsing and Model Construction

**Issue:** `DataJourneyEvent.from(json:)` and trace value parsing have no unit tests.

**Files:**
- `CodeBench/CodeBench/DataJourney/Models/DataJourneyModels.swift`
- Event parsing in `TestResultBridge.swift`

**Untested:**
- Invalid event JSON structure
- Missing or malformed trace values
- Type mismatches in event data

**Risk:**
Invalid events silently drop, leading to incomplete visualizations without clear error messages.

**Priority:** Medium

**Recommendation:**
- Add unit tests for event deserialization
- Test each `TraceValue` variant creation
- Add property-based tests for JSON parsing robustness

---

*Concerns audit: 2026-02-24*
