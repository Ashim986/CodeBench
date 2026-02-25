# Architecture Patterns: Step-by-Step Visualization for CodeBench

**Domain:** iOS algorithm visualization app
**Researched:** 2026-02-24
**Focus:** How to integrate step-by-step algorithm playback into the existing DataJourney subsystem

## Executive Summary

CodeBench's existing architecture is remarkably well-positioned for step-by-step visualization. The `DataJourneyEvent` model already has a `.step` kind, the `DataJourneyAnimationController` already manages play/pause/speed, the `TraceValueDiff` module already computes per-element diffs between consecutive events, and the `DataJourneyView+Playback` extension already renders timeline chips and playback controls. The primary gap is **step data generation** -- there is no mechanism to produce intermediate algorithm states. The secondary gap is **presenter state for N-step sequences** versus the current 3-event (input/expected/output) flow. This document provides the concrete architecture for closing both gaps.

---

## 1. Step Generation Strategy

### Recommendation: Pre-computed Step Data Embedded in Solution Code

**Confidence: HIGH** (based on full codebase analysis)

Three strategies were evaluated:

| Strategy | Complexity | Fits CodeBench? | Why/Why Not |
|----------|-----------|-----------------|-------------|
| (A) Embed step recording in solution code | Low | **YES** | Solutions are pre-built, code-generated. Adding `Trace.step()` calls is a one-time modification per solution. |
| (B) Generate steps from trace data | High | No | Current trace data is 3 flat events (input/expected/output). No intermediate states exist to derive steps from. |
| (C) Interpret solution code at runtime | Very High | No | Requires a Swift interpreter or sandboxed execution engine on iOS. Massive scope creep. |

**Strategy A is the only viable option.** Here is why:

1. **Solutions are pre-built and code-generated.** Each test file in `TestCaseEvaluator/Tests/` contains the solution code directly (e.g., `TwoSumTests.swift` line 6-17). Modifying the solution code to emit step events is a controlled, offline process.

2. **The test pipeline already records results.** `ResultRecorderActor` writes JSON. Extending it to also write step trace data is a natural extension.

3. **The iOS app is read-only.** It loads bundled JSON data. It never executes solution code. Step data must be pre-computed and shipped as JSON alongside test results.

### Step Recording Design

The step recording mechanism lives in `TestCaseEvaluator`. Solutions are modified to call a trace recorder at key algorithm points.

```
+-----------------------------+     +------------------------+
|   TestCaseEvaluator         |     |   iOS App (read-only)  |
|                             |     |                        |
|   Solution code             |     |   Load JSON bundle     |
|     + Trace.step() calls    |     |     |                  |
|         |                   |     |     v                  |
|         v                   |     |   Parse into           |
|   StepTraceRecorder         |     |   [DataJourneyEvent]   |
|     (captures snapshots)    |     |     |                  |
|         |                   |     |     v                  |
|         v                   |     |   DataJourneyPresenter |
|   JSON step data            |---->|   + AnimationController|
|   (bundled in app)          |     |     |                  |
+-----------------------------+     |     v                  |
                                    |   Animated playback    |
                                    +------------------------+
```

### Trace API for Solution Code

Add a lightweight tracing API to `LeetCodeHelpers`:

```swift
// TestCaseEvaluator/Sources/LeetCodeHelpers/StepTracer.swift

public final class StepTracer {
    private var steps: [[String: Any]] = []
    private let sourceCode: String

    public init(sourceCode: String) {
        self.sourceCode = sourceCode
    }

    /// Record a snapshot of algorithm state at a specific code line.
    public func step(
        _ label: String,
        line: Int,
        _ values: [String: Any]
    ) {
        steps.append([
            "kind": "step",
            "label": label,
            "line": line,
            "values": values
        ])
    }

    /// Export all recorded steps as JSON-serializable dictionaries.
    public func export() -> [[String: Any]] {
        return steps
    }
}
```

### Example: Two Sum with Step Tracing

```swift
private class Solution {
    func twoSum(
        _ nums: [Int], _ target: Int,
        tracer: StepTracer? = nil
    ) -> [Int] {
        var valueToIndex: [Int: Int] = [:]
        for (i, num) in nums.enumerated() {
            let complement = target - num
            tracer?.step("Check nums[\(i)]", line: 4, [
                "nums": nums,
                "i": i,
                "num": num,
                "complement": complement,
                "valueToIndex": valueToIndex
            ])
            if let j = valueToIndex[complement] {
                tracer?.step("Found match!", line: 6, [
                    "nums": nums,
                    "i": i,
                    "j": j,
                    "result": [j, i]
                ])
                return [j, i]
            }
            valueToIndex[num] = i
        }
        return []
    }
}
```

**Key design decisions:**

- `tracer` is optional -- existing tests work without it
- `line:` parameter corresponds to line numbers in the solution's source code (from `Solutions/*.json`)
- Values are captured as `[String: Any]` (JSON-serializable)
- The tracer is a simple append-only recorder, not an observer pattern

---

## 2. Event Model Extension

### Current Model

```
DataJourneyEvent
  - id: UUID
  - kind: .input | .output | .step
  - line: Int?
  - label: String?
  - values: [String: TraceValue]
```

Currently `TestResultBridge.events(from:)` produces exactly 3 events:
1. `.input` (parsed from `result.input` string)
2. `.step` with label "Expected" (parsed from `result.originalExpected`)
3. `.output` (parsed from `result.computedOutput`)

### Extended Model: No Schema Change Required

**Confidence: HIGH**

The existing `DataJourneyEvent` schema already supports step-by-step data. The `.step` kind exists. The `line` field exists. The `label` field exists. The `values` dictionary supports arbitrary `TraceValue` entries. **No model change is needed.**

What changes is the **data source**, not the schema:

```
BEFORE (3 events from TestResultBridge):
  [.input, .step("Expected"), .output]

AFTER (N events from pre-computed JSON):
  [.input, .step("Init"), .step("i=0"), .step("i=1"), ..., .output]
```

### New JSON Format for Step Data

A new JSON file per problem carries the step trace data:

```json
{
  "slug": "two-sum",
  "topic": "arrays-hashing",
  "sourceCode": "func twoSum(_ nums: [Int], _ target: Int) -> [Int] {\n    var valueToIndex...",
  "testTraces": {
    "4B7827CE-A154-4E5C-A002-32C9E73DE97C": {
      "steps": [
        {
          "kind": "input",
          "label": "Input",
          "values": {
            "nums": [2, 7, 11, 15],
            "target": 9
          }
        },
        {
          "kind": "step",
          "label": "Check nums[0]",
          "line": 4,
          "values": {
            "nums": [2, 7, 11, 15],
            "i": 0,
            "num": 2,
            "complement": 7,
            "valueToIndex": {}
          }
        },
        {
          "kind": "step",
          "label": "Check nums[1]",
          "line": 4,
          "values": {
            "nums": [2, 7, 11, 15],
            "i": 1,
            "num": 7,
            "complement": 2,
            "valueToIndex": {"2": 0}
          }
        },
        {
          "kind": "step",
          "label": "Found match!",
          "line": 6,
          "values": {
            "nums": [2, 7, 11, 15],
            "i": 1,
            "j": 0,
            "result": [0, 1]
          }
        },
        {
          "kind": "output",
          "label": "Output (Match)",
          "values": {
            "result": [0, 1]
          }
        }
      ]
    }
  }
}
```

### File Organization

```
TestCaseEvaluator/
  step_traces/
    arrays-hashing/
      two-sum.json
      contains-duplicate.json
      ...
    trees/
      invert-binary-tree.json
      ...

CodeBench/CodeBench/Resources/
  step_traces/           <-- bundled into iOS app
    arrays-hashing/
      two-sum.json
      ...
```

Step traces are per-problem (not per-topic) because each problem may have many test cases and the combined data could be large.

---

## 3. Presenter / State Machine for Playback

### Current State

The `DataJourneyPresenter` currently manages 5 properties:

```swift
var dataJourney: [DataJourneyEvent] = []
var selectedJourneyEventID: UUID?
var highlightedExecutionLine: Int?
var isJourneyTruncated: Bool = false
var sourceCode: String = ""
```

The `DataJourneyAnimationController` manages play/pause:

```swift
@Published var isPlaying = false
@Published var playbackSpeed: Double = 1.0
```

### Recommendation: Minimal Extension, Not Rewrite

**Confidence: HIGH**

The existing architecture is sound. The presenter already handles N events, selection, and line highlighting. The animation controller already handles play/pause/speed. The `DataJourneyView+Playback` extension already renders timeline chips.

**What to add to DataJourneyPresenter:**

```swift
@Observable @MainActor
final class DataJourneyPresenter {
    // EXISTING (unchanged)
    var dataJourney: [DataJourneyEvent] = []
    var selectedJourneyEventID: UUID?
    var highlightedExecutionLine: Int?
    var isJourneyTruncated: Bool = false
    var sourceCode: String = ""

    // NEW: Step-by-step playback mode
    var hasStepData: Bool = false   // distinguishes step vs static mode

    // EXISTING (unchanged)
    private let interactor: DataJourneyInteracting

    // NEW: Load step data from pre-computed trace JSON
    func loadStepTrace(
        events: [DataJourneyEvent],
        sourceCode: String
    ) {
        self.sourceCode = sourceCode
        self.hasStepData = true
        updateFromExecution(traceEvents: events)
    }

    // EXISTING updateFromExecution works as-is for N events
    // EXISTING selectEvent works as-is
    // EXISTING clear works as-is (add hasStepData = false)
}
```

### State Machine Diagram

```
                      loadStepTrace()
                           |
                           v
                    +-------------+
        +---------->|   READY     |<-----------+
        |           | (events     |            |
        |           |  loaded,    |            |
        |           |  idx = 0)   |            |
        |           +------+------+            |
        |                  |                   |
        |             play |                   |
        |                  v                   |
        |           +-------------+            |
        |           |  PLAYING    |---pause--->+
        |           | (timer      |            |
        |           |  advances   |            |
        |           |  idx)       |            |
        |           +------+------+            |
        |                  |                   |
        |          reached end                 |
        |                  |                   |
        |                  v                   |
        |           +-------------+            |
        +-----------+  FINISHED   |            |
        restart     | (idx = max) |            |
                    +-------------+            |
                                               |
                    user tap step chip -------->+
                    user scrub timeline ------->+
                    user press prev/next ------>+
```

This state machine is **already implemented** by `DataJourneyAnimationController` + `DataJourneyView+Playback`. The `advancePlayback()` method increments the index, `pause()` stops the timer, and reaching the end pauses automatically. No new state machine is needed.

### What Changes in the View Layer

Almost nothing. The `DataJourneyView+Selection` extension already computes:

```swift
var playbackEvents: [DataJourneyEvent] {
    if !stepEvents.isEmpty {
        return stepEvents    // <-- step-by-step mode
    }
    return [inputEvent, outputEvent].compactMap { $0 }  // fallback
}
```

When step data is loaded, `stepEvents` will be non-empty, and the playback system automatically uses them. The timeline chips, step counter ("Step 3 of 12"), play/pause, speed picker, forward/back buttons -- all work without modification.

---

## 4. View Composition for Animated Structures

### Current Diff Infrastructure

The codebase already has sophisticated diff computation:

```
TraceValueDiff
  .changedKeys(previous:current:)       -- variable-level diff
  .changedIndices(previous:current:)     -- array element diff
  .changedNodeIds(previous:current:)     -- linked list node diff
  .changedTreeNodeIds(previous:current:) -- tree node diff
  .changedMatrixCells(previous:current:) -- matrix cell diff
  .changedDictKeys(previous:current:)    -- dictionary key diff
  .elementChanges(previous:current:)     -- LCS-based array diff
  .nodeChanges(previous:current:)        -- tree node add/remove/modify
```

The `DataJourneyStructureCanvasView+DiffHighlights` extension already renders diff highlights. The `previousPlaybackEvent` property already provides the prior event for comparison.

### What SwiftUI Animations Already Handle

The view already applies animations on step selection:

```swift
// DataJourneyView+Playback.swift line 322-329
func selectEvent(_ event: DataJourneyEvent) {
    let animation: Animation? = reduceMotion
        ? .linear(duration: 0.05)
        : .easeInOut(duration: 0.35)
    withAnimation(animation) {
        selectedEventID = event.id
        onSelectEvent(event)
    }
}
```

When the selected event changes, SwiftUI will:
1. Recompute `selectedEvent` and `previousPlaybackEvent`
2. `DataJourneyStructureCanvasView` re-renders with new data
3. Diff highlights update (changed elements glow/pulse)
4. `withAnimation` smoothly transitions between states

### What Needs Enhancement

**Array element transitions:** Currently the diff only highlights which indices changed. For step-by-step, we want to show:
- Elements sliding to new positions (for sorts)
- New elements appearing (for insertions)
- Elements fading out (for deletions)
- Pointer arrows moving between elements

This requires extending `DataJourneySequenceBubbleRow` to support animated element identity:

```swift
// Proposed extension to DataJourneySequenceBubbleRow

// Current: Each bubble is identified by array index
ForEach(Array(items.enumerated()), id: \.offset) { index, value in
    TraceBubble(...)
}

// Enhanced: Each bubble identified by value identity for matchedGeometry
ForEach(Array(items.enumerated()), id: \.offset) { index, value in
    TraceBubble(...)
        .matchedGeometryEffect(
            id: value.identityKey + "-\(index)",
            in: animationNamespace
        )
}
```

**Pointer visualization:** The existing `PointerMarker` and `PointerMotion` models already support showing pointers on array indices and linked list nodes. Step data naturally includes pointer state in the `values` dictionary (e.g., `"i": 3` means pointer `i` is at index 3). The `StructureResolver` already uses name-based heuristics to detect pointer values.

**Enhancement needed:** A `PointerExtractor` that examines step event values and identifies which scalar integers are array pointers vs. algorithm state. Heuristic: if a variable name matches common pointer names (`i`, `j`, `left`, `right`, `lo`, `hi`, `start`, `end`, `slow`, `fast`, `curr`, `prev`, `next`) and its value is within array bounds, treat it as a pointer.

```swift
enum PointerExtractor {
    static let knownPointerNames: Set<String> = [
        "i", "j", "k", "l", "r", "left", "right",
        "lo", "hi", "low", "high", "start", "end",
        "slow", "fast", "curr", "prev", "next",
        "p", "q", "head", "tail", "top", "bottom",
        "front", "back", "mid", "pivot"
    ]

    static func extractPointers(
        from event: DataJourneyEvent,
        arraySize: Int
    ) -> [PointerMarker] {
        event.values.compactMap { key, value in
            guard knownPointerNames.contains(key.lowercased()),
                  case let .number(num, isInt) = value,
                  isInt,
                  Int(num) >= 0,
                  Int(num) < arraySize
            else { return nil }
            return PointerMarker(
                name: key,
                index: Int(num),
                theme: currentTheme
            )
        }
    }
}
```

---

## 5. TestResultBridge Extension

### Current Behavior

`TestResultBridge.events(from: TestResult)` parses flat strings into 3 events. This continues to work for problems without step data.

### New Entry Point: StepTraceBridge

A new bridge loads pre-computed step trace JSON. This is a separate code path, not a modification of `TestResultBridge`.

```swift
// DataJourney/Services/StepTraceBridge.swift

enum StepTraceBridge {
    /// Load step trace events from pre-computed JSON data.
    ///
    /// Returns nil if no step trace exists for this test case,
    /// in which case the caller falls back to TestResultBridge.
    static func events(
        forSlug slug: String,
        testId: String,
        from bundle: Bundle
    ) -> (events: [DataJourneyEvent], sourceCode: String)? {

        // 1. Locate the step trace JSON file
        guard let url = bundle.url(
            forResource: slug,
            withExtension: "json",
            subdirectory: "step_traces/\(topic)"
        ) else { return nil }

        // 2. Load and parse
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data)
                  as? [String: Any],
              let sourceCode = json["sourceCode"] as? String,
              let testTraces = json["testTraces"] as? [String: Any],
              let trace = testTraces[testId] as? [String: Any],
              let stepsJSON = trace["steps"] as? [Any]
        else { return nil }

        // 3. Convert to DataJourneyEvent array
        let events = stepsJSON.compactMap {
            DataJourneyEvent.from(json: $0)
        }

        guard !events.isEmpty else { return nil }
        return (events: events, sourceCode: sourceCode)
    }
}
```

### Call Site in SolutionView

```swift
// In SolutionView, when displaying a test result:

func loadVisualization(for result: TestResult) {
    // Try step-by-step first
    if let stepData = StepTraceBridge.events(
        forSlug: result.slug,
        testId: result.testId,
        from: Bundle.main
    ) {
        presenter.loadStepTrace(
            events: stepData.events,
            sourceCode: stepData.sourceCode
        )
    } else {
        // Fall back to static 3-event view
        let events = TestResultBridge.events(from: result)
        presenter.updateFromExecution(traceEvents: events)
    }
}
```

---

## 6. Separation of Concerns

### Responsibility Boundaries

```
+-------------------------------------------------------+
|                TestCaseEvaluator (macOS)                |
|                                                        |
|  RESPONSIBILITIES:                                     |
|  - Execute solutions against test cases                |
|  - Record pass/fail results (existing)                 |
|  - Record step-by-step trace data (NEW)                |
|  - Export JSON files for bundling                       |
|                                                        |
|  COMPONENTS:                                           |
|  - StepTracer (NEW) -- captures snapshots              |
|  - ResultRecorderActor (existing) -- records results   |
|  - StepTraceExporter (NEW) -- writes step JSON         |
|  - Solution code with Trace calls (MODIFIED)           |
+-------------------------------------------------------+
                          |
                     JSON files
                          |
                          v
+-------------------------------------------------------+
|                iOS App (read-only)                      |
|                                                        |
|  RESPONSIBILITIES:                                     |
|  - Load and parse JSON data                            |
|  - Present step-by-step visualization                  |
|  - Animate transitions between steps                   |
|  - Handle user playback interaction                    |
|                                                        |
|  COMPONENTS:                                           |
|  - StepTraceBridge (NEW) -- loads step JSON            |
|  - TestResultBridge (existing) -- loads flat results   |
|  - DataJourneyPresenter (MINOR EXTENSION)              |
|  - DataJourneyAnimationController (unchanged)          |
|  - DataJourneyView + extensions (MINOR ENHANCEMENTS)   |
|  - PointerExtractor (NEW) -- identifies pointer vars   |
+-------------------------------------------------------+
```

### What Goes Where

| Concern | Location | Rationale |
|---------|----------|-----------|
| Which algorithm steps to trace | `TestCaseEvaluator/Tests/` (solution code) | Developer decides what is pedagogically valuable |
| How to capture a step snapshot | `LeetCodeHelpers/StepTracer.swift` | Reusable across all solutions |
| How to serialize step data | `LeetCodeHelpers/StepTraceExporter.swift` | Consistent JSON format |
| How to load step data in iOS | `DataJourney/Services/StepTraceBridge.swift` | iOS-side parsing |
| How to animate between steps | `DataJourney/Views/` | SwiftUI rendering concern |
| When to show step vs static view | `Views/SolutionView.swift` | UI routing decision |

### What Does NOT Move

- `TestResultBridge` stays -- it handles the static 3-event path
- `DataJourneyInteractor` stays -- it handles event processing/truncation
- `StructureResolver` stays -- it detects structure types from events
- `TraceValueDiff` stays -- it computes diffs between consecutive events

---

## 7. Backward Compatibility

### Strategy: Graceful Fallback

```
Has step trace JSON for this problem + test case?
  |
  YES --> Load step events, show animated playback
  |
  NO  --> Fall back to TestResultBridge (3 static events)
```

This is a **zero-risk** strategy because:

1. **No existing code is modified.** `TestResultBridge` continues to work as-is.
2. **No existing data format changes.** The test result JSON schema is untouched.
3. **Step trace data is additive.** New JSON files are added alongside existing ones.
4. **The presenter handles both modes.** `DataJourneyPresenter.updateFromExecution()` already works with any number of events.

### Progressive Enhancement

Step traces can be added one problem at a time:

```
Phase 1: Add step traces for 5 core problems
  - Two Sum (hash map lookup)
  - Contains Duplicate (set operations)
  - Valid Parentheses (stack push/pop)
  - Binary Search (pointer movement)
  - Reverse Linked List (pointer rewiring)

Phase 2: Add step traces per topic category
  - Arrays: sorting, sliding window, two pointers
  - Trees: traversals, insertions
  - Graphs: BFS, DFS
  - etc.
```

The UI gracefully shows either:
- Step controls with timeline chips (when step data exists)
- Static input/expected/output view (when no step data exists)

This is **already how the codebase works** -- `DataJourneyView+Selection.playbackEvents` returns step events when they exist, or falls back to input/output.

---

## 8. Complete Data Flow (End-to-End)

```
                    STEP GENERATION (offline, macOS)
                    ================================

Solutions/*.json  -->  TestCaseEvaluator
  (source code)          |
                         v
                    Generate test files
                    with StepTracer calls
                         |
                         v
                    swift test
                         |
                    +----+----+
                    |         |
                    v         v
              test_results/  step_traces/
              (pass/fail)    (step events)

                    APP CONSUMPTION (iOS)
                    =====================

Resources/summary.json
Resources/arrays-hashing.json     <-- test results
Resources/step_traces/two-sum.json <-- step traces
Resources/step_traces/...
         |
         v
    ResultsLoader.loadFromBundle()
         |                              StepTraceBridge.events()
         v                                    |
    TopicBrowseView                           v
         |                              [DataJourneyEvent] + sourceCode
         v                                    |
    ProblemBrowseView                         v
         |                              DataJourneyPresenter.loadStepTrace()
         v                                    |
    SolutionView ---> Try StepTraceBridge --> |
         |                                    v
         |   (fallback if no step data)  DataJourneyView
         +-----> TestResultBridge.events()    |
                       |                      v
                       v                 Animated playback
                  DataJourneyPresenter   with diff highlights,
                  .updateFromExecution() pointer markers,
                       |                 code context
                       v
                  DataJourneyView
                  (static mode)
```

---

## 9. Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `StepTracer` (NEW, LeetCodeHelpers) | Captures algorithm state snapshots during test execution | Solution code calls it; `StepTraceExporter` reads from it |
| `StepTraceExporter` (NEW, LeetCodeHelpers) | Serializes step data to JSON files | Reads from `StepTracer`; writes to filesystem |
| `StepTraceBridge` (NEW, DataJourney/Services) | Loads and parses step trace JSON on iOS | Reads from Bundle; produces `[DataJourneyEvent]` |
| `PointerExtractor` (NEW, DataJourney/Services) | Identifies pointer variables in step events | Called by `DataJourneyStructureCanvasView` |
| `DataJourneyPresenter` (EXTENDED) | Manages visualization state, now with `hasStepData` flag | Receives events from either bridge; drives views |
| `DataJourneyAnimationController` (UNCHANGED) | Play/pause/speed timer | Owned by `DataJourneyView`; calls advance closure |
| `DataJourneyInteractor` (UNCHANGED) | Event filtering and truncation | Called by presenter for event processing |
| `StructureResolver` (UNCHANGED) | Detects structure types from event values | Called by view for rendering decisions |
| `TraceValueDiff` (UNCHANGED) | Computes element-level diffs between events | Called by views for highlight rendering |
| `DataJourneyView` + extensions (MINOR) | Renders playback UI and structure canvas | Reads presenter state; delegates to sub-views |
| `TestResultBridge` (UNCHANGED) | Parses flat test strings into 3 events | Called as fallback when no step data exists |

---

## 10. Patterns to Follow

### Pattern 1: Bridge Pattern for Data Loading

**What:** Separate the data format/source from the consumer. `StepTraceBridge` and `TestResultBridge` both produce `[DataJourneyEvent]` but from different sources.

**Why:** The presenter and views do not care where events came from. They render whatever events they receive. This enables adding new data sources (e.g., live execution on macOS) without changing the view layer.

```swift
// Both bridges produce the same output type
let events: [DataJourneyEvent] = stepTraceBridge.events()
    ?? testResultBridge.events()  // fallback
```

### Pattern 2: Optional Tracer Parameter

**What:** Solution functions accept an optional `StepTracer?` parameter. When nil, no tracing occurs (zero overhead). When provided, snapshots are captured.

**Why:** Keeps existing tests working without modification. The tracer is only provided in trace-recording test runs, not in correctness-checking test runs.

```swift
func twoSum(_ nums: [Int], _ target: Int, tracer: StepTracer? = nil) -> [Int] {
    // tracer?.step() calls are no-ops when tracer is nil
}
```

### Pattern 3: Event-Driven Diff Rendering

**What:** Views compute diffs between `previousPlaybackEvent` and `selectedEvent` to determine what changed. Changed elements get highlighted/animated.

**Why:** Already implemented in `TraceValueDiff` and `DataJourneyStructureCanvasView+DiffHighlights`. Step-by-step visualization naturally leverages this by providing consecutive events as previous/current.

### Pattern 4: Progressive Data Enhancement

**What:** Ship the app with zero step traces initially. Add step traces per-problem over time. The app gracefully falls back to static visualization.

**Why:** Avoids big-bang delivery. Each problem's step trace can be developed, tested, and bundled independently.

---

## 11. Anti-Patterns to Avoid

### Anti-Pattern 1: Runtime Code Interpretation

**What:** Executing or interpreting Swift solution code on the iOS device to generate steps dynamically.

**Why bad:** Massive complexity (needs a Swift interpreter or sandboxed process). Security concerns. Performance unpredictable. iOS sandboxing restrictions.

**Instead:** Pre-compute all step data offline in TestCaseEvaluator.

### Anti-Pattern 2: Monolithic Step Trace Files

**What:** One giant JSON file per topic containing step traces for all problems and all test cases.

**Why bad:** Topic files could reach 50+ MB. Loading time would be unacceptable. Memory pressure on iOS.

**Instead:** One JSON file per problem. Load only when user navigates to that problem. Lazy loading.

### Anti-Pattern 3: Modifying DataJourneyEvent Schema

**What:** Adding step-specific fields (e.g., `stepIndex`, `highlightedElements`, `pointerPositions`) to `DataJourneyEvent`.

**Why bad:** The current schema is already flexible enough. Adding fields couples the event format to rendering concerns. The event should be a pure data snapshot; the view layer derives rendering information.

**Instead:** Keep events as pure `{kind, line, label, values}`. Let `PointerExtractor`, `StructureResolver`, and `TraceValueDiff` derive rendering information from the values dictionary.

### Anti-Pattern 4: Dual Animation Systems

**What:** Creating a new animation system separate from `DataJourneyAnimationController` for step-by-step playback.

**Why bad:** The existing animation controller already handles play/pause/speed/advance. Duplicating it creates state synchronization bugs.

**Instead:** Use the existing `DataJourneyAnimationController` unchanged. It works with any number of events.

---

## 12. Scalability Considerations

| Concern | 10 steps | 100 steps | 500 steps |
|---------|----------|-----------|-----------|
| JSON file size | ~2 KB | ~20 KB | ~100 KB |
| Parse time | < 1ms | ~5ms | ~25ms |
| Memory | negligible | ~200 KB | ~1 MB |
| Timeline chips | scrollable | scrollable, may need virtualization | need sampling/condensing |
| Diff computation | instant | instant | ~50ms (LCS caps at 200) |
| Animation smoothness | 60fps | 60fps | 60fps (only 2 events compared at a time) |

### Step Count Limits

The existing `DataJourneyInteractor.maxSteps = 40` truncates at 40 steps. For step-by-step visualization:

- **Short algorithms** (two sum, binary search): 5-20 steps. No issue.
- **Medium algorithms** (sorting small arrays): 20-80 steps. May need to raise limit to 100.
- **Long algorithms** (DP table filling, BFS on large graph): 200+ steps. Need adaptive sampling.

**Recommendation:** Make `maxSteps` configurable per problem. Store the recommended max in the step trace JSON:

```json
{
  "slug": "bubble-sort",
  "maxDisplaySteps": 100,
  "testTraces": { ... }
}
```

### Timeline UI for Many Steps

With 100+ steps, individual timeline chips become impractical. Two approaches:

1. **Scrubber slider** (replace chips): A continuous slider from step 0 to step N. Already partially supported by the step counter text.

2. **Condensed chips with expansion**: Show every 10th step as a chip, with expand-on-demand. More complex but more interactive.

**Recommendation:** Start with the current chip UI (works up to ~30 steps). Add a slider alternative for problems with 30+ steps. This is a view-layer change only.

---

## 13. File Modifications Summary

### New Files (TestCaseEvaluator side)

| File | Purpose |
|------|---------|
| `Sources/LeetCodeHelpers/StepTracer.swift` | Step snapshot recorder |
| `Sources/LeetCodeHelpers/StepTraceExporter.swift` | JSON serialization for step traces |
| `Tests/*/modified solution files` | Solutions with optional tracer parameter |

### New Files (iOS app side)

| File | Purpose |
|------|---------|
| `DataJourney/Services/StepTraceBridge.swift` | Loads step trace JSON |
| `DataJourney/Services/PointerExtractor.swift` | Identifies pointer variables in events |

### Modified Files (iOS app side)

| File | Change |
|------|--------|
| `DataJourney/Services/DataJourneyPresenter.swift` | Add `hasStepData` flag, `loadStepTrace()` method |
| `Views/SolutionView.swift` | Try StepTraceBridge before falling back to TestResultBridge |
| `DataJourney/Views/DataJourneyView+Playback.swift` | Add slider mode for 30+ steps (optional enhancement) |

### Unchanged Files

Everything else. The diff, structure resolution, animation controller, interactor, models, and all existing views continue to work without modification.

---

## Sources

- Codebase analysis: All source files in `CodeBench/CodeBench/DataJourney/` (14 view files, 5 service files, 5 model files)
- Codebase analysis: `TestCaseEvaluator/` (Package.swift, LeetCodeHelpers, sample test files)
- Codebase analysis: `.planning/codebase/ARCHITECTURE.md`, `CONCERNS.md`, `STRUCTURE.md`
- SwiftUI animation patterns: `withAnimation`, `matchedGeometryEffect`, `@Observable` reactivity (training data, MEDIUM confidence)
- State machine design: Based on existing `DataJourneyAnimationController` implementation (HIGH confidence, directly observed)

**Confidence notes:**
- Architecture recommendations: HIGH -- based on direct codebase analysis, no external claims
- SwiftUI animation details (`matchedGeometryEffect` for element transitions): MEDIUM -- standard SwiftUI API but not verified against iOS 26 specifically
- Step count performance estimates: MEDIUM -- based on general JSON parsing benchmarks, not profiled in this codebase

---

*Architecture research: 2026-02-24*
