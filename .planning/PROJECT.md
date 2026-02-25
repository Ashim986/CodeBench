# CodeBench

## What This Is

A personal iOS app for studying DSA (Data Structures & Algorithms) problems. It lets you browse LeetCode-style problems by topic, read pre-built solution approaches with code and explanations, view validated test case results, and visualize how the algorithm processes each test case step by step — showing array changes, pointer movements, tree traversals, and graph explorations as they happen.

## Core Value

Step-by-step algorithm visualization on real test cases — see *how* a solution works, not just *that* it works.

## Requirements

### Validated

- ✓ Topic browsing with match rates — existing
- ✓ Problem browsing per topic — existing
- ✓ Solution display with test results — existing
- ✓ Data Journey visualization framework (TraceValue, events, timeline) — existing
- ✓ TestResultBridge parsing (input/output → structured data) — existing
- ✓ TestCaseEvaluator pipeline for arrays-hashing and intervals — existing

### Active

- [ ] Generate validated test results for all 16 remaining topics (backtracking, binary-search, bit-manipulation, dynamic-programming, graphs, greedy, heap-priority-queue, linked-list, math-geometry, misc, sliding-window, stack, trees, tries, two-pointers)
- [ ] Step-by-step array visualization (highlight swaps, partitions, sliding windows, pointer positions)
- [ ] Step-by-step tree visualization (traversal order, insertions, node highlights)
- [ ] Step-by-step graph visualization (BFS/DFS traversal, visited nodes, path finding)
- [ ] Step-by-step linked list visualization (pointer rewiring, node insertions/deletions)
- [ ] User can select any validated test case and see the algorithm animate on that input
- [ ] Solution view shows code, intuition, approach explanation, and complexity analysis
- [ ] Test case results show input, expected output, computed output, and pass/fail status

### Out of Scope

- User-written code execution — app displays pre-built solutions only
- Raw tc-*.json test cases — these are unvalidated and contain errors; only use TestCaseEvaluator output
- App Store distribution — personal use tool
- Network features — all data is bundled locally
- Progress tracking / bookmarks — keep it simple for now

## Context

- 18 DSA topics with ~450 problems total and ~10,000+ test cases across all topics
- Solutions exist for all 18 topics in `Solutions/` with multiple approaches per problem (iterative, recursive, optimized, etc.)
- TestCaseEvaluator is a Swift Package that runs solutions against test cases and records results
- Only 2 of 18 topics have validated test results so far (arrays-hashing, intervals)
- Existing app skeleton has MVVM architecture with SwiftUI, Observable state, and a DataJourney visualization framework already in place
- DataJourney already handles: TraceValue parsing (arrays, trees, linked lists, tries, primitives), event timeline display, and structure resolution
- Built with Swift 6.2+, iOS 26.0+, XcodeGen for project generation

## Constraints

- **Tech stack**: SwiftUI + Swift 6.2+, iOS 26.0+ — already established
- **Data source**: Only `Solutions/` and `TestCaseEvaluator/test_results/` are trusted data — never use raw `tc-*.json`
- **Build system**: XcodeGen (`project.yml`) for iOS app, SPM for TestCaseEvaluator
- **Local only**: All data bundled in app, no network dependencies

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Pre-built solutions only (no user code execution) | Simplifies scope, focuses on learning/visualization | — Pending |
| Exclude raw tc-*.json from app | Contains unvalidated/incorrect answers; only evaluator output is trusted | — Pending |
| Visualize all 4 major data structures (arrays, trees, graphs, linked lists) | Covers the breadth of DSA topics in the problem set | — Pending |
| Generate remaining test results as part of project | Need complete coverage before app is useful across all topics | — Pending |

---
*Last updated: 2026-02-24 after initialization*
