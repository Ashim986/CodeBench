# Architecture

**Analysis Date:** 2026-02-24

## Pattern Overview

**Overall:** Model-View-ViewModel (MVVM) with feature-specific subsystems

**Key Characteristics:**
- SwiftUI-based UI layer with Observable state managers
- Separation between data loading, visualization, and presentation
- Two distinct subsystems: Results viewer and Data Journey visualizer
- Protocol-driven design for testability (especially DataJourney services)
- Data flows from JSON files through parsers into typed models
- iOS-first implementation with macOS compatibility (Swift 6.2+)

## Layers

**Presentation Layer (Views):**
- Purpose: Render UI and collect user interaction
- Location: `CodeBench/CodeBench/Views/` and `CodeBench/CodeBench/DataJourney/Views/`
- Contains: SwiftUI `View` structs, layout composition, rendering logic
- Depends on: Observable state classes (ResultsLoader, DataJourneyPresenter), Models
- Used by: SwiftUI runtime

**ViewModel/State Layer (Observable):**
- Purpose: Manage presentation state and coordinate between views and business logic
- Location: `CodeBench/CodeBench/Services/` and `CodeBench/CodeBench/DataJourney/Services/`
- Contains: `@Observable` classes (`ResultsLoader`, `DataJourneyPresenter`), interactors (`DataJourneyInteractor`)
- Depends on: Models, data parsers, file I/O
- Used by: Presentation layer via @Bindable

**Data Model Layer:**
- Purpose: Define core domain objects and data structures
- Location: `CodeBench/CodeBench/Models/` and `CodeBench/CodeBench/DataJourney/Models/`
- Contains: `Codable` structs (TestSummary, TestResult, ProblemMeta, TopicSummary), trace models (DataJourneyEvent, TraceValue)
- Depends on: Foundation
- Used by: All other layers

**Data Access Layer:**
- Purpose: Load JSON files and handle filesystem operations
- Location: Embedded in `ResultsLoader`, bridged through `TestResultBridge`
- Contains: File loading, JSON decoding, path resolution
- Depends on: Foundation, Models
- Used by: ViewModel layer

**Visualization Helpers:**
- Purpose: Parse and transform test data into visualization-ready structures
- Location: `CodeBench/CodeBench/DataJourney/Services/` (StructureResolver, TestResultBridge, DataJourneyPresenter)
- Contains: Structure resolution, diff calculations, event filtering
- Depends on: Models
- Used by: DataJourney presentation views

## Data Flow

**Results Loading Flow:**

1. App launches → `CodeBenchApp` creates `ResultsLoader` (Observable state)
2. `ContentView` loads: shows either loading screen or topics view
3. User taps "Load Bundled Data" or "Load from Files"
4. `ResultsLoader.loadFromBundle()` or `loadFromDirectory()` executes:
   - Reads `summary.json` from Bundle or FileManager
   - Decodes into `TestSummary` struct
   - Iterates topic names, reads each `{topic}.json`
   - Decodes into `TopicResults`, stores in `topicResults: [String: TopicResults]`
   - Sets `isLoaded = true`
5. ContentView rebuilds → `TopicBrowseView` displays topics
6. User navigates: Topic → Problem → Solution
7. `SolutionView` queries `ResultsLoader.resultsForProblem()` to get test results

**Data Journey Visualization Flow:**

1. `SolutionView` displays a test result (TestResult struct)
2. Calls `TestResultBridge.events(from: result)`:
   - Parses input string ("nums = [2,7,11,15], target = 9") into `[String: TraceValue]`
   - Parses expected output string into `TraceValue`
   - Parses computed output string into `TraceValue`
   - Returns 3 `DataJourneyEvent` objects (input, expected, output)
3. `DataJourneyView` receives events, displays visualization:
   - `DataJourneyVariableTimeline` shows event sequence
   - User selects event → `DataJourneyPresenter.selectEvent()` updates selection
   - Views re-render with highlighted data structures

**State Management:**

- `ResultsLoader` (@Observable): Owns all loaded test data, coordinates file I/O
- `DataJourneyPresenter` (@Observable): Owns visualization state (5 properties: dataJourney, selectedJourneyEventID, highlightedExecutionLine, isJourneyTruncated, sourceCode)
- Data flows downward from Observable to View, events flow upward from View to Observable
- No shared mutable state across features (Results viewer and Data Journey are independent)

## Key Abstractions

**TestResult Bridge:**
- Purpose: Converts flat string test results into structured visualization events
- Examples: `CodeBench/CodeBench/DataJourney/Services/TestResultBridge.swift`
- Pattern: Static enum with focused parsing methods for each value type (parseValue, parseInputParameters, parseArray, splitAssignments)

**DataJourneyInteracting Protocol:**
- Purpose: Abstract trace event processing logic
- Examples: `CodeBench/CodeBench/DataJourney/Services/DataJourneyInteractor.swift` implements protocol
- Pattern: Protocol defines interface (processTraceEvents, shouldTruncate), concrete implementation handles filtering and step limiting

**TraceValue Enum:**
- Purpose: Represent any parsed value type from test data (primitives, arrays, structures, pointers)
- Examples: `.null`, `.bool(true)`, `.number(3.14, isInt: false)`, `.array([...])`, `.list(TraceList)`, `.tree(TraceTree)`, `.trie(TraceTrie)`
- Pattern: Indirect recursive enum with factory method `TraceValue.from(json:)` for polymorphic deserialization

**Observable State Pattern:**
- Purpose: Enable SwiftUI reactive updates without @State overhead
- Examples: `ResultsLoader`, `DataJourneyPresenter` marked with `@Observable` and `@MainActor`
- Pattern: Mutable properties observed by Views; Views call methods to trigger updates

## Entry Points

**App Entry Point:**
- Location: `CodeBench/CodeBench/CodeBenchApp.swift`
- Triggers: iOS app launch
- Responsibilities: Creates ResultsLoader observable, provides to ContentView

**Content View (Primary Navigation):**
- Location: `CodeBench/CodeBench/Views/ContentView.swift`
- Triggers: Presented after app launch
- Responsibilities: Shows loading screen or topics view, handles file picker for loading results

**Topic Browse (Navigation Hub):**
- Location: `CodeBench/CodeBench/Views/TopicBrowseView.swift`
- Triggers: After results loaded
- Responsibilities: Displays list of topics with match rates, navigates to TopicDetailView

**Problem Browse & Solution View:**
- Location: `CodeBench/CodeBench/Views/ProblemBrowseView.swift`, `CodeBench/CodeBench/Views/SolutionView.swift`
- Triggers: User navigation through topics → problems
- Responsibilities: Display problems per topic, render test results with data journey visualization

**Data Journey View:**
- Location: `CodeBench/CodeBench/DataJourney/Views/DataJourneyView.swift`
- Triggers: Embedded in SolutionView to visualize test data
- Responsibilities: Render trace timeline, handle event selection, display structure visualizations

## Error Handling

**Strategy:** Fail-safe with user messaging

**Patterns:**
- `ResultsLoader` catches JSON decoding errors, stores in `errorMessage` property displayed in UI
- File not found returns early with descriptive error: "No summary.json found in selected directory."
- Parsing errors in `TestResultBridge` default to `.string(trimmed)` for unparseable values
- Data Journey structure resolution in `StructureResolver` handles missing data gracefully (e.g., cycles in linked lists marked explicitly)

## Cross-Cutting Concerns

**Logging:** None detected. Errors handled through model properties, displayed in UI.

**Validation:**
- JSON decoding validates structure through Codable conformance
- Input parameter parsing validates bracket matching during assignment splitting
- TraceValue parsing validates numeric ranges (Int, Double conversion)

**Authentication:** Not applicable. Loads local bundled or file-selected JSON data.

---

*Architecture analysis: 2026-02-24*
