# Coding Conventions

**Analysis Date:** 2026-02-24

## Naming Patterns

**Files:**
- Swift: PascalCase for all files, matching the primary type/class name within (e.g., `ResultsLoader.swift`, `InputParser.swift`, `BinaryTreePruningTests.swift`)
- Test files: Suffix with `Tests` (e.g., `TwoSumTests.swift`, `MaximumDepthOfBinaryTreeTests.swift`)
- Use descriptive names that indicate purpose: `TopicBrowseView.swift` for browsing views, `OutputSerializer.swift` for serialization

**Functions:**
- lowerCamelCase for all function names
- Descriptive names indicating action or return value (e.g., `parseIntArray()`, `serialize()`, `rateColor()`, `loadFromBundle()`)
- Private functions use `private func` prefix
- Async functions use `async` keyword and typically suffixed with action name (e.g., `record()`, `registerResultFlush()`)

**Variables:**
- lowerCamelCase for local variables and properties (e.g., `isLoaded`, `errorMessage`, `resourceBundle`, `topicResults`)
- Private properties use `private var` prefix
- Use descriptive names: `matchRate` not `rate`, `computedOutput` not `output`
- Underscore prefix for internal state: `_flushRegistered`

**Types:**
- PascalCase for all types (structs, classes, enums)
- Enum cases: lowerCamelCase (e.g., `case input`, `case output`, `case step`)
- Protocol names: PascalCase with descriptive purpose (e.g., `Identifiable`, `Codable`, `Sendable`)
- Type aliases: PascalCase (e.g., `typealias `)

## Code Style

**Formatting:**
- No explicit formatter configuration detected (no .swiftformat or .swiftlint files)
- Follow Apple's standard Swift formatting conventions
- Indentation: 4 spaces (implicit from code examples)
- Line length: No strict limit observed, but stay reasonable (80-100 characters for readability)
- Brace style: Opening braces on same line (K&R style)

**Linting:**
- No linter configuration detected in codebase
- Swift compiler warnings should be treated as guide

## Import Organization

**Order:**
1. Foundation (standard library)
2. Specialized imports (Testing, SwiftUI)
3. Internal module imports (@testable import)

**Example from `BinaryTreePruningTests.swift`:**
```swift
import Foundation
import Testing
@testable import LeetCodeHelpers
```

**Path Aliases:**
- Bundle.module used in SPM targets
- Bundle.main used in Xcode projects
- Conditional compilation: `#if SWIFT_PACKAGE` / `#else` pattern (see `ResultsLoader.swift`)

## Error Handling

**Patterns:**
- Use `guard` statements for early returns with parameter validation (see `ResultsLoader.swift:loadFromBundle()`)
- Check constraints before processing: validate array size limits, parameter counts
- Use `do-catch` blocks for file I/O and JSONDecoder operations
- Record error states in model properties: `errorMessage: String?` pattern
- Supply user-facing error messages via localization or direct strings
- Log errors to console for debugging: `print("[ResultRecorder] ERROR writing...")`

**Example from test files:**
```swift
guard params.count >= 2 else {
    await ResultRecorderActor.shared.record(slug: slug, topic: topic, testId: testId,
        input: rawInput, originalExpected: expectedOutput, computedOutput: "",
        isValid: false, outputMatches: false, orderMatters: orderMatters,
        errorMessage: "Wrong number of params: expected 2, got \(params.count)")
    return
}
```

## Logging

**Framework:** Native `print()` function with prefixed context tags

**Patterns:**
- Use tagged prefixes for context: `print("[ResultRecorder] Wrote...")`
- Log to console only (no external logging framework)
- Include operation name and result count: `print("[ResultRecorder] Wrote \(results.count) results to \(outputDir)/ (\(resultsByTopic.count) topics)")`
- Log errors with full error description: `print("[ResultRecorder] ERROR writing \(topicPath): \(error)")`
- No logging in UI code or views

## Comments

**When to Comment:**
- Add comments for complex algorithms or non-obvious logic
- Clarify intent when naming alone is insufficient
- Use inline comments sparingly; prefer clear variable names

**Documentation Comments (///):**
- Required for public API in library code (`LeetCodeHelpers` target)
- Include description of purpose and behavior
- Describe parameters and return values for public functions
- Include examples for complex utilities

**Example from `InputParser.swift`:**
```swift
/// Parses LeetCode-style input strings into Swift values.
/// Handles all 5 input formats:
///   1. Named params: "nums = [2,7,11,15], target = 9"
///   2. Bare values: "[-1,0,1,2,-1,-4]"
///   3. JSON objects: {"nums": [2, 7, 11, 15], "target": 9}
///   4. Multi-line bare values: "100\n4\n200\n1\n3\n2"
///   5. Raw strings: "leetcode"
public enum InputParser {
```

**MARK Comments:**
- Use `// MARK: -` to separate sections in longer files
- Use `// MARK:` for subsection headers
- Examples: `// MARK: - Primitives`, `// MARK: - Optional`, `// MARK: - Auto-flush registration`
- Group related functions together with MARK separators

**Example section markers:**
```swift
// MARK: - Parse integer from string
public static func parseInt(_ s: String) -> Int {
```

## Function Design

**Size:**
- Keep functions small and focused (most test functions are 20-30 lines)
- Extract helper functions for repeated patterns (see `topicRow()` as private helper)
- Private helper functions for calculations: `rateColor()` as private method

**Parameters:**
- Explicit parameter names (no shorthand)
- Use clear, descriptive names: `_ target: Int` not `_ t: Int`
- For simple parameters, omit name when context is obvious (e.g., `func serialize(_ value: Int)`)
- Tuple parameters for related values (e.g., in file I/O)

**Return Values:**
- Single return value preferred
- Use tuples or structs for multiple values
- Optional returns for potentially missing values (e.g., `TreeNode?`)
- Async functions return computed values, not side effects via parameters

## Module Design

**Exports:**
- Mark public API with `public` keyword in library targets
- Mark internal implementation with `private` or no access modifier
- Use `@testable import` for accessing internal code in tests

**Barrel Files:**
- No barrel file pattern observed (no `__init__.swift` or `Public.swift`)
- Each file contains its primary type
- Related types (nodes, models) grouped in semantic files: `NodeVariants.swift` contains all node types

## Access Modifiers

**Patterns observed:**
- `public` - Library API in `LeetCodeHelpers` target
- `private` - Implementation details, helper functions
- `final` - Used on classes to prevent subclassing (e.g., `final class ResultsLoader`)
- `@Observable` - Modern SwiftUI state management (e.g., `@Observable final class ResultsLoader`)

**View Design:**
- Use `@Bindable` for observable state in views (modern SwiftUI pattern)
- Use `@State` for local view state
- Extract computed properties for view body sections (e.g., `private var topicsView: some View`)

---

*Convention analysis: 2026-02-24*
