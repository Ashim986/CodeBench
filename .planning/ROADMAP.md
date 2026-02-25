# Roadmap: CodeBench v1

## Overview

CodeBench's visualization framework is substantially built (14 renderers, playback controls, diff highlighting), but nothing produces the step event data it consumes. The critical path is closing the trace data pipeline, then populating it with content. Two active bugs (UUID identity, layout-in-body) must be fixed before any animation work. Test validation coverage must expand from 2/18 topics to 18/18. After the pipeline flows and content exists, polish the visualization experience and add study workflow features.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation Bug Fixes** - Fix UUID identity instability and layout-in-body performance bugs that block all animation work
- [ ] **Phase 2: Trace Pipeline (macOS)** - Build StepTracer and StepTraceExporter to capture and serialize algorithm state snapshots
- [ ] **Phase 3: Trace Pipeline (iOS) + Bridge** - Build StepTraceBridge to load step data into the visualization framework with graceful fallback
- [ ] **Phase 4: Comparison Strategies** - Implement per-problem comparison logic to eliminate false test failures across all output formats
- [ ] **Phase 5: Trace Authoring** - Author step traces for 10 core problems spanning all major algorithm patterns, validating end-to-end pipeline
- [ ] **Phase 6: Test Validation Coverage** - Validate all 18 topics with correct comparison strategies and fix InputParser edge cases
- [ ] **Phase 7: Playback Enhancements** - Add pointer extraction, full source code display, and code-to-visualization sync
- [ ] **Phase 8: Visual Polish and Study Workflow** - Reingold-Tilford tree layout, animation polish, progress tracking, and difficulty tagging

## Phase Details

### Phase 1: Foundation Bug Fixes
**Goal**: The visualization framework renders and animates correctly -- no identity flickering, no frame drops from redundant layout computation
**Depends on**: Nothing (first phase)
**Requirements**: REQ-F01, REQ-F02
**Research**: NO -- bugs are identified, fixes are known patterns (stable IDs, memoization)
**Success Criteria** (what must be TRUE):
  1. Graph nodes animate position changes smoothly during step playback with no identity-based flickering or node destruction/recreation
  2. Layout computation runs once per data change, not on every SwiftUI render cycle
  3. Step playback maintains 60fps on graph and tree visualizations (no force simulation in body)
**Plans**: 5 plans

Plans:
- [ ] 01-01-PLAN.md -- Infrastructure: Add LeetPulseDesignSystem SPM dependency, delete DesignTokens.swift shim, remove TestCaseEvaluator/CodeBench duplicate
- [ ] 01-02-PLAN.md -- Core Bug Fixes: Replace all UUID() identity with stable composite IDs, memoize layout computation in Graph/Tree/Trie views, enforce 40-node truncation limit
- [ ] 01-03-PLAN.md -- DS Token Sweep (Part 1): Replace hardcoded styling in graph/tree/trie/canvas/heap/matrix/bubble views (14 files)
- [ ] 01-04-PLAN.md -- DS Token Sweep (Part 2): Replace hardcoded styling in sequence/string/dictionary/timeline/main views (12 files)
- [ ] 01-05-PLAN.md -- Verification: Debug test harness with rapid step transitions, SwiftLint UUID regression guard, grep-based styling audit, visual human verification

### Phase 2: Trace Pipeline (macOS)
**Goal**: Algorithm solutions can record intermediate state snapshots that serialize to well-formed JSON files
**Depends on**: Nothing (independent of Phase 1, but sequenced for focus)
**Requirements**: REQ-F03, REQ-F04
**Research**: YES -- step trace JSON schema design, step granularity rules per algorithm pattern, versioning strategy
**Success Criteria** (what must be TRUE):
  1. A solution function instrumented with StepTracer records snapshots with line number, label, and arbitrary key-value state via tracer.step(line:label:values:)
  2. Uninstrumented solutions (tracer: nil) execute with zero overhead -- no performance regression
  3. StepTraceExporter produces per-problem JSON files with versioned schema containing step events matching DataJourneyEvent format
  4. Exported JSON is valid, parseable, and contains correct step sequences for a manually verified test case
**Plans**: 6 plans

Plans:
- [ ] 02-01: Research step trace schema design -- field mapping to DataJourneyEvent, versioning, granularity rules
- [ ] 02-02: Implement StepTracer API with optional parameter pattern in LeetCodeHelpers
- [ ] 02-03: Implement StepTraceExporter for JSON serialization with schema version field
- [ ] 02-04: Define step granularity guidelines per algorithm pattern (per-pass, per-node, per-row)
- [ ] 02-05: Instrument one solution (Two Sum) as proof-of-concept and validate exported JSON
- [ ] 02-06: Verify zero-overhead path when tracer is nil

### Phase 3: Trace Pipeline (iOS) + Bridge
**Goal**: The iOS app loads step trace data on-demand and feeds it into the existing visualization framework, with graceful fallback for problems without traces
**Depends on**: Phase 2 (needs JSON schema to implement loader)
**Requirements**: REQ-F05
**Research**: NO -- architecture documented in research, minimal extension to existing DataJourneyPresenter
**Success Criteria** (what must be TRUE):
  1. Problems with step trace JSON files show full step-by-step playback with all existing visualization features (diff highlighting, timeline, playback controls)
  2. Problems without step trace files continue to show the existing 3-event static view unchanged -- no regression
  3. DataJourneyPresenter exposes hasStepData flag so UI can indicate step data availability
  4. Step trace JSON is loaded lazily (on-demand when user opens visualization, not at app launch)
**Plans**: 5 plans

Plans:
- [ ] 03-01: Implement StepTraceBridge that loads per-problem JSON and produces [DataJourneyEvent]
- [ ] 03-02: Extend DataJourneyPresenter with hasStepData flag and loadStepTrace() method
- [ ] 03-03: Implement fallback logic -- StepTraceBridge defers to TestResultBridge when no step data exists
- [ ] 03-04: Wire step trace loading into the visualization view layer
- [ ] 03-05: End-to-end test -- load the Two Sum trace from Phase 2 in the app, verify playback works

### Phase 4: Comparison Strategies
**Goal**: Test case evaluation uses correct comparison logic per problem, eliminating false failures from strict string equality
**Depends on**: Nothing (independent of trace pipeline, but sequenced to unblock Phase 6)
**Requirements**: REQ-V01
**Research**: YES -- per-topic comparison edge cases, mapping existing orderMatters flag to comparison logic, identifying which problems need which strategy
**Success Criteria** (what must be TRUE):
  1. Each problem specifies a comparison strategy (exactMatch, sortedMatch, floatMatch, treeMatch, setMatch, or multiAnswer)
  2. The existing orderMatters flag is wired to actual comparison logic (not ignored as it is now)
  3. Previously failing test cases that produce correct-but-differently-ordered output now pass
  4. No regressions in the 2 already-validated topics (arrays-hashing, intervals)
**Plans**: 6 plans

Plans:
- [ ] 04-01: Research per-topic comparison needs -- catalog which problems need which strategy
- [ ] 04-02: Implement ComparisonStrategy enum with all 6 strategy types
- [ ] 04-03: Wire comparison strategies into ResultRecorder replacing strict string equality
- [ ] 04-04: Map existing orderMatters flag to sortedMatch strategy
- [ ] 04-05: Create per-problem comparison strategy metadata (default + overrides)
- [ ] 04-06: Re-validate arrays-hashing and intervals topics to confirm no regressions

### Phase 5: Trace Authoring
**Goal**: 10 representative problems have authored step traces that load and play back correctly in the app, validating the end-to-end pipeline across all major algorithm patterns
**Depends on**: Phase 2, Phase 3 (needs pipeline built and bridge connected)
**Requirements**: REQ-VZ01
**Research**: NO -- trace API and JSON format defined in Phase 2, authoring is mechanical per-problem work
**Success Criteria** (what must be TRUE):
  1. All 10 traces load in the app and play back with correct step-by-step diff highlighting
  2. Each trace has 20-50 steps at semantic granularity (per-pass for sorting, per-node for traversals, per-row for DP)
  3. Pointer tracking works for problems that use index variables (binary search, two pointers, sliding window)
  4. Tree, graph, and linked list visualizations render correctly with step data (not just arrays)
  5. The trace authoring workflow is documented so future problems can be traced using the same pattern
**Plans**: 7 plans

Plans:
- [ ] 05-01: Author traces for array/hash problems -- Two Sum (hash map lookups)
- [ ] 05-02: Author traces for pointer-based problems -- Binary Search, Valid Palindrome (two pointers), Best Time to Buy/Sell Stock (sliding window)
- [ ] 05-03: Author trace for stack problem -- Valid Parentheses (push/pop operations)
- [ ] 05-04: Author trace for linked list problem -- Reverse Linked List (pointer rewiring)
- [ ] 05-05: Author traces for tree/graph problems -- Invert Binary Tree (traversal), Number of Islands (BFS/DFS)
- [ ] 05-06: Author traces for DP/backtracking problems -- Climbing Stairs (table fill), Subsets (decision tree)
- [ ] 05-07: End-to-end validation of all 10 traces in app -- verify playback, diffs, pointer tracking across all data structure types

### Phase 6: Test Validation Coverage
**Goal**: All 18 topics have validated test results with correct comparison strategies, and InputParser handles all input formats
**Depends on**: Phase 4 (needs comparison strategies to avoid false failures)
**Requirements**: REQ-V02, REQ-V03
**Research**: YES -- per-topic input parsing challenges (graph adjacency lists, tree serialization, backtracking constraints, linked list cycles)
**Success Criteria** (what must be TRUE):
  1. All 18 topics have validated test result JSON files in Resources/
  2. Match rates reflect actual solution correctness (no false failures from comparison or parsing)
  3. InputParser correctly handles all input formats without falling back to .string(trimmed) for parseable data
  4. Graph adjacency list, tree serialization with trailing nulls, linked list cycle notation, and backtracking constraint formats all parse correctly
**Plans**: 8 plans

Plans:
- [ ] 06-01: Research per-topic parsing challenges -- catalog input formats and known failures for all 16 remaining topics
- [ ] 06-02: Fix InputParser for graph-related topics (graphs, trees, tries)
- [ ] 06-03: Fix InputParser for linear structure topics (linked-list, stack, queue)
- [ ] 06-04: Fix InputParser for numeric/logic topics (binary-search, bit-manipulation, math-geometry, dynamic-programming)
- [ ] 06-05: Validate batch 1 -- backtracking, binary-search, bit-manipulation, dynamic-programming
- [ ] 06-06: Validate batch 2 -- graphs, greedy, heap-priority-queue, linked-list
- [ ] 06-07: Validate batch 3 -- math-geometry, misc, sliding-window, stack, trees, tries, two-pointers
- [ ] 06-08: Final sweep -- verify all 18 topics present in Resources/, spot-check match rates

### Phase 7: Playback Enhancements
**Goal**: Step playback shows automatic pointer visualization and full source code with line-by-line sync to the visualization
**Depends on**: Phase 5 (needs step traces with real data to test pointer extraction and code sync)
**Requirements**: REQ-F06, REQ-VZ03
**Research**: NO -- PointerExtractor uses name heuristics (documented), code display is a SwiftUI view expansion
**Success Criteria** (what must be TRUE):
  1. Pointer variables (i, j, left, right, lo, hi, mid, slow, fast) are auto-detected from step event values without manual annotation
  2. Pointer positions display with motion arcs during playback for array and linked list problems
  3. Full solution source code is visible during step playback (not just the current 3-line window)
  4. The active source line is highlighted and auto-scrolled into view on each step transition
**Plans**: 6 plans

Plans:
- [ ] 07-01: Implement PointerExtractor with name heuristics for common pointer variable patterns
- [ ] 07-02: Wire PointerExtractor output into existing pointer motion arc rendering
- [ ] 07-03: Test pointer detection on all 10 authored traces -- verify correct identification
- [ ] 07-04: Build full source code display view with syntax highlighting
- [ ] 07-05: Implement scroll-to-line behavior on step transitions with active line highlighting
- [ ] 07-06: Integration test -- verify code-to-visualization sync across array, tree, and graph problems

### Phase 8: Visual Polish and Study Workflow
**Goal**: Tree visualization handles deep trees compactly, animations are smooth for structural changes, and users can track their study progress
**Depends on**: Phase 5 (needs step traces for animation testing), Phase 6 (needs all topics for progress tracking to be meaningful)
**Requirements**: REQ-VZ02, REQ-VZ04, REQ-S01, REQ-S02
**Research**: MAYBE -- Reingold-Tilford algorithm is well-documented but Swift/SwiftUI layout integration may need research
**Success Criteria** (what must be TRUE):
  1. Deep trees (depth 8+) render without horizontal overflow using Reingold-Tilford layout
  2. Unbalanced trees display compactly (no wasted space from heap-index positioning)
  3. Array element swaps animate smoothly via matchedGeometryEffect (no jump-cuts)
  4. Tree node insertions/deletions transition smoothly; comparison operations pulse briefly via PhaseAnimator
  5. Topics show review progress (how many problems reviewed out of total)
  6. Problems show reviewed/not-reviewed state that persists across app launches
  7. User can tag any problem with personal difficulty (easy/medium/hard) and filter by difficulty
**Plans**: 8 plans

Plans:
- [ ] 08-01: Research and implement Reingold-Tilford tree layout algorithm in Swift
- [ ] 08-02: Replace heap-index layout with Reingold-Tilford in DataJourneyTreeGraphView
- [ ] 08-03: Add matchedGeometryEffect for array element repositioning during structural changes
- [ ] 08-04: Add matchedGeometryEffect for tree/list node repositioning
- [ ] 08-05: Add PhaseAnimator for micro-animations (comparison pulses, visited-node flashes)
- [ ] 08-06: Build persistence service for progress tracking and difficulty tags (UserDefaults or JSON)
- [ ] 08-07: Wire progress tracking into TopicBrowseView and ProblemBrowseView
- [ ] 08-08: Wire difficulty tagging into ProblemBrowseView with filter support

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8

Note: Phases 1 and 4 are independent and could theoretically run in parallel. Phases 2 and 4 are also independent. However, sequential execution is recommended for solo development focus.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation Bug Fixes | 0/5 | Planned | - |
| 2. Trace Pipeline (macOS) | 0/6 | Not started | - |
| 3. Trace Pipeline (iOS) + Bridge | 0/5 | Not started | - |
| 4. Comparison Strategies | 0/6 | Not started | - |
| 5. Trace Authoring | 0/7 | Not started | - |
| 6. Test Validation Coverage | 0/8 | Not started | - |
| 7. Playback Enhancements | 0/6 | Not started | - |
| 8. Visual Polish and Study Workflow | 0/8 | Not started | - |

## Coverage

| Requirement | Phase | Status |
|-------------|-------|--------|
| REQ-F01 | Phase 1 | Pending |
| REQ-F02 | Phase 1 | Pending |
| REQ-F03 | Phase 2 | Pending |
| REQ-F04 | Phase 2 | Pending |
| REQ-F05 | Phase 3 | Pending |
| REQ-V01 | Phase 4 | Pending |
| REQ-VZ01 | Phase 5 | Pending |
| REQ-V02 | Phase 6 | Pending |
| REQ-V03 | Phase 6 | Pending |
| REQ-F06 | Phase 7 | Pending |
| REQ-VZ03 | Phase 7 | Pending |
| REQ-VZ02 | Phase 8 | Pending |
| REQ-VZ04 | Phase 8 | Pending |
| REQ-S01 | Phase 8 | Pending |
| REQ-S02 | Phase 8 | Pending |

**Mapped: 15/15 -- 100% coverage**

## Dependency Graph

```
Phase 1 (Bug Fixes) ──────────────────────────> Phase 5 (Trace Authoring)
                                                      |
Phase 2 (Trace macOS) ──> Phase 3 (Trace iOS) ──────>|
                                                      |──> Phase 7 (Playback)
Phase 4 (Comparison) ──> Phase 6 (Validation) ──────>|──> Phase 8 (Polish + Study)
```

## Research Flags

| Phase | Needs Research? | Reason |
|-------|----------------|--------|
| Phase 1 | NO | Bugs identified, fixes are known SwiftUI patterns |
| Phase 2 | YES | Step trace schema design, granularity rules, versioning |
| Phase 3 | NO | Architecture documented in research, minimal extension |
| Phase 4 | YES | Per-topic comparison edge cases, strategy mapping |
| Phase 5 | NO | Trace API defined in Phase 2, authoring is per-problem work |
| Phase 6 | YES | 16 topics with unique input formats and comparison needs |
| Phase 7 | NO | PointerExtractor heuristics documented, code display is standard |
| Phase 8 | MAYBE | Reingold-Tilford in Swift/SwiftUI may need research |
