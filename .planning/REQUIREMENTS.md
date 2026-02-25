# Requirements — CodeBench v1

**Scoped:** 2026-02-24
**Source:** PROJECT.md + domain research + user scoping session

## v1 Scope Summary

15 requirements across 4 categories. The core focus is closing the trace data pipeline gap (the visualization framework is mostly built) and completing test validation coverage across all 18 topics.

---

## Foundation & Infrastructure

### REQ-F01: Fix Graph Node Identity
**Priority:** P0 — Blocks animation work
**Description:** Replace `UUID()` identity in `GraphLayout.Node` with stable semantic IDs (node index). Currently, every layout recalculation produces new identities, causing SwiftUI to destroy and recreate nodes instead of animating them.
**Acceptance:** Graph nodes animate position changes smoothly during step playback. No identity-based flickering.
**Files:** `DataJourney/Views/DataJourneyGraphView.swift`

### REQ-F02: Memoize Layout Computation
**Priority:** P0 — Blocks animation work
**Description:** Move layout computation (TraceTreeLayout, GraphLayout) out of SwiftUI `body`. Currently runs 50-iteration force simulations on every render. Cache layout results and only recompute when underlying data (adjacency, node count) changes.
**Acceptance:** Layout computed once per data change, not per render. Playback maintains 60fps on step transitions.
**Files:** `DataJourney/Views/DataJourneyTreeGraphView.swift`, `DataJourney/Views/DataJourneyGraphView.swift`

### REQ-F03: Build StepTracer API
**Priority:** P0 — Critical path
**Description:** New component in `TestCaseEvaluator/Sources/LeetCodeHelpers/` that captures algorithm state snapshots during test execution. Solutions call `tracer.step(line:label:values:)` to record intermediate states. Optional parameter pattern: `func twoSum(_ nums: [Int], _ target: Int, tracer: StepTracer? = nil)` — zero overhead when nil.
**Acceptance:** StepTracer records snapshots with line number, label, and arbitrary key-value state. Produces serializable step sequence.
**Files:** `TestCaseEvaluator/Sources/LeetCodeHelpers/StepTracer.swift`

### REQ-F04: Build StepTraceExporter
**Priority:** P0 — Critical path
**Description:** Serializes StepTracer output to per-problem JSON files. Versioned schema with step events that match `DataJourneyEvent` format (kind: .step, line, label, values dictionary).
**Acceptance:** Produces well-formed JSON files loadable by StepTraceBridge. Schema version field present.
**Files:** `TestCaseEvaluator/Sources/LeetCodeHelpers/StepTraceExporter.swift`

### REQ-F05: Build StepTraceBridge
**Priority:** P0 — Critical path
**Description:** iOS-side component that loads per-problem step trace JSON on-demand and produces `[DataJourneyEvent]`. Falls back to existing `TestResultBridge` for problems without step data. Extends `DataJourneyPresenter` with `hasStepData` flag and `loadStepTrace()` method.
**Acceptance:** Problems with step traces show full step-by-step playback. Problems without step traces show existing 3-event static view unchanged.
**Files:** `DataJourney/Services/StepTraceBridge.swift`, `DataJourney/Services/DataJourneyPresenter.swift`

### REQ-F06: Build PointerExtractor
**Priority:** P1
**Description:** Identifies pointer variables from step event values using name heuristics (i, j, left, right, lo, hi, mid, slow, fast, etc.). Enables automatic pointer visualization on step data without manual annotation.
**Acceptance:** Pointer variables auto-detected and displayed with motion arcs during playback for array and linked list problems.
**Files:** `DataJourney/Services/PointerExtractor.swift`

---

## Test Validation

### REQ-V01: Per-Problem Comparison Strategies
**Priority:** P0 — Blocks 16 topics
**Description:** Replace strict string equality (`computedOutput == expectedOutput`) with per-problem comparison strategies. Types: `exactMatch` (default), `sortedMatch` (order-independent arrays), `floatMatch` (epsilon tolerance), `treeMatch` (trailing null handling), `setMatch` (set equality), `multiAnswer` (any valid answer accepted). The existing `orderMatters` flag should be wired to actual comparison logic.
**Acceptance:** Each problem specifies its comparison strategy. False failures eliminated for order-independent, floating-point, and multiple-valid-answer problems.
**Files:** `TestCaseEvaluator/Sources/LeetCodeHelpers/ComparisonStrategy.swift`, `TestCaseEvaluator/Sources/LeetCodeHelpers/ResultRecorder.swift`

### REQ-V02: Validate All 18 Topics
**Priority:** P0
**Description:** Run TestCaseEvaluator for the remaining 16 topics (backtracking, binary-search, bit-manipulation, dynamic-programming, graphs, greedy, heap-priority-queue, linked-list, math-geometry, misc, sliding-window, stack, trees, tries, two-pointers) with proper comparison strategies. Produce complete validated test result JSON files for all topics.
**Acceptance:** All 18 topics have validated test results in `Resources/`. Match rates reflect actual correctness with appropriate comparison strategies.
**Files:** `TestCaseEvaluator/Tests/` (all 16 remaining topic directories), `CodeBench/CodeBench/Resources/`

### REQ-V03: Fix InputParser Edge Cases
**Priority:** P1
**Description:** Fix topic-specific input parsing failures. Known issues: graph adjacency list formats, backtracking constraint parsing, tree serialization with trailing nulls, linked list cycle notation. Each topic may need specialized parsing paths.
**Acceptance:** InputParser correctly handles all input formats across 18 topics without falling back to `.string(trimmed)` for parseable data.
**Files:** `TestCaseEvaluator/Sources/LeetCodeHelpers/InputParser.swift`

---

## Visualization & Content

### REQ-VZ01: Author Traces for 10 Core Problems
**Priority:** P0 — Validates pipeline
**Description:** Create step trace data for 10 representative problems (one per major algorithm pattern):
1. **Arrays/Hashing:** Two Sum (hash map lookups)
2. **Binary Search:** Search in Rotated Sorted Array (pointer movement)
3. **Sliding Window:** Best Time to Buy and Sell Stock
4. **Two Pointers:** Valid Palindrome
5. **Stack:** Valid Parentheses (push/pop operations)
6. **Linked List:** Reverse Linked List (pointer rewiring)
7. **Trees:** Invert Binary Tree (traversal order)
8. **Graphs:** Number of Islands (BFS/DFS visited nodes)
9. **Dynamic Programming:** Climbing Stairs (table fill)
10. **Backtracking:** Subsets (decision tree)

Step granularity target: 20-50 steps per visualization. Use semantic granularity (per-pass for sorting, per-node for traversals).
**Acceptance:** All 10 traces load in app, playback works with correct diffs and pointer tracking. End-to-end pipeline validated.
**Files:** `TestCaseEvaluator/Tests/` (modified solution files), step trace JSON files

### REQ-VZ02: Reingold-Tilford Tree Layout
**Priority:** P1
**Description:** Replace current heap-index-based tree layout (which allocates 2^depth positions per level, causing width explosion for depth 6+ trees) with Reingold-Tilford algorithm that sizes based on actual subtree width.
**Acceptance:** Deep trees (depth 8+) render without horizontal overflow. Compact layout for unbalanced trees.
**Files:** `DataJourney/Views/DataJourneyTreeGraphView.swift`

### REQ-VZ03: Full Source Code Display
**Priority:** P1
**Description:** Expand current 3-line code context window to full source code display with syntax highlighting and scroll-to-line on step transitions. Code-to-visualization sync: current step highlights the corresponding source line.
**Acceptance:** Full solution source visible during step playback. Active line highlighted and auto-scrolled into view.
**Files:** `DataJourney/Views/` (new or modified code display component)

### REQ-VZ04: Animation Polish (matchedGeometryEffect + PhaseAnimator)
**Priority:** P2
**Description:** Add `matchedGeometryEffect` for smooth element repositioning during structural changes (array swaps, tree rotations, list pointer rewiring). Add `PhaseAnimator` for micro-animations within steps (comparison highlight pulses, visited-node flashes).
**Acceptance:** Array element swaps animate smoothly. Tree node insertions/deletions transition without jump-cuts. Comparison operations pulse briefly before resolving.
**Files:** `DataJourney/Views/` (multiple visualization components)

---

## Study Workflow

### REQ-S01: Progress Tracking
**Priority:** P2
**Description:** Track which problems the user has reviewed, with completion state per topic. Persistent across app launches. Simple local storage (UserDefaults or JSON file).
**Acceptance:** Topics show review progress. Problems show reviewed/not-reviewed state. Progress persists across launches.
**Files:** New persistence service, updated `TopicBrowseView.swift`, `ProblemBrowseView.swift`

### REQ-S02: Difficulty Tagging
**Priority:** P2
**Description:** User can tag any problem with personal difficulty rating (easy/medium/hard). Displayed in problem browse view. Filterable.
**Acceptance:** Difficulty tags visible in problem list. Tags persist across launches. Optional filter by difficulty.
**Files:** New persistence service (shared with REQ-S01), updated `ProblemBrowseView.swift`

---

## Out of Scope (v2+)

- Step bookmarks with personal notes
- Spaced repetition scheduling
- Side-by-side approach comparison visualization
- Custom input creation (user enters own test inputs)
- Offline trace generator tool (automates trace authoring)
- User-written code execution
- App Store distribution
- Network features
- Swap/insertion micro-animations (beyond matchedGeometryEffect)

---

## Priority Summary

| Priority | Count | Requirements |
|----------|-------|-------------|
| P0 | 8 | REQ-F01, F02, F03, F04, F05, REQ-V01, V02, REQ-VZ01 |
| P1 | 4 | REQ-F06, REQ-V03, REQ-VZ02, REQ-VZ03 |
| P2 | 3 | REQ-VZ04, REQ-S01, REQ-S02 |

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| REQ-F01 | Phase 1: Foundation Bug Fixes | Complete |
| REQ-F02 | Phase 1: Foundation Bug Fixes | Complete |
| REQ-F03 | Phase 2: Trace Pipeline (macOS) | Pending |
| REQ-F04 | Phase 2: Trace Pipeline (macOS) | Pending |
| REQ-F05 | Phase 3: Trace Pipeline (iOS) + Bridge | Pending |
| REQ-V01 | Phase 4: Comparison Strategies | Pending |
| REQ-VZ01 | Phase 5: Trace Authoring | Pending |
| REQ-V02 | Phase 6: Test Validation Coverage | Pending |
| REQ-V03 | Phase 6: Test Validation Coverage | Pending |
| REQ-F06 | Phase 7: Playback Enhancements | Pending |
| REQ-VZ03 | Phase 7: Playback Enhancements | Pending |
| REQ-VZ02 | Phase 8: Visual Polish and Study Workflow | Pending |
| REQ-VZ04 | Phase 8: Visual Polish and Study Workflow | Pending |
| REQ-S01 | Phase 8: Visual Polish and Study Workflow | Pending |
| REQ-S02 | Phase 8: Visual Polish and Study Workflow | Pending |

---
*Requirements defined: 2026-02-24*
*Traceability added: 2026-02-24*
