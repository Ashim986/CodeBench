# Project Research Summary

**Project:** CodeBench
**Domain:** iOS DSA study app with step-by-step algorithm visualization
**Researched:** 2026-02-24
**Confidence:** HIGH

## Executive Summary

CodeBench's visualization layer is substantially more complete than initially expected. The DataJourney framework already supports 14 data structure types, step-by-step playback with play/pause/speed controls, diff-based highlighting, pointer motion arcs, variable timeline sparklines, and keyboard shortcuts. All table-stakes features for a DSA visualization tool are built. The critical gap is not visualization -- it is the **trace data pipeline**. No mechanism exists to produce the `[DataJourneyEvent]` step sequences that the visualization framework consumes. Solutions exist as pre-built code strings, but nothing executes them to generate intermediate algorithm states. Closing this pipeline gap unlocks all existing visualization features with zero new visualization code.

The recommended approach is to pre-compute trace data offline in the TestCaseEvaluator (macOS-side), embed `Trace.step()` calls in solution code, export step events as per-problem JSON files, and load them lazily on the iOS side via a new `StepTraceBridge`. The existing `DataJourneyEvent` schema requires no changes -- it already supports the `.step` kind, `line` numbers, labels, and arbitrary `TraceValue` dictionaries. The `DataJourneyPresenter` and `DataJourneyAnimationController` work with N events out of the box. This is a data problem, not an architecture problem.

The top risks are: (1) SwiftUI view identity instability from `UUID()` in layout nodes, which already causes broken animations and must be fixed before any animation polish work; (2) layout recalculation inside `body` running 50-iteration force simulations on every render, which will tank frame rates during step playback; (3) step count explosion for O(n^2) algorithms overwhelming the UI and memory; and (4) test validation false failures from strict string equality comparison blocking 16 of 18 topics. All four are addressable with known solutions and should be tackled early.

## Key Findings

### Recommended Stack

Zero external dependencies. The entire visualization stack is custom SwiftUI, and this is the correct choice -- the Swift ecosystem has no meaningful DSA visualization libraries. CodeBench already has more sophisticated visualization than any available open-source option.

**Core technologies:**
- **SwiftUI (iOS 26+):** UI framework with first-class animation support -- already in use, no change needed
- **Swift Canvas (iOS 15+):** Edge/path rendering for non-interactive elements (arrows, curves, grid lines) -- already in use, hybrid approach with SwiftUI views for nodes is optimal
- **`withAnimation` + state changes:** Primary animation mechanism for step transitions -- already implemented correctly
- **`matchedGeometryEffect` (iOS 14+):** Needed for smooth node repositioning during structural changes (insertions, deletions, tree rotations) -- not yet used, should be added
- **`PhaseAnimator` / `KeyframeAnimator` (iOS 17+):** For micro-animations within steps (comparison pulses, swap arcs) -- not yet used, add as polish layer
- **No external libraries:** No SwiftGraph, no Lottie, no SpriteKit, no D3.js-via-WKWebView -- the custom framework is better than all alternatives

### Expected Features

**Must have (table stakes) -- ALL DONE:**
- Step forward/back, play/pause, speed control
- Array/tree/graph/linked list visualization with indices, edges, pointers
- Diff highlighting (what changed between steps)
- Code-to-visualization sync (3-line context window exists, needs line data from traces)
- Pointer/variable tracking with automatic detection of i, j, left, right, lo, hi, etc.

**Should have (differentiators) -- MOSTLY DONE:**
- Variable timeline sparklines (DONE, unique to CodeBench)
- Pointer motion curves showing FROM and TO between steps (DONE)
- Auto structure detection from trace data (DONE)
- Per-element change classification via LCS-based diffing (DONE)
- Combined linked list view for merge problems (DONE)
- Progress tracking and difficulty tagging (NOT BUILT, low complexity)

**Defer (v2+):**
- Swap/insertion animations (state snapshots are sufficient for learning)
- Side-by-side approach comparison visualization
- Spaced repetition scheduling
- Custom input creation
- Offline trace generator tool (automates what v1 does manually)

**The real gap: Trace Data Pipeline.** The visualization framework consumes events but nothing produces them. Approach A (pre-computed traces in JSON, authored alongside solutions) is the only viable v1 strategy. Zero runtime complexity, perfectly controlled data quality, incrementally authorable.

### Architecture Approach

The existing MVVM + DataJourney architecture requires minimal extension, not a rewrite. The `DataJourneyPresenter` needs one new flag (`hasStepData`) and one new method (`loadStepTrace()`). A new `StepTraceBridge` loads per-problem JSON and falls back to the existing `TestResultBridge` for problems without step data. The `DataJourneyAnimationController`, `DataJourneyInteractor`, `StructureResolver`, and `TraceValueDiff` modules are all unchanged.

**Major new components:**
1. **StepTracer** (TestCaseEvaluator/LeetCodeHelpers) -- captures algorithm state snapshots during test execution
2. **StepTraceExporter** (TestCaseEvaluator/LeetCodeHelpers) -- serializes step data to per-problem JSON files
3. **StepTraceBridge** (iOS DataJourney/Services) -- loads step trace JSON on-demand, produces `[DataJourneyEvent]`
4. **PointerExtractor** (iOS DataJourney/Services) -- identifies pointer variables from step event values using name heuristics

**Key patterns:**
- Bridge pattern: both `StepTraceBridge` and `TestResultBridge` produce `[DataJourneyEvent]`, consumer does not care about source
- Optional tracer: `func twoSum(_ nums: [Int], _ target: Int, tracer: StepTracer? = nil)` -- zero overhead when nil
- Progressive data enhancement: ship with zero traces, add per-problem over time, graceful fallback to static view
- Separate storage: step traces in per-problem JSON files, loaded lazily, never bloating the test results

### Critical Pitfalls

1. **View identity instability (CRITICAL, ALREADY HAPPENING):** `GraphLayout.Node` uses `UUID()` for its `id`, so every layout recalculation produces entirely new identities. SwiftUI destroys and recreates nodes instead of animating them. Fix: use stable semantic IDs (node index for graphs, data model ID for trees).

2. **Layout recalculation in body (CRITICAL, ALREADY HAPPENING):** `TraceTreeLayout` and `GraphLayout` are initialized inside `body`, running O(n^2 * 50) force simulations on every render. Fix: memoize layout results, only recompute when adjacency changes.

3. **Step count explosion (CRITICAL, DESIGN-TIME):** O(n^2) algorithms on 100-element inputs produce 10,000+ steps. Fix: define semantic step granularity per topic (per-pass for sorting, per-row for DP, per-node for traversals). Keep steps at 30-60 per visualization.

4. **Test validation false failures (CRITICAL, BLOCKS 16 TOPICS):** Strict string equality comparison fails for order-independent results, floating-point values, multiple valid answers, and trailing nulls in tree serialization. Fix: implement per-problem comparison strategies (sortedMatch, floatMatch, treeMatch, setMatch) before running the remaining 16 topics.

5. **Tree width explosion (CRITICAL, UX):** Heap-index-based layout reserves 2^level positions, producing absurdly wide canvases for depth 6+ trees. Fix: switch to Reingold-Tilford layout that sizes based on actual subtree width.

## Architecture Readiness

**What exists and works well:**
- DataJourneyEvent model (supports step kind, line, label, arbitrary values)
- DataJourneyAnimationController (play/pause/speed/advance -- works with N events)
- DataJourneyPresenter (event management, selection, line highlighting)
- TraceValueDiff (LCS-based array diff, tree node diff, matrix cell diff, dictionary diff)
- StructureResolver (auto-detects arrays, trees, graphs, matrices, linked lists, tries)
- 14 data structure renderers (array, tree, graph, linked list, trie, heap, stack, queue, matrix, dictionary, set, string sequence, combined list, list array)
- Timeline chips, playback controls, keyboard shortcuts, PNG export, accessibility

**What is missing:**
- Trace data generation pipeline (StepTracer, StepTraceExporter)
- Step trace loading bridge (StepTraceBridge)
- Pointer extraction from step events (PointerExtractor)
- Per-problem comparison strategies for test validation
- Full source code display (currently 3-line window)

**What needs fixing before new work:**
- `GraphLayout.Node.id = UUID()` must become stable index-based ID
- Layout computation must move out of `body` into cached/memoized state
- `maxSteps = 40` must become configurable per problem
- `StructureResolver` heuristics need explicit type annotation support for step data

## Critical Risks

| Risk | Probability | Impact | When to Address |
|------|------------|--------|-----------------|
| Layout recalculation every render | Already happening | Frame drops during playback | Before any animation work |
| Graph node identity instability | Already happening | Broken animations | Before any animation work |
| Test validation false failures | Very high | Blocks 16 of 18 topics | Before topic validation push |
| Step count explosion | Very high | Memory/UI overflow | During trace pipeline design |
| Tree width explosion | High | Unusable on iPhone for deep trees | During tree animation work |
| Memory pressure from step snapshots | Medium | App crashes on older devices | Monitor continuously, lazy-load step data |
| StructureResolver misclassification | Medium | Wrong visualization shown | Add type annotations in step trace format |
| JSON schema backward compatibility | Medium | Rework risk | Prevent from the start (optional fields only) |

## Recommended Phase Ordering

### Phase 1: Foundation Fixes and Trace Pipeline Design

**Rationale:** The two "already happening" bugs (identity instability, layout-in-body) undermine all future animation work. The trace pipeline is the critical path -- everything else depends on having step data. Test validation comparison strategies unblock 16 topics of content.

**Delivers:**
- Fixed `GraphLayout.Node` identity (stable IDs)
- Memoized layout computation (out of `body`)
- `StepTracer` API in LeetCodeHelpers
- `StepTraceExporter` for JSON serialization
- Step trace JSON schema (versioned, per-problem files)
- `StepTraceBridge` on iOS side with fallback to `TestResultBridge`
- Per-problem comparison strategies for test validation
- Minimal presenter extension (`hasStepData`, `loadStepTrace()`)

**Addresses features:** Trace data pipeline (P0), wire trace loading (P0)
**Avoids pitfalls:** #1 (identity), #2 (layout recalc), #6 (test validation), #9 (schema evolution)

**Research flag:** Needs deeper research on comparison strategy edge cases per topic. The `orderMatters` flag exists but is unused -- mapping it to actual comparison logic requires per-topic analysis.

### Phase 2: Trace Authoring for Core Problems

**Rationale:** With the pipeline built, populate it. Start with 10 representative problems (one per major algorithm pattern) to validate the end-to-end flow. This is authoring work, not engineering work.

**Delivers:**
- Step traces for 10 problems spanning all major patterns:
  - Arrays: Two Sum (hash map), Binary Search (pointers)
  - Sliding Window: Best Time to Buy and Sell Stock or similar
  - Two Pointers: Valid Palindrome or similar
  - Stack: Valid Parentheses (push/pop)
  - Linked List: Reverse Linked List (pointer rewiring)
  - Trees: Invert Binary Tree (traversal)
  - Graphs: Number of Islands (BFS/DFS)
  - DP: Climbing Stairs or similar (table fill)
  - Backtracking: Subsets or similar (decision tree)
  - Greedy: Jump Game or similar
- End-to-end validation: trace JSON loaded in app, playback works, diffs highlight correctly

**Addresses features:** Trace data for key problems (P0)
**Avoids pitfalls:** #5 (step count explosion -- establish granularity rules here), #8 (StructureResolver misclassification -- test with real data)

**Research flag:** Standard patterns, no deep research needed. The trace API and JSON format are defined in Phase 1.

### Phase 3: Test Validation for Remaining 16 Topics

**Rationale:** Content coverage is essential for the app to be useful. With comparison strategies from Phase 1, validate all remaining topics. This can partially overlap with Phase 2.

**Delivers:**
- Validated test results for all 18 topics
- Comparison strategy metadata per problem
- InputParser fixes for topic-specific parsing edge cases

**Addresses features:** Complete test coverage
**Avoids pitfalls:** #6 (false failures), #12 (InputParser silent defaults)

**Research flag:** Needs per-topic research. Each of the 16 topics will have unique parsing and comparison challenges. Graphs, backtracking, and trees are highest risk.

### Phase 4: Visualization Polish and Animation Enhancements

**Rationale:** With step data flowing and content validated, polish the visual experience. This is where `matchedGeometryEffect`, `PhaseAnimator`, and `KeyframeAnimator` get added.

**Delivers:**
- `matchedGeometryEffect` on array/tree/list elements for smooth repositioning
- `PhaseAnimator` for comparison highlight pulses
- Full source code display (expand from 3-line window)
- Configurable `maxSteps` per problem
- Slider-based timeline for 30+ step visualizations
- Compact array rendering for 20+ elements
- Reingold-Tilford tree layout (replacing heap-index for wide trees)
- Graph layout caching and disconnected component handling

**Addresses features:** Full code display (P1), algorithm-specific step labels
**Avoids pitfalls:** #3 (tree width explosion), #4 (graph layout instability), #11 (Canvas performance), #13 (array readability)

**Research flag:** May need research on Reingold-Tilford implementation specifics in Swift. The algorithm is well-documented but Swift/SwiftUI-specific layout integration may have subtleties.

### Phase 5: Study Workflow Features

**Rationale:** Once visualization works end-to-end across all topics, add study-oriented features. These are independent of the visualization pipeline.

**Delivers:**
- Progress tracking (which problems reviewed, completion state)
- Problem difficulty tagging (personal easy/medium/hard)
- Step bookmarks with notes

**Addresses features:** Progress tracking (P1), difficulty tagging (P2), bookmarks (P2)
**Avoids pitfalls:** #17 (scope creep -- keep these simple, avoid over-engineering)

**Research flag:** Standard patterns, no deep research needed. Core Data or simple JSON persistence.

### Phase Ordering Rationale

- **Phase 1 before everything:** Identity and layout bugs are already present and will sabotage all animation work. The trace pipeline is the critical dependency for all content.
- **Phase 2 before Phase 3:** Authoring 10 traces validates the pipeline design before committing to 450 problems worth of content work.
- **Phase 3 can overlap Phase 2:** Test validation is independent of trace authoring -- different codepaths, different files.
- **Phase 4 after Phase 2:** Animation polish requires step data to test against. Without traces, you cannot verify that `matchedGeometryEffect` works correctly on real algorithm steps.
- **Phase 5 last:** Study features are additive and independent. They provide value only when there is content to study.

### Research Flags Summary

| Phase | Needs Research? | Reason |
|-------|----------------|--------|
| Phase 1 | YES -- comparison strategies | Per-topic comparison edge cases need analysis |
| Phase 2 | NO | Trace API defined in Phase 1, authoring is mechanical |
| Phase 3 | YES -- per-topic parsing | 16 topics with unique input formats and output comparison needs |
| Phase 4 | MAYBE -- Reingold-Tilford | Algorithm is standard but Swift/SwiftUI integration may need research |
| Phase 5 | NO | Standard persistence patterns |

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Entire recommendation is "keep what you have, add zero dependencies." Based on direct codebase analysis. iOS 26-specific claims are LOW confidence. |
| Features | HIGH | Feature inventory verified from code. Competitor analysis is MEDIUM (training data, no live verification). The trace pipeline gap finding is HIGH. |
| Architecture | HIGH | All architecture recommendations based on direct codebase analysis. The "minimal extension, not rewrite" conclusion is strongly supported. |
| Pitfalls | HIGH | Top pitfalls verified from code (UUID identity, layout-in-body). Phase warnings are well-grounded in established SwiftUI patterns. |

**Overall confidence:** HIGH

The research is unusually confident because the project is an extension of an existing codebase, not a greenfield build. Most findings come from direct code analysis rather than external sources.

### Gaps to Address

- **iOS 26 specifics:** Cannot verify iOS 26-specific features or performance characteristics. WWDC 2025 content not available. Build on iOS 17+ APIs which are stable.
- **Competitor current state:** VisuAlgo, Algorithm Visualizer, PythonTutor feature comparisons based on training data. May have evolved. Low impact -- CodeBench's differentiators are clear regardless.
- **Performance thresholds:** View count limits (~200 views in ZStack, ~500 for lag) are estimates, not profiled on target device. Profile during Phase 4.
- **Step trace file sizes at scale:** Estimates (2KB for 10 steps, 100KB for 500 steps) need validation with real data during Phase 2.
- **Reingold-Tilford in SwiftUI:** Standard algorithm but no verified Swift implementation was found. May need to build from scratch in Phase 4.

## Per-Dimension Summaries

### STACK.md Summary

The existing tech stack is correct and needs no changes. SwiftUI + Canvas hybrid rendering, `withAnimation` for step transitions, custom layout algorithms (Fruchterman-Reingold, heap-indexed BFS, recursive subtree-width) are all well-implemented. The key additions are `matchedGeometryEffect` for element repositioning, `PhaseAnimator`/`KeyframeAnimator` for micro-animations, and layout memoization for performance. Zero external dependencies -- this is intentional and should remain so.

### FEATURES.md Summary

All table-stakes features are built. The visualization framework supports 14 data structure types with pointer tracking, diff highlighting, pointer motion arcs, variable timelines, and code context. The critical missing feature is the trace data pipeline -- the bridge between solution code and `DataJourneyEvent` sequences. Recommended approach: pre-computed JSON traces authored alongside solutions, loaded lazily per-problem. Study workflow features (progress, bookmarks, difficulty tags) are low-complexity additions for later phases.

### ARCHITECTURE.md Summary

The architecture needs extension, not rewrite. `DataJourneyEvent` schema already supports step data. `DataJourneyPresenter` and `DataJourneyAnimationController` handle N events. New components: `StepTracer` (macOS-side snapshot recorder), `StepTraceExporter` (JSON writer), `StepTraceBridge` (iOS-side loader with fallback), `PointerExtractor` (pointer variable detection). The design preserves full backward compatibility -- problems without step traces continue to work via the existing `TestResultBridge`. Step traces are stored in separate per-problem JSON files, loaded on-demand.

### PITFALLS.md Summary

Six critical pitfalls identified, two already present in the codebase. The UUID-based identity in `GraphLayout.Node` and layout computation inside `body` are actively causing broken animations and frame drops. Test validation false failures from strict string comparison will block 16 topics. Step count explosion is the biggest design-time risk for the trace pipeline. Tree width explosion and graph layout instability are UX risks for specific data structure categories. All have known, well-documented solutions.

## Sources

### Primary (HIGH confidence)
- Direct codebase analysis: all 40+ Swift files in DataJourney framework, TestCaseEvaluator package, solution JSON files
- Existing planning docs: `.planning/codebase/ARCHITECTURE.md`, `CONCERNS.md`, `STRUCTURE.md`, `TESTING.md`

### Secondary (MEDIUM confidence)
- Apple SwiftUI Animation APIs (PhaseAnimator, KeyframeAnimator, matchedGeometryEffect): established APIs through iOS 18, training data
- Fruchterman-Reingold and Reingold-Tilford algorithms: published academic references
- SwiftUI performance characteristics: Apple WWDC sessions 2021-2024, community benchmarks
- Competitor feature analysis: VisuAlgo, Algorithm Visualizer, PythonTutor (training data knowledge)

### Tertiary (LOW confidence)
- iOS 26 projections: cannot verify, flagged for post-WWDC validation
- Performance threshold numbers (200 views, 500 views): estimates needing device profiling
- Bundle size projections: estimates needing validation with real trace data

---
*Research completed: 2026-02-24*
*Ready for roadmap: yes*
