# Codebase Structure

**Analysis Date:** 2026-02-24

## Directory Layout

```
CodeBench/
├── CodeBench/                              # iOS app target (Xcode project)
│   ├── CodeBench/                          # Main app source code
│   │   ├── CodeBenchApp.swift              # @main entry point, sets up ResultsLoader
│   │   ├── Models/                         # Data models and test result structures
│   │   ├── Views/                          # Presentation layer - SwiftUI screens
│   │   ├── Services/                       # Observable state managers and loaders
│   │   ├── DataJourney/                    # Data visualization subsystem
│   │   ├── Resources/                      # Bundled test result JSON files
│   │   └── Assets.xcassets/                # App icons and design assets
│   ├── CodeBench.xcodeproj/                # Xcode project file
│   └── project.yml                         # XcodeGen configuration for project generation
│
├── TestCaseEvaluator/                      # Swift Package (macOS test runner/evaluator)
│   ├── Sources/LeetCodeHelpers/            # Shared testing utilities library
│   ├── Tests/                              # 18 test target categories
│   │   ├── ArraysHashingTests/
│   │   ├── TreesTests/
│   │   ├── GraphsTests/
│   │   └── ... (14 more)
│   ├── Package.swift                       # SPM manifest with dynamic test targets
│   └── Scripts/                            # Test execution scripts
│
├── Solutions.json                          # Index of all solution implementations
├── Solutions/                              # Solution JSON files by topic
│   ├── arrays-hashing.json
│   ├── trees.json
│   ├── graphs.json
│   └── ... (12 more topics)
│
└── tc-*.json                               # Test case indices by topic
    ├── tc-index.json                       # Master test case index
    └── tc-arrays-hashing.json ... (15 more topics)
```

## Directory Purposes

**CodeBench/CodeBench/CodeBench/ (iOS App - Main Source):**
- Purpose: SwiftUI-based test results viewer application
- Contains: All app code, UI components, business logic
- Key files: CodeBenchApp.swift, Models/, Views/, Services/, DataJourney/

**CodeBench/CodeBench/CodeBench/Models/:**
- Purpose: Core domain models for test execution results
- Contains: Codable structs for JSON decoding
- Key files:
  - `TestResultsModel.swift`: TestSummary, TopicResults, ProblemMeta, TestResult, TopicSummary

**CodeBench/CodeBench/CodeBench/Views/:**
- Purpose: SwiftUI screen components and UI layers
- Contains: View structs for navigation and presentation
- Key files:
  - `ContentView.swift`: Initial screen with load options (bundled or file picker)
  - `TopicBrowseView.swift`: Topic list with match rate circles, navigation hub
  - `ProblemBrowseView.swift`: Problems per topic
  - `SolutionView.swift`: Test result display with optional data journey visualization

**CodeBench/CodeBench/CodeBench/Services/:**
- Purpose: Observable state managers and data access
- Contains: @Observable classes, file I/O, data loading
- Key files:
  - `ResultsLoader.swift`: Loads JSON from Bundle or file system, manages topicResults dictionary

**CodeBench/CodeBench/CodeBench/DataJourney/:**
- Purpose: Visualization subsystem for test data tracing
- Contains: Models, services, and views for data flow visualization
- Structure:
  - `Models/`: DataJourneyEvent, TraceValue, TraceList, TraceTree, TraceTrie
  - `Services/`: DataJourneyPresenter (@Observable), DataJourneyInteractor (protocol + impl), TestResultBridge, StructureResolver
  - `Views/`: DataJourneyView, DataJourneyVariableTimeline, visualization components for each data structure type

**CodeBench/CodeBench/CodeBench/DataJourney/Views/:**
- Purpose: Specialized visualization components
- Contains: One component per visualization type
- Examples:
  - `DataJourneyVariableTimeline.swift`: Event sequence timeline
  - `DataJourneyStructureCanvasView.swift`: Lists, trees, triples
  - `DataJourneyGraphView.swift`: Graph visualization
  - `DataJourneyHeapView.swift`: Heap visualization
  - `DataJourneyMatrixGridView.swift`: 2D array visualization
  - `DataJourneyTrieGraphView.swift`: Trie tree visualization
  - `DataJourneyTreeGraphView.swift`: Binary tree visualization

**CodeBench/CodeBench/CodeBench/Resources/:**
- Purpose: Bundled precomputed test results for offline demo mode
- Contains: summary.json and topic-specific result JSON files
- Format: Same structure as test evaluator output (TestSummary and TopicResults objects)

**TestCaseEvaluator/ (Swift Package):**
- Purpose: Standalone test execution and evaluation framework
- Contains: Problem solution tests organized by algorithm topic
- Platforms: macOS 26+ (main), iOS 26+ (compatible, no tests run on iOS)

**TestCaseEvaluator/Sources/LeetCodeHelpers/:**
- Purpose: Shared testing utilities used by all test targets
- Contains: Input parsing, output serialization, data structure helpers
- Key files:
  - `InputParser.swift`: Parses all 5 LeetCode input formats (named params, bare arrays, JSON, multiline, raw strings)
  - `ListNode.swift`: Linked list node definition
  - `TreeNode.swift`: Binary tree node definition
  - `NodeVariants.swift`: Generic node types (N-ary trees, graphs)
  - `OutputSerializer.swift`: Converts Swift types back to LeetCode format strings
  - `ResultRecorder.swift`: Records test execution results to JSON files

**TestCaseEvaluator/Tests/:**
- Purpose: 18 test target categories (one per algorithm topic)
- Contains: Problem-specific test implementations
- Organization: Each test file imports LeetCodeHelpers, defines test cases, records results
- Examples:
  - `ArraysHashingTests/`: 15+ problem tests for array hashing problems
  - `TreesTests/`: 25+ problem tests for binary tree problems
  - `GraphsTests/`: Graph traversal and manipulation tests

## Key File Locations

**Entry Points:**
- `CodeBench/CodeBench/CodeBench/CodeBenchApp.swift`: iOS app main struct, creates ResultsLoader
- `TestCaseEvaluator/Package.swift`: SPM package root with dynamic test target generation

**Configuration:**
- `CodeBench/project.yml`: XcodeGen configuration - specifies iOS 26.0, macOS 26.0, Swift Strict Concurrency enabled
- `TestCaseEvaluator/Package.swift`: SPM 6.2, dynamic product generation from testTargets array

**Core Logic:**
- `CodeBench/CodeBench/CodeBench/Services/ResultsLoader.swift`: Handles all file I/O and JSON decoding
- `CodeBench/CodeBench/CodeBench/DataJourney/Services/TestResultBridge.swift`: Parses test string output into visualization structures
- `TestCaseEvaluator/Sources/LeetCodeHelpers/InputParser.swift`: Parses all input formats

**Testing:**
- `TestCaseEvaluator/Tests/ArraysHashingTests/`: Example test category (replicate structure for each topic)
- Individual test files (e.g., `TwoSumTests.swift`) follow XCTest pattern

**Data/Resources:**
- `CodeBench/CodeBench/CodeBench/Resources/`: Bundled JSON results (populated at build time)
- `Solutions/`: Topic-based solution metadata JSON files
- `tc-*.json`: Test case indices by category

## Naming Conventions

**Files:**
- `[FeatureName]View.swift`: SwiftUI View structs (e.g., ContentView, TopicBrowseView)
- `[FeatureName]+[Aspect].swift`: View extensions for layout/logic (e.g., DataJourneyView+Selection.swift)
- `[FeatureName]Model.swift`: or Model file (TestResultsModel.swift)
- `[FeatureName]Presenter.swift`: Observable view model (DataJourneyPresenter.swift)
- `[FeatureName]Interactor.swift`: Business logic class (DataJourneyInteractor.swift)
- `[FeatureName]Bridge.swift`: Data transformation/parsing utility (TestResultBridge.swift)
- `[ProblemName]Tests.swift`: Test files in TestCaseEvaluator (TwoSumTests.swift)

**Directories:**
- `Views/`: UI components
- `Services/`: Observable state and business logic
- `Models/`: Data structures and types
- `DataJourney/`: Feature-specific subsystem (contains own Models/Services/Views)
- `Tests/[TopicName]Tests/`: Test category directory (e.g., ArraysHashingTests/)

## Where to Add New Code

**New View Feature:**
- Add View struct file: `CodeBench/CodeBench/CodeBench/Views/NewFeature.swift`
- Create @Observable state manager if needed: `CodeBench/CodeBench/CodeBench/Services/NewFeatureState.swift`
- Add model if needed: `CodeBench/CodeBench/CodeBench/Models/NewFeatureModel.swift`
- Add navigation from existing view (typically ContentView or TabView)

**New Data Journey Visualization Component:**
- Add View: `CodeBench/CodeBench/CodeBench/DataJourney/Views/DataJourney[StructureType]View.swift`
- Update `DataJourneyView.swift` to route to new component based on data structure type
- Add model if new TraceValue type needed: extend TraceValue enum in `DataJourneyModels.swift`
- Add parser in `StructureResolver.swift` if new structure requires custom layout

**New Test Category (in TestCaseEvaluator):**
- Create directory: `TestCaseEvaluator/Tests/[TopicName]Tests/`
- Create test files: `[ProblemName]Tests.swift` (import XCTest, LeetCodeHelpers)
- Update `Package.swift` testTargets array with new (name, path) tuple
- Tests automatically compile and run as part of SPM

**Shared Testing Utility:**
- Add to: `TestCaseEvaluator/Sources/LeetCodeHelpers/`
- Name pattern: `[UtilityName].swift`
- Available to all test targets automatically

**Utilities and Helpers:**
- App-specific: `CodeBench/CodeBench/CodeBench/Services/`
- Test-specific: `TestCaseEvaluator/Sources/LeetCodeHelpers/`
- UI helpers: `CodeBench/CodeBench/CodeBench/DataJourney/Views/` (design tokens like VizTypography.swift)

## Special Directories

**CodeBench/CodeBench/CodeBench/Resources/:**
- Purpose: Bundled test result data for offline demo
- Generated: Yes (populated by build process from test evaluator output)
- Committed: Yes (checked into git, provides offline functionality)

**CodeBench/CodeBench/CodeBench/DataJourney/:**
- Purpose: Logically isolated visualization subsystem
- Generated: No
- Committed: Yes

**TestCaseEvaluator/.build/:**
- Purpose: SPM build artifacts
- Generated: Yes (created during `swift build`)
- Committed: No (.gitignore excludes)

**CodeBench/CodeBench/CodeBench.xcodeproj/:**
- Purpose: Xcode project metadata
- Generated: Yes (by XcodeGen from project.yml)
- Committed: Mixed (shared data committed, user data ignored)

---

*Structure analysis: 2026-02-24*
