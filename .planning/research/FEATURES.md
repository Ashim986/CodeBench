# Feature Landscape

**Domain:** Personal iOS DSA study app with step-by-step algorithm visualization
**Researched:** 2026-02-24
**Research mode:** Ecosystem (no web access -- analysis based on codebase inspection + training data knowledge of VisuAlgo, Algorithm Visualizer, CS Academy, LeetCode, AlgoExpert, PythonTutor)

## Current State Assessment

CodeBench's DataJourney framework is **substantially more complete than initial project context suggests**. Based on thorough codebase analysis, the following already exists:

### Already Built (Verified from Code)
| Feature | Status | Evidence |
|---------|--------|----------|
| Step-by-step playback | COMPLETE | `DataJourneyAnimationController`, play/pause/step-forward/step-back |
| Speed control (0.5x-4x) | COMPLETE | `availableSpeeds: [0.5, 1.0, 2.0, 4.0]` |
| Array visualization | COMPLETE | `arrayContentView`, index display, pointer badges |
| Tree visualization | COMPLETE | `TreeGraphView` with layout engine, edge curves, pointer motions |
| Graph visualization | COMPLETE | `GraphView` with force-directed + circular layout, directed/undirected |
| Linked list visualization | COMPLETE | Single, doubly, cycle detection, list groups, combined views |
| Trie visualization | COMPLETE | `DataJourneyTrieGraphView` |
| Matrix/grid visualization | COMPLETE | `MatrixGridView` with cell highlighting |
| Heap visualization | COMPLETE | `HeapView` with min/max indication |
| Stack/queue visualization | COMPLETE | Direction arrows (push/pop, enqueue/dequeue) |
| Dictionary/set visualization | COMPLETE | `DictionaryStructureRow`, set with gap rendering |
| String sequence visualization | COMPLETE | `StringSequenceView` |
| Pointer tracking | COMPLETE | `PointerMarker`, `PointerMotion`, `TreePointerMotion` |
| Pointer motion animation | COMPLETE | Curve-based motion paths between steps |
| Diff highlighting | COMPLETE | `TraceValueDiff` with LCS-based array diffing, tree node diffing, matrix cell diffing |
| Element change types | COMPLETE | `ChangeType` (added/removed/modified/unchanged) |
| Code line context | COMPLETE | `DataJourneyCodeContext` -- 3-line window with active line highlight |
| Variable timeline | COMPLETE | `VariableTimelineView` with sparklines, bar charts, dot views |
| Keyboard shortcuts | COMPLETE | Arrow keys, space, Home/End |
| PNG export | COMPLETE | `renderAndExport()` with `ImageRenderer` |
| Truncation handling | COMPLETE | 40-step cap with user-facing message |
| Structure auto-detection | COMPLETE | `StructureResolver` with matrix, graph adjacency, list detection |
| Accessibility | COMPLETE | Labels, identifiers, reduce-motion support |

### What the DataJourney Does NOT Have (Gaps)
Based on code review, these are the actual missing features:

1. **No trace data generation** -- Solutions are pre-built code strings but there is no mechanism to execute them and generate trace events. The DataJourney framework consumes `[DataJourneyEvent]` but nothing produces them.
2. **No test case execution engine** -- The `TestResultBridge` exists but likely bridges to pre-computed results, not live execution.
3. **No solution-to-trace pipeline** -- The ~450 solutions have code and test cases, but no trace annotations (`Trace.step()` calls).
4. **No search/filter within visualization** -- Cannot search for a specific state or value across steps.
5. **No bookmarking/annotation** -- Cannot mark "interesting" steps for review later.
6. **No comparison mode** -- Cannot compare two approaches' visualizations side-by-side.
7. **No edge weight visualization for graphs** -- The `GraphLayout.Edge` has a `weight: String?` field and the rendering code draws it, but the graph structure detection (`StructureResolver.graphAdjacency`) only produces `[[Int]]` with no weights.

---

## Table Stakes

Features users expect from any DSA visualization tool. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | CodeBench Status |
|---------|--------------|------------|-----------------|
| Step forward/back | Core of "step-by-step" -- VisuAlgo, Algorithm Visualizer, PythonTutor all have this | Low | DONE |
| Play/pause auto-advance | Every visualization tool offers this | Low | DONE |
| Speed control | Standard in VisuAlgo (multiple speeds), Algorithm Visualizer | Low | DONE |
| Array visualization with indices | Fundamental -- every tool shows arrays with index labels | Low | DONE |
| Tree node-edge rendering | Binary trees are core to half of all DSA problems | Med | DONE |
| Diff highlighting (what changed) | PythonTutor highlights changed values red; VisuAlgo colors active elements | Med | DONE |
| Code-to-viz sync | PythonTutor's defining feature -- show which line produced current state | Med | PARTIAL -- 3-line context window exists, needs trace line data |
| Pointer/variable tracking | VisuAlgo shows i, j, left, right pointers on arrays; essential for two-pointer, sliding window | Med | DONE |
| Linked list node-arrow rendering | Arrows between nodes showing next pointers | Med | DONE |
| Graph node-edge layout | Force-directed or layered layout for arbitrary graphs | High | DONE |
| Input/output display | Show what goes in, what comes out | Low | DONE |

**Verdict:** CodeBench has all table stakes features built. The gap is not in visualization -- it is in the **data pipeline** that feeds visualizations.

---

## Differentiators

Features that set CodeBench apart. Not expected, but high study value.

| Feature | Value Proposition | Complexity | CodeBench Status |
|---------|-------------------|------------|-----------------|
| Variable timeline sparklines | See how variables evolve across ALL steps at a glance -- unique to CodeBench | Med | DONE |
| Pointer motion curves | Animated arcs showing where pointers moved FROM and TO -- beyond what VisuAlgo offers | High | DONE |
| Auto structure detection | Automatically identifies arrays, trees, graphs, matrices from trace data -- no manual tagging | High | DONE |
| Per-element change classification | LCS-based diffing distinguishes added/removed/modified -- richer than simple "changed" highlighting | High | DONE |
| Combined linked list view | Shows individual lists + merged combined view for merge-sort-list type problems | High | DONE |
| Matrix pointer cell tracking | Detects i/j/row/col variables and highlights the active cell in grids | Med | DONE |
| Cycle detection visualization | Shows cycle index in linked lists visually | Med | DONE |
| Tree pointer motion arcs | Curved animated paths showing how tree traversal pointers move between nodes | High | DONE |
| Multiple approach comparison | Show two different approaches to same problem (brute force vs optimized) | Med | PARTIAL -- can browse approaches, no side-by-side viz comparison |
| Study progress tracking | Track which problems reviewed, mastery level | Med | NOT BUILT |
| Spaced repetition scheduling | Surface problems due for review based on memory curves | High | NOT BUILT |
| Problem difficulty tagging | Tag problems with personal difficulty assessment | Low | NOT BUILT |
| Trace annotation/bookmarks | Mark interesting steps with notes for later review | Low | NOT BUILT |

---

## Anti-Features

Features to explicitly NOT build for a personal study tool.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| User code execution / sandbox | Massive security/complexity burden (sandboxing Swift runtime, handling infinite loops, memory limits). Not needed -- solutions are pre-built. | Pre-compute trace data offline as part of solution authoring pipeline |
| Real-time code editing with live viz | Requires incremental parsing, error recovery, live compilation -- enormous scope | Static pre-built solution display with existing `DataJourneyCodeContext` |
| Multiplayer / social features | Personal study tool, not a platform | N/A |
| App Store submission features | Not targeting App Store (TestFlight/personal device) | Skip analytics SDKs, review prompts, IAP, App Tracking Transparency |
| Natural language problem explanation | LLM integration adds API dependency, cost, latency | Pre-written explanations already exist in solution JSON (`explanation`, `intuition` fields) |
| Online judge / submission grading | Not the purpose -- this is for studying solutions, not writing them | Show pre-computed test results |
| Cross-platform (Android/web) | Personal iOS tool | Stay native SwiftUI |
| Algorithm complexity analyzer | Deriving Big-O from code is an unsolved problem in general | Display pre-authored complexity strings (already in solution JSON) |

---

## The Real Gap: Trace Data Pipeline

The most important finding from this research is that CodeBench's **visualization layer is production-quality** but the **data pipeline is the critical missing piece**.

### What Exists
- Solutions have `code` (Swift source strings) and `testCases` (input/expected output)
- DataJourney consumes `[DataJourneyEvent]` where each event has `kind` (input/step/output), optional `line`, `label`, and `values: [String: TraceValue]`
- TraceValue supports: null, bool, number, string, array, object, list (linked list), tree, trie, listPointer, treePointer, typed (set/stack/queue)

### What's Missing
The bridge between "here is a Swift solution string" and "here is an array of DataJourneyEvents" does not exist. This is the **single most important feature to build**.

### Options for the Pipeline

| Approach | How It Works | Complexity | Recommendation |
|----------|-------------|------------|----------------|
| **A: Pre-computed traces in JSON** | Author trace events alongside each solution, store in solution JSON files | Low | YES -- for v1 |
| **B: Offline trace generator** | A macOS command-line tool that executes solutions with instrumented tracing, outputs JSON | High | LATER -- v2 |
| **C: Runtime execution** | Execute Swift code in-app with trace hooks | Very High | NO -- anti-feature |

**Recommendation: Approach A for v1.** Store trace events directly in the solution JSON. Each approach gains a `trace` field containing the array of events for one representative test case. This is:
- Zero runtime complexity
- Perfectly controlled data quality
- Can be authored incrementally (add traces to the most important problems first)
- Can be generated by a separate tool later (approach B) without changing the app

---

## Feature Comparison: CodeBench vs DSA Visualization Tools

**Confidence: MEDIUM** -- based on training data knowledge of these tools; unable to verify with live web access.

### VisuAlgo (visualgo.net)
The gold standard for CS education visualization. Covers sorting, BST, graph algorithms, SSSP, etc.

| Feature | VisuAlgo | CodeBench |
|---------|----------|-----------|
| Step-by-step execution | Yes | Yes |
| Speed control | Yes (multiple levels) | Yes (4 levels) |
| Play/pause/step | Yes | Yes |
| Code line highlighting | Yes (pseudocode) | Partial (3-line context) |
| Create custom input | Yes | No (pre-built test cases) |
| Multiple data structures | ~12 categories | 14 structure types |
| Algorithm-specific animations | Yes (e.g., swap animation for sorting) | Diff-based (shows before/after state) |
| Educational notes per step | Yes | Yes (step labels) |
| Mobile support | Limited (web-based) | Native iOS |

**Key difference:** VisuAlgo shows algorithm-specific animations (e.g., elements sliding during a swap). CodeBench shows state snapshots with diff highlighting. VisuAlgo's approach is more visually fluid but requires hand-coded animations per algorithm. CodeBench's approach scales to all ~450 problems automatically via the trace format.

### Algorithm Visualizer (algorithm-visualizer.org)
Open-source, code-driven visualization.

| Feature | Algorithm Visualizer | CodeBench |
|---------|---------------------|-----------|
| Code editing + live viz | Yes | No (pre-built solutions) |
| Tracer API | Yes (JavaScript) | Similar concept (TraceValue) |
| Step-by-step | Yes | Yes |
| Multiple languages | JS only for viz | Swift solutions |
| Data structure variety | Arrays, graphs, trees | 14 types including linked lists, tries, heaps |
| Variable tracking | Limited | Rich (pointer badges, motion arcs) |

**Key insight from Algorithm Visualizer:** Their "tracer" concept -- where code emits visualization events -- is exactly what CodeBench's `DataJourneyEvent` model implements. The trace format is the right architecture.

### PythonTutor (pythontutor.com)
The most widely-used code execution visualizer for education.

| Feature | PythonTutor | CodeBench |
|---------|-------------|-----------|
| Code execution | Live (Python, JS, etc.) | Pre-built |
| Step forward/back | Yes | Yes |
| Variable state display | Yes (all vars) | Yes (all trace values) |
| Heap/stack frame vis | Yes (memory model) | No (data structure level) |
| Code line highlighting | Yes (full source) | Partial (3-line window) |
| Data structure rendering | Basic (lists, dicts) | Rich (14 types with pointers) |
| Pointer/reference arrows | Yes (between objects) | Yes (pointer badges + motion arcs) |

**Key insight from PythonTutor:** Their strength is the code-to-state sync. CodeBench's `DataJourneyCodeContext` provides a 3-line code window, but the trace events need `line` numbers populated to make this work.

### LeetCode Built-in Visualizer
LeetCode added basic visualization for some problems.

| Feature | LeetCode | CodeBench |
|---------|----------|-----------|
| Scope | Select problems only | All ~450 problems (with trace data) |
| Step-by-step | Limited | Full |
| Custom input | Yes | No |
| Offline access | No | Yes (fully offline) |
| Multiple approaches | No | Yes (2+ per problem) |

---

## Detailed Feature Analysis by Data Structure

### Array Visualization Features

**What tools commonly show (MEDIUM confidence):**

| Operation | Visual Treatment | CodeBench Support |
|-----------|-----------------|-------------------|
| Element comparison | Highlight compared elements | YES (diff highlighting) |
| Swap | Animate elements exchanging positions | NO -- shows before/after state |
| Partition (quicksort) | Color regions (left of pivot, right of pivot) | PARTIAL (pointer badges for left/right) |
| Sliding window | Highlight window range | YES (pointer badges for left/right) |
| Two pointers | Show i, j pointer positions | YES (automatic pointer detection for i/j/left/right/mid/lo/hi) |
| Prefix sum | Show running computation | YES (variable timeline sparklines) |
| Binary search | Show lo/mid/hi on array | YES (pointer badges) |
| Element insertion/deletion | Animate shift | NO -- shows before/after state |

**Assessment:** CodeBench covers array visualization well. The pointer auto-detection (`isIndexName` checks for i, j, k, idx, left, right, mid, lo, hi, start, end) is a strong feature that most tools lack.

### Tree Visualization Features

| Operation | Visual Treatment | CodeBench Support |
|-----------|-----------------|-------------------|
| Node rendering with values | Circles with values inside | YES (`TraceValueNode`) |
| Parent-child edges | Curved lines | YES (quad curves) |
| Traversal order highlighting | Color nodes in traversal order | PARTIAL (diff highlights changed nodes) |
| Current node pointer | Badge showing "current" | YES (tree pointer badges) |
| Subtree highlighting | Color entire subtree | NO |
| Path highlighting | Color root-to-node path | NO |
| BST property visualization | Show valid range per node | NO |
| Insertion/deletion animation | Animate tree restructuring | NO -- shows before/after state |
| Level-order layout | Heap-style positioning | YES (`TraceTreeLayout`) |
| Skewed tree handling | Compact layout for pathological cases | YES (skew detection adjusts spacing) |

**Assessment:** Tree visualization is strong. The pointer motion arcs (showing how a pointer moved from node A to node B) are a genuinely differentiating feature. Missing subtree/path highlighting could be valuable for DFS/backtracking problems but is not critical.

### Graph Visualization Features

| Operation | Visual Treatment | CodeBench Support |
|-----------|-----------------|-------------------|
| Node-edge rendering | Force-directed layout | YES (Fruchterman-Reingold + circular) |
| Directed/undirected detection | Auto-detect and render arrows | YES |
| BFS/DFS visited coloring | Dim visited nodes | YES (visited indices dimmed to 0.5 opacity) |
| Edge weights | Labels on edges | PARTIAL (rendering code exists, but structure detection strips weights) |
| Shortest path highlighting | Color shortest path edges | NO |
| Cycle detection | Highlight cycle edges | NO |
| Adjacency matrix visualization | Separate from graph view | NO (uses either matrix or graph view, not both) |
| Current frontier node | Pointer badge | YES |

**Assessment:** Graph visualization is solid for the common case. The auto-detection of directed vs undirected graphs is smart. Edge weight support needs the structure resolver to preserve weight data.

### Linked List Visualization Features

| Operation | Visual Treatment | CodeBench Support |
|-----------|-----------------|-------------------|
| Node-arrow rendering | Boxes with arrows | YES (bubble row with arrows) |
| Doubly linked list | Bidirectional arrows | YES (`isDoubly` flag) |
| Cycle detection | Arrow back to earlier node | YES (`cycleIndex`) |
| Pointer rewiring animation | Show old/new pointer targets | YES (pointer motion arcs) |
| Merge two lists | Combined view | YES (`listGroup`, `combinedListRow`) |
| Node insertion/deletion | Before/after state | YES (via diff) |
| List array (e.g., merge k lists) | Array of list heads | YES (`listArray` with heads row) |
| Current pointer position | Badge on node | YES (pointer badges) |

**Assessment:** Linked list visualization is the **most complete** area. The combined list view for merge problems and the list array for "merge k sorted lists" type problems are unique differentiators.

---

## Feature Dependencies

```
Trace Data Pipeline (CRITICAL PATH)
  |
  +-> Code-to-Viz Sync (requires line numbers in trace events)
  |     |
  |     +-> Full source code display with line highlighting
  |
  +-> All visualization features (already built, need data to display)
  |
  +-> Variable Timeline (already built, needs populated events)

Study Features (independent of visualization)
  |
  +-> Progress Tracking
  |     |
  |     +-> Spaced Repetition
  |
  +-> Problem Difficulty Tagging
  |
  +-> Bookmarks/Annotations

Edge Weight Graph Support (enhancement)
  |
  +-> Weighted graph structure in StructureResolver
  |
  +-> Shortest path highlighting
```

---

## MVP Recommendation

### Phase 1: Trace Data Pipeline (HIGHEST PRIORITY)

The visualization framework is built. The bottleneck is trace data.

**Prioritize:**
1. **Define trace JSON schema** -- formalize the `trace` field format in solution JSON
2. **Author traces for 10 representative problems** -- one from each major topic (array, tree, graph, linked list, binary search, sliding window, DP, backtracking, stack, two pointers)
3. **Wire trace loading into SolutionView** -- connect existing JSON loading to `DataJourneyView`
4. **Validate code-line sync** -- ensure `line` numbers in trace events map to displayed code

This unlocks ALL existing visualization features with zero new visualization code.

### Phase 2: Study Workflow Features

Once visualization works end-to-end:
1. **Progress tracking** -- which problems have been reviewed, simple completion state
2. **Problem difficulty tagging** -- personal "easy/medium/hard" per problem
3. **Bookmark interesting steps** -- mark specific visualization states with notes

### Phase 3: Visualization Enhancements

Polish based on actual usage:
1. **Full code display** -- expand from 3-line window to scrollable source with line highlighting
2. **Weighted graph support** -- extend `StructureResolver` to preserve edge weights
3. **Subtree/path highlighting for trees** -- useful for DFS problems
4. **Algorithm-specific step labels** -- "Comparing A[i] with A[j]" type semantic labels

### Defer Indefinitely
- Swap/insertion animations (state snapshots are sufficient for learning)
- Custom input creation (pre-built test cases are fine for personal use)
- Side-by-side approach comparison visualization
- User code execution
- Spaced repetition (useful but complex; simple manual review is fine)

---

## Feature Prioritization Matrix

| Feature | Study Value | Build Cost | Already Built? | Priority |
|---------|-------------|------------|----------------|----------|
| Trace data for 10 key problems | CRITICAL | Medium (authoring time) | No | P0 |
| Wire trace loading into app | CRITICAL | Low | No | P0 |
| Full code display with highlighting | High | Low | Partial | P1 |
| Progress tracking | High | Low | No | P1 |
| Difficulty tagging | Medium | Low | No | P2 |
| Step bookmarks | Medium | Low | No | P2 |
| Weighted graph edges | Medium | Medium | Partial | P2 |
| Subtree highlighting | Medium | Medium | No | P3 |
| Path highlighting (trees/graphs) | Medium | Medium | No | P3 |
| Swap animation | Low | High | No | SKIP |
| Offline trace generator tool | High | High | No | P3 |
| Spaced repetition | Medium | High | No | SKIP for v1 |

---

## Sources and Confidence

| Claim | Source | Confidence |
|-------|--------|------------|
| CodeBench visualization features inventory | Direct codebase analysis | HIGH |
| Feature gap analysis (trace pipeline) | Direct codebase analysis | HIGH |
| VisuAlgo features | Training data (used VisuAlgo extensively) | MEDIUM |
| Algorithm Visualizer features | Training data | MEDIUM |
| PythonTutor features | Training data | MEDIUM |
| LeetCode visualizer features | Training data | LOW |
| AlgoExpert visualization features | Training data | LOW |

**Note:** Web search and web fetch were unavailable during this research. All competitor analysis is based on training data knowledge. Feature comparisons should be validated against current versions of these tools if accuracy is critical. However, the most important finding -- that the visualization layer is complete and the trace data pipeline is the critical gap -- is verified with HIGH confidence from direct code analysis.
