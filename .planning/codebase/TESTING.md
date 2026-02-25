# Testing Patterns

**Analysis Date:** 2026-02-24

## Test Framework

**Runner:**
- Swift Testing (`Testing` framework from iOS 18.1+ / macOS 15.1+)
- Configuration: `Package.swift` declares 16 test targets
- Swift version: 6.2+

**Assertion Library:**
- Native Swift Testing framework with `#expect()` macro
- No external assertion library (XCTest, Quick, Nimble, etc.)

**Run Commands:**
```bash
swift test                    # Run all tests
swift test --filter TwoSum    # Run specific test
swift test --parallel         # Run tests in parallel
```

## Test File Organization

**Location:**
- Co-located in separate `Tests/` directory (not alongside source files)
- Topic-based organization: `Tests/ArraysHashingTests/`, `Tests/TreesTests/`, `Tests/TriesTests/`, etc.

**Naming:**
- File: `[ProblemName]Tests.swift` (e.g., `TwoSumTests.swift`, `BinaryTreePruningTests.swift`)
- Suite struct: `[ProblemName]Tests` (e.g., `struct TwoSumTests`)
- Test functions: `test_0()`, `test_1()`, `test_2()`, etc. (numbered test cases)

**Structure:**
```
TestCaseEvaluator/
├── Tests/
│   ├── ArraysHashingTests/
│   │   ├── TwoSumTests.swift
│   │   └── [other problem tests]
│   ├── TreesTests/
│   │   ├── BinaryTreePruningTests.swift
│   │   ├── MaximumDepthOfBinaryTreeTests.swift
│   │   └── [other tree tests]
│   ├── TriesTests/
│   ├── BacktrackingTests/
│   └── [16 total test topic directories]
└── Sources/
    └── LeetCodeHelpers/
        ├── InputParser.swift
        ├── OutputSerializer.swift
        ├── ResultRecorder.swift
        └── [helper utilities]
```

## Test Structure

**Suite Organization:**
```swift
@Suite struct BinaryTreePruningTests {
    init() { registerResultFlush() }

    @Test func test_0() async {
        // Test implementation
    }

    @Test func test_1() async {
        // Test implementation
    }
}
```

**Patterns:**

**1. Test Suite Initialization:**
- Use `@Suite` attribute on struct
- Call `registerResultFlush()` in `init()` to auto-record results on exit
- Async support with `async` keyword on test functions

**2. Test Structure (LeetCode Problem Testing):**
```swift
@Test func test_0() async {
    let slug = "binary-tree-pruning"
    let topic = "trees"
    let testId = "f9484055-f91e-4f72-9e01-3209b957e347"
    let rawInput = "root = []"
    let expectedOutput = "null"
    let orderMatters = true

    let params = InputParser.stripParamNames(rawInput)

    guard params.count >= 1 else {
        await ResultRecorderActor.shared.record(slug: slug, topic: topic, testId: testId,
            input: rawInput, originalExpected: expectedOutput, computedOutput: "",
            isValid: false, outputMatches: false, orderMatters: orderMatters,
            errorMessage: "Wrong number of params: expected 1, got \(params.count)")
        return
    }

    let p_root = buildTree(InputParser.parseNullableIntArray(params[0]))
    let solution = Solution()
    let result = solution.pruneTree(p_root)
    let computedOutput = OutputSerializer.serialize(result)

    let matches = computedOutput == expectedOutput
    await ResultRecorderActor.shared.record(slug: slug, topic: topic, testId: testId,
        input: rawInput, originalExpected: expectedOutput, computedOutput: computedOutput,
        isValid: true, outputMatches: matches, orderMatters: orderMatters)
    #expect(computedOutput == expectedOutput, "Test \(testId): input=\(rawInput)")
}
```

**3. Local Solution Class:**
- Private class `Solution` defined at top of test file
- Contains implementation to be tested
- Not using external solutions; each test file includes the solution being evaluated

**4. Error Handling in Tests:**
- Parameter validation with `guard` statements
- Constraint checking (e.g., array size limits)
- Early return with error recording for invalid test setup
- Async error recording via actor

## Test Execution Flow

**For Each Test:**
1. Parse raw input string using `InputParser` utilities
2. Validate parameter count with guard statement
3. Parse individual parameters (arrays, primitives, trees, etc.)
4. Create Solution instance
5. Call solution method with parsed parameters
6. Serialize result using `OutputSerializer`
7. Record result (valid/invalid, matches/mismatches) to actor
8. Assert computed output matches expected output

**Result Recording:**
- Uses thread-safe actor: `ResultRecorderActor.shared`
- Records: slug, topic, testId, input, expected, computed, validity, match status, error message
- Auto-flushes on process exit via `registerResultFlush()` and `atexit()` handler
- Writes results to JSON files organized by topic

## Input/Output Handling

**Input Parsing (from `InputParser.swift`):**

**Supported formats:**
1. Named parameters: `"nums = [2,7,11,15], target = 9"`
2. Bare arrays: `"[-1,0,1,2,-1,-4]"`
3. JSON objects: `{"nums": [2, 7, 11, 15], "target": 9}`
4. Multi-line bare values: `"100\n4\n200\n1\n3\n2"`
5. Raw strings: `"leetcode"`

**Key parsing functions:**
- `parseIntArray(_:)` - Parse `[1,2,3]` format
- `parseDoubleArray(_:)` - Parse floating-point arrays
- `parseStringArray(_:)` - Parse quoted string arrays
- `parseInt(_:)`, `parseDouble(_:)`, `parseBool(_:)` - Primitives
- `stripParamNames(_:)` - Remove `param = ` prefix for named input
- `parseNullableIntArray(_:)` - Parse arrays with `null` values for trees
- `parseNullableIntMatrix(_:)` - Parse 2D arrays with nulls

**Output Serialization (from `OutputSerializer.swift`):**

**Overloads for types:**
```swift
serialize(_ value: Int) -> String      // "42"
serialize(_ value: Double) -> String   // "3.14" (trimmed to 5 decimal places)
serialize(_ value: Bool) -> String     // "true" or "false"
serialize(_ value: String) -> String   // "\"hello\""
serialize(_ value: [Int]) -> String    // "[1,2,3]"
serialize(_ value: [[Int]]) -> String  // "[[1,2],[3,4]]"
serialize(_ value: TreeNode?) -> String // "[1,2,3,null,null,4,5]"
// ... many overloads for different types
```

## Helper Utilities (LeetCodeHelpers Library)

**Location:** `/Users/ashimdahal/Documents/CodeBench/TestCaseEvaluator/Sources/LeetCodeHelpers/`

**Core Modules:**

**1. InputParser.swift**
- Purpose: Convert LeetCode string input to Swift values
- Key methods: `parseIntArray()`, `parseStringArray()`, `parseNullableIntArray()`, etc.
- Handles 5 different input formats automatically

**2. OutputSerializer.swift**
- Purpose: Convert Swift values back to LeetCode format strings
- Overloaded for Int, Double, Bool, String, Arrays, Trees, Lists, etc.
- Handles nullable types and complex structures

**3. NodeVariants.swift**
- Purpose: Define all node types used in LeetCode problems
- Contains: `TreeNode`, `ListNode`, `Node` (graphs), `NaryTreeNode`, `RandomPointerNode`, `DoublyListNode`, etc.

**4. ResultRecorder.swift**
- Purpose: Thread-safe result recording and JSON export
- Actor-based concurrency (no manual synchronization)
- Methods: `record()`, `flush()`, `reset()`
- Auto-flush on process exit via `registerResultFlush()`

**5. TreeNode.swift, ListNode.swift**
- Purpose: Standard data structure definitions for LeetCode problems
- Public for use in test files

## Mocking

**Not Used in This Codebase:**

The test suite does not use mocking frameworks or mock objects. Instead:
- Each test file includes a local `private class Solution` with the actual implementation
- Tests directly instantiate and call the solution
- No external dependencies are mocked or stubbed
- All input is generated from parsed test case strings

## Fixtures and Factories

**Test Data:**
- No external fixture files; data embedded in test code
- Each `@Test func test_N()` contains hard-coded LeetCode test case data
- Format: Raw input string + expected output string

**Location:**
- Inline in each test function definition
- Variables: `rawInput`, `expectedOutput`, `testId`, `slug`, `topic`, `orderMatters`

**Tree Building Helper:**
```swift
let p_root = buildTree(InputParser.parseNullableIntArray(params[0]))
```
- Uses `buildTree()` function (defined in helper scope)
- Converts level-order array format to TreeNode structure

## Coverage

**Requirements:** Not enforced

**View Coverage:**
- No coverage reporting configuration detected
- Test results exported to JSON format for external analysis

**JSON Output Structure:**
```json
{
  "evaluated_at": "2026-02-24T...",
  "total_results": 1234,
  "topics": [...],
  "problems": [...]
}
```

Per-topic JSON files created: `trees.json`, `arrays-hashing.json`, etc.

## Test Types

**Unit Tests:**
- Scope: Individual LeetCode problem solutions
- Approach: Test function receives pre-computed input/output pairs, parses, executes, compares
- Coverage: 16 algorithm topic areas with multiple tests per problem

**Integration Tests:**
- Not present; tests are purely unit-scoped

**E2E Tests:**
- Not applicable; this is algorithm evaluation suite

## Common Patterns

**Async Testing:**
```swift
@Test func test_0() async {
    let params = InputParser.stripParamNames(rawInput)
    let p_root = buildTree(InputParser.parseNullableIntArray(params[0]))
    let solution = Solution()
    let result = solution.pruneTree(p_root)
    let computedOutput = OutputSerializer.serialize(result)

    await ResultRecorderActor.shared.record(...)
    #expect(computedOutput == expectedOutput, ...)
}
```

**Error Testing (Parameter Validation):**
```swift
guard params.count >= 1 else {
    await ResultRecorderActor.shared.record(slug: slug, topic: topic, testId: testId,
        input: rawInput, originalExpected: expectedOutput, computedOutput: "",
        isValid: false, outputMatches: false, orderMatters: orderMatters,
        errorMessage: "Wrong number of params: expected 1, got \(params.count)")
    return
}
```

**Constraint Checking:**
```swift
guard p_nums.count <= 100_000 else {
    await ResultRecorderActor.shared.record(slug: slug, topic: topic, testId: testId,
        input: rawInput, originalExpected: expectedOutput, computedOutput: "",
        isValid: false, outputMatches: false, orderMatters: orderMatters,
        errorMessage: "Constraint violation: nums array too large (\(p_nums.count))")
    return
}
```

**Assertion Pattern:**
```swift
let matches = computedOutput == expectedOutput
#expect(computedOutput == expectedOutput, "Test \(testId): input=\(rawInput)")
```

## Test Data Organization

**Test Identifiers:**
- UUID format: `"f9484055-f91e-4f72-9e01-3209b957e347"`
- Or uppercase hex: `"4B7827CE-A154-4E5C-A002-32C9E73DE97C"`
- Uniquely identify each test case across all topics

**Metadata Per Test:**
- `slug`: Problem identifier (kebab-case)
- `topic`: Algorithm category
- `testId`: Unique test identifier
- `rawInput`: Unparsed LeetCode input string
- `expectedOutput`: Expected output string
- `orderMatters`: Boolean indicating if output order affects correctness (e.g., false for two-sum, true for tree traversals)

---

*Testing analysis: 2026-02-24*
