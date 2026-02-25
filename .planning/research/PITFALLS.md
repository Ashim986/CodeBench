# Domain Pitfalls

**Domain:** DSA algorithm visualization iOS app (step-by-step animation)
**Researched:** 2026-02-24
**Overall confidence:** HIGH (based on deep codebase analysis + established SwiftUI/iOS patterns)

---

## Critical Pitfalls

Mistakes that cause rewrites, severe performance degradation, or fundamentally broken user experience.

---

### Pitfall 1: SwiftUI View Identity Instability Causing Animation Chaos

**Severity:** CRITICAL
**What goes wrong:** SwiftUI uses structural identity (position in the view hierarchy) and explicit identity (`id()` modifier, `Identifiable` conformance) to track views across state changes. When view identity changes between frames, SwiftUI destroys and recreates the view instead of animating it. This produces jarring flashes, disappearing elements, and broken transitions -- the exact opposite of smooth step-by-step animation.

**Why it happens in CodeBench:** The current `TraceTreeLayout.Node` uses the tree node's string ID (`"i0"`, `"i1"`, etc.) which is stable for a single tree, but when the tree structure changes between steps (node inserted, deleted, or pruned), the same index may map to a different logical node. Similarly, `GraphLayout.Node` uses `UUID()` for its `id`, meaning every layout recalculation produces entirely new identities -- SwiftUI sees every node as new and cannot animate position changes.

**Code evidence:**
```swift
// GraphLayout.Node (line 209 of DataJourneyGraphView.swift)
struct Node: Identifiable {
    let id = UUID()  // NEW ID every time layout is computed!
    let index: Int
    let position: CGPoint
}
```

**Consequences:**
- Graph nodes flash/teleport instead of smoothly moving between steps
- Tree nodes cannot animate insertion/deletion because identity is position-based
- `withAnimation` blocks have no effect when the view identity changes
- Users see visual noise instead of meaningful structural changes

**Prevention:**
- Use **stable, semantically meaningful IDs** for all layout nodes. For graphs, use the node index. For trees, use the tree node's semantic ID from the data model (not the heap-index position).
- Never use `UUID()` as the `id` for `Identifiable` types that will be animated across state changes.
- Use `id()` modifier only when you intentionally want to reset a view (e.g., switching to a completely different problem).
- When tree structure changes between steps, map old node IDs to new node IDs to enable matched geometry transitions.

**Detection:**
- Step forward/backward and watch for elements that flash/appear instead of smoothly transitioning
- If `withAnimation` has no visible effect on position changes, identity is broken
- Instrument with `Self._printChanges()` to see which views are being destroyed vs. updated

**Confidence:** HIGH -- this is a well-documented SwiftUI behavior and the existing code has the exact anti-pattern (`UUID()` in layout nodes).

---

### Pitfall 2: Layout Recalculation on Every Render Causing Frame Drops

**Severity:** CRITICAL
**What goes wrong:** `TraceTreeLayout` and `GraphLayout` are initialized inside the `body` computed property, meaning they run O(n), O(n log n), or O(n * iterations) layout algorithms on every single SwiftUI render pass. Since `body` can be called dozens of times per second during animation, this causes severe frame drops.

**Why it happens in CodeBench:** This is already happening. The CONCERNS.md document identifies it:
```swift
// TreeGraphView body (line 45)
let layout = TraceTreeLayout(tree: tree, nodeSize: nodeSize, levelSpacing: levelSpacing)

// GraphView body (line 41)
let layout = GraphLayout(adjacency: adjacency, size: compactSize, nodeSize: nodeSize)
```
The `GraphLayout` runs a **50-iteration Fruchterman-Reingold force simulation** inside `body`. During step-by-step playback, every step change triggers a re-render, which triggers 50 force-directed iterations per graph.

**Consequences:**
- Frame drops during animation playback (especially graphs with 7+ nodes)
- Battery drain from unnecessary CPU work
- UI feels sluggish -- user associates the app with poor performance
- Force-directed layout produces **different positions** on each render (non-deterministic), so nodes jitter even when the graph hasn't changed

**Prevention:**
- **Memoize layout calculations.** Compute layout once when the data changes, not on every render. Store layout results in the Observable state layer or use a `@State` property with equality checks.
- For force-directed graph layout: run the simulation once and cache the result. Only rerun when adjacency list changes (not when pointer positions change).
- Use `EquatableView` or custom `Equatable` conformance on visualization views to prevent re-renders when only unrelated state changes.
- Consider moving layout computation to a background thread for graphs with 20+ nodes, presenting a cached previous layout while computing.

**Detection:**
- Use Instruments (SwiftUI profiler) to measure body evaluation count
- Add a `print` inside layout init to count how often it runs during playback
- Watch for graph nodes that subtly shift position between steps even when the graph structure is unchanged

**Confidence:** HIGH -- the force-directed layout runs 50 iterations with O(n^2) repulsive force calculations. For a 20-node graph, that is 50 * 400 = 20,000 distance calculations per render.

---

### Pitfall 3: Tree Width Explosion for Wide/Deep Trees

**Severity:** CRITICAL
**What goes wrong:** The current `TraceTreeLayout` uses a heap-index-based positioning algorithm. Each level reserves positions for `2^level` potential nodes. For a tree of depth D, the bottom level has `2^(D-1)` slots. Even with the `isSkewed` detection, a balanced tree of depth 10 would need 512 leaf slots, producing a canvas potentially thousands of points wide.

**Why it happens in CodeBench:** LeetCode problems commonly involve trees with 15-31 nodes (depth 4-5), which are manageable. But certain problems (e.g., "serialize and deserialize binary tree", "balanced BST from sorted array") can produce trees with 50+ nodes and depth 6+, where `2^5 = 32` leaf positions create a very wide canvas.

**Code evidence:**
```swift
// TraceTreeLayout.computeEffectiveWidth (line 312)
let maxLeafSlots = CGFloat(1 << max(treeDepth - 1, 0))
// For depth 10: 1 << 9 = 512 slots
```

**Consequences:**
- Tree overflows the horizontal scroll view, requiring excessive scrolling
- Nodes become too small to read or overlap
- On iPhone screens (390pt wide), a tree with depth 7+ becomes unusable
- Wide trees with sparse nodes waste huge amounts of empty space

**Prevention:**
- Implement a **Reingold-Tilford** tree layout algorithm (or Walker's improvement) that assigns horizontal positions based on actual subtree width, not potential capacity. This produces compact layouts where only existing nodes take up space.
- Add **pinch-to-zoom** for the tree canvas so users can navigate large trees.
- For trees with depth > 6, show a collapsed summary view with expand-on-tap for subtrees.
- Set a maximum canvas width (e.g., 2x screen width) and adaptively shrink node sizes when the tree is too wide.

**Detection:**
- Test with a complete binary tree of depth 6 (63 nodes) and check if it renders legibly on iPhone
- Test with a skewed tree of depth 15 (linked-list-like) and check horizontal width

**Confidence:** HIGH -- the heap-index algorithm is a known limitation. Reingold-Tilford is the standard solution used by every serious tree visualization tool.

---

### Pitfall 4: Force-Directed Graph Layout Instability and Non-Determinism

**Severity:** CRITICAL
**What goes wrong:** The current Fruchterman-Reingold implementation in `GraphLayout` initializes positions on a circle and runs 50 iterations. This has several problems: (1) 50 iterations may not be enough for convergence on graphs with 15+ nodes, (2) the same graph produces slightly different layouts each render because floating-point arithmetic varies with evaluation order, and (3) disconnected components collapse onto each other because there are no inter-component repulsive forces beyond the initial circle placement.

**Why it happens in CodeBench:** Graph problems on LeetCode frequently involve disconnected components (e.g., "number of connected components", "number of islands" represented as graphs), weighted edges, and self-loops. The current layout handles none of these edge cases.

**Code evidence:**
```swift
// GraphLayout.forceDirectedLayout (line 292-369)
// Iterations fixed at 50, no convergence check
// No handling of disconnected components
// No self-loop rendering
```

**Consequences:**
- Disconnected graph components overlap, making the visualization misleading
- Non-deterministic layouts confuse users during step-by-step playback (the "same" graph looks different at each step)
- Convergence failure on larger graphs produces tangled, unreadable layouts
- Self-loops are invisible (edge from node to itself has zero length)

**Prevention:**
- **Detect disconnected components** using BFS/DFS before layout. Lay out each component separately, then arrange components in a grid or row.
- **Seed the random state** or use a deterministic initialization (e.g., spectral layout) so the same graph always produces the same positions.
- **Cache graph layouts** and only recompute when the adjacency list changes.
- Add **convergence detection**: stop early if maximum displacement falls below a threshold.
- For small graphs (< 7 nodes), the current circular layout is fine. For 7-20 nodes, use force-directed with caching. For 20+ nodes, consider a hierarchical layout or warn the user.

**Detection:**
- Render a graph with 2 disconnected components and check if they overlap
- Render the same graph twice and compare layouts visually
- Test with a graph containing a self-loop

**Confidence:** HIGH -- these are well-known limitations of basic force-directed layout.

---

### Pitfall 5: Step Count Explosion for O(n^2) Algorithms

**Severity:** CRITICAL
**What goes wrong:** When recording algorithm execution steps, the number of steps is proportional to the algorithm's time complexity. Bubble sort on an array of 100 elements produces ~10,000 steps. The current `maxSteps = 40` cap silently truncates this, but when building the step-generation system, developers will be tempted to record "every meaningful operation" without realizing the scale.

**Why it happens in CodeBench:** The project needs step generation for ~450 problems across 18 topics. Many problems have O(n^2) solutions (sorting, DP table filling) or O(2^n) solutions (backtracking). Even "optimized" solutions for DP problems fill an n*m table where n and m can be 100+.

**Consequences:**
- Recording all steps for a DP problem with a 100x100 table = 10,000 steps
- UI becomes unusable if all steps are displayed (timeline chips overflow)
- Memory consumption scales linearly with step count
- JSON file sizes balloon -- a step event with a 100-element array snapshot is ~1KB; 10,000 steps = 10MB per test case
- The `maxSteps = 40` cap means 99.6% of a bubble sort's execution is invisible

**Prevention:**
- Design step recording with **semantic granularity**, not operation-level granularity:
  - For sorting: record after each "pass" or "partition", not each comparison/swap
  - For DP: record row-by-row fills, not cell-by-cell
  - For graph traversal: record per-node visits, not per-edge checks
  - For backtracking: record at decision points and backtracks, not each recursive call
- Implement **adaptive sampling**: if an algorithm has > 100 steps, sample every Nth step to keep total around 40-60.
- Make the step limit configurable per problem category:
  - Arrays/sorting: 30-50 steps
  - Trees/graphs: 20-40 steps (one per node visit)
  - DP: special handling (show table evolution, not cell-by-cell)
- Store step data as **diffs** rather than full snapshots. "Element 3 changed from 5 to 2" is much smaller than a full array copy.

**Detection:**
- Count steps generated for the worst-case test input of each problem
- Monitor JSON file sizes after adding step data
- Check memory usage when loading a problem with many test cases, each with steps

**Confidence:** HIGH -- this is the most common pitfall in algorithm visualization projects. Every educational tool (VisuAlgo, Algorithm Visualizer, etc.) had to solve this.

---

### Pitfall 6: Test Result Validation Failures Across 16 Remaining Topics

**Severity:** CRITICAL
**What goes wrong:** Only 2 of 18 topics have validated test results. The remaining 16 topics will encounter systematic validation failures that are not bugs in the solution but mismatches in how outputs are compared.

**Why it happens in CodeBench:** The current comparison is strict string equality (`computedOutput == expectedOutput`). This fails for:

1. **Order-independent results**: Two Sum can return `[0,1]` or `[1,0]` -- both are correct. The `orderMatters` flag exists but is not used in the comparison logic.
2. **Floating-point precision**: "Find Median from Data Stream" may produce `2.0` vs `2.00000` vs `2`.
3. **Multiple valid answers**: "3Sum" may return sets in any order. `[[-1,-1,2],[-1,0,1]]` vs `[[-1,0,1],[-1,-1,2]]`.
4. **Null handling**: Tree serialization may produce `[1,null,2]` vs `[1,null,2,null,null]` (trailing nulls).
5. **Boolean case**: `"True"` vs `"true"` depending on serialization.
6. **Linked list cycle outputs**: Problems like "linked list cycle" return a node reference, not a value.

**Code evidence:**
```swift
// Test pattern (from TESTING.md)
let matches = computedOutput == expectedOutput  // STRICT string equality
#expect(computedOutput == expectedOutput, "Test \(testId): input=\(rawInput)")
```

**Topics most at risk:**
- **Graphs** (multiple valid traversal orders, disconnected components)
- **Backtracking** (multiple valid combinations, order-independent)
- **Trees** (multiple valid BST structures, trailing null handling)
- **Heap/Priority Queue** (equivalent heap structures)
- **Dynamic Programming** (floating-point in optimization problems)
- **Linked List** (cycle detection returns node reference)

**Prevention:**
- Implement **comparison strategies** per problem type:
  - `exactMatch`: current behavior, for deterministic outputs
  - `sortedMatch`: sort arrays/sets before comparing (for order-independent problems)
  - `deepSortedMatch`: recursively sort nested arrays (for problems like 3Sum)
  - `floatMatch(precision:)`: compare doubles within epsilon
  - `treeMatch`: normalize tree serialization (strip trailing nulls)
  - `setMatch`: compare as sets, ignoring order
- Store the comparison strategy in the test case metadata, not as a generic `orderMatters` boolean.
- Validate a sample of 5-10 test cases per topic manually before running full suite.
- Track false negatives (solution is correct but comparison fails) separately from true failures.

**Detection:**
- If a well-known correct solution (e.g., copied from LeetCode's editorial) fails > 20% of test cases, suspect comparison issues before suspecting the solution.
- Group failures by problem -- if all test cases for a problem fail, it is likely a comparison/parsing issue, not a logic bug.

**Confidence:** HIGH -- the `orderMatters` field already exists in test metadata, indicating awareness of this issue, but the comparison logic does not use it.

---

## Moderate Pitfalls

Mistakes that cause significant rework or degraded experience but are recoverable without full rewrites.

---

### Pitfall 7: Linked List Cycle Rendering Infinite Loop or Crash

**Severity:** MODERATE
**What goes wrong:** Linked list problems frequently involve cycles (e.g., "linked list cycle", "linked list cycle II"). If the visualization naively iterates through the list to collect nodes for rendering, a cycle produces an infinite loop. If it allocates a view per node, it will exhaust memory.

**Why it happens in CodeBench:** The `TraceList` model already handles this with a `cycleIndex` field and `isTruncated` flag. However, the data that feeds into `TraceList` must be correctly detected as cyclic. If the step-generation system follows `next` pointers to serialize a linked list, it will loop forever without cycle detection.

**Code evidence:**
```swift
// DataJourneyModels.swift
struct TraceList: Equatable {
    let nodes: [TraceListNode]
    let cycleIndex: Int?       // Exists! But must be populated correctly
    let isTruncated: Bool
    let isDoubly: Bool
}
```

**Prevention:**
- In the step-generation system, always use **Floyd's cycle detection** (or a visited set) when serializing linked lists.
- Cap the maximum number of nodes rendered in a single linked list to 50. Beyond that, truncate with a "..." indicator.
- When a cycle is detected, draw a curved arrow from the last node back to the cycle start node, clearly labeled "cycle".
- Test with every linked list problem's edge cases: empty list, single node with self-cycle, two-node cycle.

**Detection:**
- Test linked list visualization with the input from "Linked List Cycle II" test cases
- Check if the app hangs or memory climbs when displaying cyclic lists

**Confidence:** HIGH -- the data model already accounts for cycles, indicating prior awareness. The risk is in the step-generation system that feeds this model.

---

### Pitfall 8: StructureResolver Heuristic Misclassification

**Severity:** MODERATE
**What goes wrong:** The `StructureResolver` uses variable name heuristics and data shape to determine what type of structure to render. This produces incorrect visualizations when: (1) a 2D integer array happens to look like an adjacency list, (2) a variable named `heapValues` is a regular array, (3) bucket sort output (array of arrays with small integers) is misidentified as a graph.

**Why it happens in CodeBench:** The resolver already has mitigation for some cases (the `passesAdjacencyListValidation` method rejects uniform-length rows and out-of-range values). But as step data is added with new variable names and intermediate data structures, the heuristics will encounter more edge cases.

**Code evidence:**
```swift
// StructureResolver+Handlers.swift (line 60)
if loweredName.contains("heap") {  // Any variable with "heap" in name → heap view
    let isMin = loweredName.contains("min")
    ...
}
if loweredName.contains("stack") {  // Any variable with "stack" in name → stack view
    ...
}
```

**Consequences:**
- Algorithm visualization shows wrong structure type (e.g., DP table rendered as graph)
- User loses trust in the visualization if it shows incorrect representations
- Hard to debug because the misclassification is silent

**Prevention:**
- When adding step data, include **explicit type annotations** in the trace event: `{"__type": "heap", "value": [3,1,4]}` instead of relying on variable name heuristics.
- Add a fallback UI element: "Detected as: Graph. Incorrect? Tap to switch view." (for future consideration)
- Write comprehensive unit tests for `StructureResolver` covering all known edge cases (DP tables, bucket sort output, adjacency matrices vs. regular matrices).
- Document the naming conventions that trigger each heuristic so step generators can avoid false positives.

**Detection:**
- Review all test cases from DP, greedy, and math-geometry topics for 2D arrays that might be misclassified as graphs
- Run the resolver on every test input across all 18 topics and audit the detected types

**Confidence:** HIGH -- the heuristic approach is inherently fragile. The existing `passesAdjacencyListValidation` method is evidence of prior misclassification issues.

---

### Pitfall 9: JSON Schema Evolution Breaking Backward Compatibility

**Severity:** MODERATE
**What goes wrong:** The test result JSON schema will evolve as step data is added. If the new schema is not backward-compatible, all existing validated results (arrays-hashing, intervals) must be regenerated, and older versions of the app cannot load newer data.

**Why it happens in CodeBench:** The current test result format is:
```json
{
  "computed_output": "1",
  "input": "nums = [1,2,3]",
  "is_valid": true,
  "order_matters": true,
  "original_expected": "1",
  "output_matches": true,
  "slug": "...",
  "test_id": "...",
  "topic": "..."
}
```
Adding step data (e.g., `"steps": [...]`) is additive and safe. But if step data changes the structure of existing fields or requires new required fields, backward compatibility breaks.

**Consequences:**
- Existing validated test results become unloadable
- Need to re-run the full test suite for topics that already passed
- If bundled data format changes, older app builds crash on launch

**Prevention:**
- **Always add new fields as optional.** Never remove or rename existing fields.
- Use a `"schema_version": 1` field in the JSON root. The app checks the version and handles each version's format.
- Step data should be a new optional field: `"trace_events": [...]` at the test result level.
- When loading, use `decodeIfPresent` for all new fields.
- Keep a schema changelog document so future changes are tracked.

```swift
// Safe evolution pattern:
struct TestResult: Codable {
    let computedOutput: String
    let input: String
    // ... existing fields ...
    let traceEvents: [TraceEvent]?  // NEW: optional, won't break old data
}
```

**Detection:**
- Attempt to load the current `arrays-hashing.json` results with any new model changes
- Automated test: decode old JSON format with new model struct

**Confidence:** HIGH -- this is standard software engineering practice but easy to forget when rapidly iterating.

---

### Pitfall 10: Memory Pressure from Large Data Structures in Step Snapshots

**Severity:** MODERATE
**What goes wrong:** Each step in the visualization needs a snapshot of the data structure's state at that point. If each step stores a full copy of the data structure (e.g., a 100-element array as a `[TraceValue]`), memory usage scales as `steps * data_size`. For a problem with 40 steps and a 100-element array, that is 4,000 `TraceValue` objects just for one test case.

**Why it happens in CodeBench:** The app loads all test results for a topic into memory at once. If each test result gains 40 step snapshots with full data copies, the memory per topic could increase 10-40x.

**Current state (from CONCERNS.md):**
> Current capacity: ~1000 test results per topic before noticeable lag
> With 150+ problems x 10+ test cases per problem, memory usage becomes problematic on iOS.

Adding step data to each test result multiplies this problem significantly.

**Consequences:**
- iOS memory warnings and potential app termination on older devices
- Slow topic loading times (parsing large JSON with step data)
- Scrolling lag when browsing problems in a topic with step data

**Prevention:**
- **Store step data separately** from test results. Keep test results lean (input/output/pass-fail) and load step data on-demand when the user taps "Visualize".
- Use **delta encoding** for step snapshots: store the initial state plus diffs for each step, not full copies.
- **Lazy load** step data: only parse step JSON when the user actually opens the visualization for a specific test case.
- Cap the number of test cases with pre-computed step data per problem (e.g., 3 representative test cases).
- Profile memory usage on an iPhone SE (4GB RAM) as the baseline device.

**Detection:**
- Load a topic with step data and monitor memory usage in Instruments
- Check if total JSON file size per topic exceeds 5MB after adding step data

**Confidence:** HIGH -- the existing CONCERNS.md already flags memory as a concern at current data volumes.

---

### Pitfall 11: Canvas Rendering Performance with Large Graphs/Trees

**Severity:** MODERATE
**What goes wrong:** SwiftUI `Canvas` draws all edges every frame, regardless of whether they are visible. For a graph with 50 nodes and 200 edges, every render pass executes 200 path stroke operations plus 50 node positions. Combined with the layout recalculation pitfall (#2), this produces compounding frame drops.

**Why it happens in CodeBench:** The current implementation has no viewport culling:
```swift
// GraphView Canvas (line 46-55)
Canvas { context, _ in
    let nodeRadius = nodeSize / 2
    for edge in layout.edges {  // ALL edges, every frame
        drawSurfaceEdge(context: &context, edge: edge, nodeRadius: nodeRadius)
    }
}
```

**Consequences:**
- Graphs with 20+ nodes and dense edges drop below 30fps during animation
- Large trees with 50+ nodes render slowly on older iPhones
- Battery drain during extended visualization sessions

**Prevention:**
- Implement **viewport culling**: only draw edges and nodes that intersect the visible scroll rect. `Canvas` provides the `size` parameter; combine with the scroll offset to determine visibility.
- For graphs with 30+ edges, use **edge bundling** or reduce edge opacity to decrease visual clutter.
- Cache the Canvas rendering as a `UIImage` when the data hasn't changed and only re-render on data changes (not on selection/highlight changes).
- Consider using `drawingGroup()` modifier on the canvas container to rasterize the layer, reducing per-frame compositing cost.
- For truly large structures (100+ nodes), fall back to a simplified representation (adjacency list table) with a "show full graph" toggle.

**Detection:**
- Profile with Instruments (Core Animation, Metal System Trace) on a physical iPhone
- Test with the largest graph in the test case set and measure FPS

**Confidence:** HIGH -- no viewport culling is a known pattern in the codebase, and Canvas redraw cost is well-understood.

---

### Pitfall 12: InputParser Silent Defaults Propagating Bad Data Through the Pipeline

**Severity:** MODERATE
**What goes wrong:** `InputParser` returns default values (`0`, `false`, empty string, empty array) when parsing fails, instead of reporting errors. This means a malformed test case input silently produces wrong data, which the solution runs on, which produces a "wrong" output -- but the real bug is in the input, not the solution.

**Code evidence:**
```swift
// InputParser.swift
public static func parseInt(_ s: String) -> Int {
    Int(s.trimmingCharacters(in: .whitespaces)) ?? 0  // Silent default
}
```

**Why this matters for 16 remaining topics:** Each topic has different input formats and edge cases. Graphs use adjacency lists, trees use nullable arrays, DP problems have complex multi-parameter inputs. A parsing failure in any of these silently corrupts the test.

**Consequences:**
- False test failures that appear to be solution bugs but are actually parsing bugs
- Wasted debugging time investigating "wrong" solutions that are actually correct
- Incorrect test results get bundled into the app and shown to users

**Prevention:**
- For the test validation pipeline (not the app), replace silent defaults with throwing parsers or Result types.
- Add input validation assertions: after parsing, verify the parsed values match expected constraints from the problem description (e.g., `1 <= nums.length <= 10^5`).
- Log all parse operations with input/output for debugging failed test cases.
- For each new topic, manually verify 3-5 test case inputs parse correctly before running the full suite.

**Detection:**
- Search test results for problems where ALL test cases fail -- likely a parsing issue
- Compare input parameter count against expected count in guard statements

**Confidence:** HIGH -- the CONCERNS.md already identifies this as a security and correctness risk.

---

## Minor Pitfalls

Issues that cause friction or suboptimal results but are fixable without significant rework.

---

### Pitfall 13: Array Visualization Readability at 100+ Elements

**Severity:** MINOR
**What goes wrong:** The current `SequenceBubbleRow` renders each array element as a 40px bubble in a horizontal scroll view. An array with 100 elements produces a row 4,000+ px wide (100 * 40px). Users must scroll extensively, losing context of the overall array structure. Pointer positions (e.g., `left` at index 5, `right` at index 95) cannot be seen simultaneously.

**Prevention:**
- For arrays with 20+ elements, switch to a **compact row** rendering: smaller bubbles (20px), no gaps, with index labels every 10th element.
- For arrays with 50+ elements, use a **wrapped grid** layout (e.g., 20 elements per row) so the full array is visible at once.
- Show a **minimap** at the top of long arrays: a 1px-per-element bar with highlighted regions for pointer positions and changed elements.
- Always ensure all active pointers are visible: auto-scroll to keep the "action area" (region between leftmost and rightmost pointers) centered.

**Detection:** Test with sorting algorithm visualization on a 100-element array.

**Confidence:** HIGH -- this is a standard UX problem in array visualizations.

---

### Pitfall 14: Playback State Inconsistency During Rapid User Interaction

**Severity:** MINOR
**What goes wrong:** The `DataJourneyView+Playback.swift` extension manages playback state (current index, playing/paused, speed) across multiple functions (`stepControlsHeader`, `stepControlsTimeline`, `ensurePlaybackSelection`). If the user rapidly clicks step-forward while auto-play is running, or changes speed mid-playback, the state can become inconsistent.

**Code evidence (from CONCERNS.md):**
> The extension contains multiple state management functions that recalculate similar parameters. The `ensurePlaybackSelection()` function may not be called consistently on all events.

**Prevention:**
- Consolidate playback state into a single `@Observable` playback controller class with a well-defined state machine (idle, playing, paused, stepping).
- Make all state transitions go through a single method that validates the transition is legal.
- When the user manually steps, always pause auto-play first.
- Debounce rapid step clicks (e.g., 50ms debounce) to prevent state race conditions.

**Detection:** Rapidly click step-forward during auto-play and check if the index and display stay synchronized.

**Confidence:** MEDIUM -- the CONCERNS.md identifies this as a known bug, suggesting it has been observed in practice.

---

### Pitfall 15: Trie Visualization Explosion for Large Prefix Trees

**Severity:** MINOR
**What goes wrong:** Tries can be extremely wide. A trie containing all lowercase English words starting with each of the 26 letters produces a root with 26 children, each potentially branching further. The current trie visualization likely uses a tree-like layout, which will produce an extremely wide canvas.

**Prevention:**
- Use a **radial/sunburst layout** for tries: root at center, children radiating outward.
- Collapse single-child chains into a single node: `r -> u -> n` becomes a single node labeled `"run"`.
- Limit the displayed trie depth to 3-4 levels by default, with expand-on-tap for deeper exploration.
- For large tries (50+ nodes), show a simplified view with just the relevant path highlighted.

**Detection:** Test with the "Implement Trie" problem using a large word set.

**Confidence:** MEDIUM -- the trie visualization exists but the research could not verify its layout algorithm in detail.

---

### Pitfall 16: Bundle Size Growth from 10,000+ Test Cases with Step Data

**Severity:** MINOR
**What goes wrong:** The app bundles test result JSON files. Currently ~1MB total. Adding step data (even with delta encoding) could increase this 5-20x. A 20MB bundle is still acceptable for an iOS app, but 100MB+ would trigger App Store review issues if ever distributed.

**Prevention:**
- Pre-compute step data for only a **curated subset** of test cases (3 per problem: small, medium, edge case). Not all 10,000+.
- Use binary encoding (MessagePack, CBOR, or even compressed JSON) instead of pretty-printed JSON for step data.
- Compress the step data files using zlib and decompress on-demand.
- Track total bundle size in the build process and alert if it exceeds 50MB.

**Detection:** Monitor the app bundle size after each topic's step data is added.

**Confidence:** MEDIUM -- depends entirely on how much step data is generated per test case.

---

### Pitfall 17: Scope Creep in "Small" Feature Additions

**Severity:** MINOR
**What goes wrong:** Certain features that sound simple have hidden complexity that can consume weeks of development time:

| "Simple" Feature | Hidden Complexity |
|-----------------|-------------------|
| "Add undo/redo for step navigation" | Full command pattern, state snapshot stack, memory management for snapshots |
| "Add speed control for animation" | Animation timing system, interpolation between speeds, timer management (already partially implemented with speed picker) |
| "Let users edit test inputs" | Input validation per problem type, re-execution, result comparison, maintaining consistency with pre-computed steps |
| "Show code alongside visualization" | Code parsing, line highlighting sync, scroll-lock between code and visualization, syntax highlighting engine |
| "Support dark mode for visualizations" | All color tokens must be dynamic, Canvas drawing must use theme colors (partially done with `dsTheme`), contrast ratios must be verified |
| "Compare two algorithms side-by-side" | Synchronized step playback, dual layout calculation, shared state management, responsive layout on small screens |

**Prevention:**
- Before starting any feature, write a **complexity estimate** that lists all the sub-tasks. If there are more than 5 sub-tasks, it is not a "small" feature.
- Maintain a strict separation between the current milestone's features and "nice to have" additions.
- Use the DataJourney's existing playback system (speed picker, step controls) as the reference for what "done" looks like -- don't over-engineer beyond what exists.

**Detection:** If a feature has been "almost done" for more than 3 days, it was underscoped.

**Confidence:** HIGH -- this is a universal software development pitfall, and the existing codebase already has partial implementations (speed picker) that show scope was managed.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Test result validation (16 topics) | False failures from comparison strategy (#6) | Implement per-problem comparison strategies before running full suite |
| Step data generation | Step count explosion (#5) | Define semantic step granularity rules per topic before generating |
| Array animation | Large array readability (#13) | Design compact rendering before implementing animation |
| Tree animation | Width explosion (#3), layout recalculation (#2) | Switch to Reingold-Tilford layout, memoize |
| Graph animation | Layout instability (#4), Canvas performance (#11) | Cache layouts, add viewport culling |
| Linked list animation | Cycle rendering (#7) | Ensure cycle detection in step generator, test with cycle problems first |
| DP visualization | Step count explosion (#5), misclassification (#8) | Use explicit type annotations in step data for DP tables |
| Playback system | State inconsistency (#14) | Refactor to state-machine-based controller before adding animations |
| JSON schema changes | Backward compatibility (#9) | Version the schema, use optional fields only |
| Bundle size management | Bundle growth (#16) | Track size, curate step data subset |

---

## CodeBench-Specific Risk Matrix

| Risk | Probability | Impact | Priority |
|------|------------|--------|----------|
| Layout recalculation every render (#2) | Already happening | Frame drops | Fix first |
| Graph identity instability (#1) | Already happening | Broken animation | Fix first |
| Test validation false failures (#6) | Very high | Blocks 16 topics | Fix before validation push |
| Step count explosion (#5) | Very high | Data/memory issues | Design before implementing |
| Tree width explosion (#3) | High | Poor UX on iPhone | Fix during tree animation |
| Force layout instability (#4) | High | Misleading visualization | Fix during graph animation |
| Schema evolution (#9) | Medium | Rework risk | Prevent from the start |
| Memory pressure (#10) | Medium | App crashes on older devices | Monitor continuously |
| StructureResolver misclassification (#8) | Medium | Wrong visualization type | Add type annotations in step data |
| Scope creep (#17) | Medium | Schedule slip | Discipline, milestone boundaries |

---

## Sources

- CodeBench codebase analysis (all source files read directly)
- SwiftUI identity and animation system (Apple documentation, WWDC sessions on animation identity)
- Reingold-Tilford tree layout algorithm (standard CS visualization reference)
- Fruchterman-Reingold force-directed layout (original 1991 paper, well-known limitations)
- Algorithm visualization design patterns (VisuAlgo, Algorithm Visualizer, CS education research)
- iOS memory management best practices (Apple Technical Notes on memory pressure)
- JSON schema evolution (semver principles applied to data formats)

---

*Pitfalls research: 2026-02-24*
