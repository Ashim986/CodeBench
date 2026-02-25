# Technology Stack: SwiftUI Visualization & Animation for DSA

**Project:** CodeBench -- iOS DSA study app with step-by-step algorithm visualization
**Researched:** 2026-02-24
**Research limitations:** WebSearch and WebFetch tools were unavailable. All findings are based on training data (through mid-2025), direct codebase analysis, and established Apple documentation patterns. iOS 26-specific claims are flagged as needing verification.

---

## 1. SwiftUI Animation APIs (iOS 17-18+, projected iOS 26)

### What CodeBench Already Has (And It's Good)

The existing `DataJourneyAnimationController` uses a solid pattern: `Task.sleep`-based timer loop driving discrete state changes via an `advance()` closure, with `withAnimation(.easeInOut(duration: 0.35))` on step transitions. This is fundamentally the right approach for step-by-step algorithm visualization.

**Current animation strategy in the codebase:**
- `DataJourneyAnimationController`: Task-based play/pause timer at configurable speeds
- `withAnimation(.easeInOut(duration: 0.35))` on step selection (in `DataJourneyView+Playback.swift`)
- `.animation(.spring(response: 0.35, dampingFraction: 0.82), value:)` on `SequenceBubbleRow` for implicit animations on data changes
- `@Environment(\.accessibilityReduceMotion)` already respected

### Available APIs and When to Use Each

#### `withAnimation` + State Changes (USE THIS -- primary mechanism)
**Confidence: HIGH (established API, iOS 13+)**

This is the backbone of CodeBench's animation system and should remain so. For discrete step-by-step visualization, you change state (the current step index) and let SwiftUI animate the diff.

```swift
// Already in the codebase, this is correct:
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

**Recommendation:** Keep using this. The "state machine drives discrete steps, withAnimation interpolates between them" pattern is exactly right for algorithm visualization.

#### `PhaseAnimator` (iOS 17+) -- For Multi-Step Micro-Animations Within a Single Step
**Confidence: HIGH (training data verified through iOS 18)**

`PhaseAnimator` cycles through a sequence of phases, applying animations between each. It is NOT the right tool for driving the overall step-by-step playback (that's the `DataJourneyAnimationController`), but it IS useful for micro-animations within a single visualization step.

```swift
// Example: Highlighting a node that was just visited, then fading
enum HighlightPhase: CaseIterable {
    case initial, highlight, settle
}

PhaseAnimator(HighlightPhase.allCases, trigger: currentStepIndex) { phase in
    TraceBubble(text: "5", fill: .blue, size: 40, style: .solid)
        .scaleEffect(phase == .highlight ? 1.2 : 1.0)
        .opacity(phase == .initial ? 0.6 : 1.0)
} animation: { phase in
    switch phase {
    case .initial: .easeIn(duration: 0.1)
    case .highlight: .spring(response: 0.3, dampingFraction: 0.6)
    case .settle: .easeOut(duration: 0.2)
    }
}
```

**Use for:** "Pulse" effects when a node is being compared, swap animations where elements briefly enlarge, BFS "wave" ripple effects.

**Do NOT use for:** Driving overall step-by-step playback. The existing Task-based timer is better for that.

#### `KeyframeAnimator` (iOS 17+) -- For Complex Coordinated Motions
**Confidence: HIGH (training data verified through iOS 18)**

`KeyframeAnimator` defines animation tracks for specific properties (position, scale, opacity, rotation) with keyframes at specific timestamps. This is the right tool for swap animations where two elements need coordinated movement.

```swift
struct SwapAnimationValues {
    var offset1: CGFloat = 0
    var offset2: CGFloat = 0
    var verticalBounce1: CGFloat = 0
    var verticalBounce2: CGFloat = 0
}

KeyframeAnimator(
    initialValue: SwapAnimationValues(),
    trigger: swapTrigger
) { values in
    HStack {
        element1.offset(x: values.offset1, y: values.verticalBounce1)
        element2.offset(x: values.offset2, y: values.verticalBounce2)
    }
} keyframes: { _ in
    KeyframeTrack(\.offset1) {
        CubicKeyframe(targetOffset, duration: 0.4)
    }
    KeyframeTrack(\.offset2) {
        CubicKeyframe(-targetOffset, duration: 0.4)
    }
    KeyframeTrack(\.verticalBounce1) {
        CubicKeyframe(-20, duration: 0.2)
        CubicKeyframe(0, duration: 0.2)
    }
    KeyframeTrack(\.verticalBounce2) {
        CubicKeyframe(20, duration: 0.2)
        CubicKeyframe(0, duration: 0.2)
    }
}
```

**Use for:** Array element swaps (two elements cross paths), pointer rewiring animations, tree rotations.

**Caution:** Keyframe animations are time-based, not state-based. For playback speed control, you'd need to scale durations. Consider wrapping in a helper that takes playback speed as input.

#### `matchedGeometryEffect` (iOS 14+) -- For Element Identity Across Layouts
**Confidence: HIGH**

When an element moves from one position to another (e.g., a node being removed from one position in a linked list and appearing elsewhere), `matchedGeometryEffect` tells SwiftUI "these are the same element" so it animates position/size transitions smoothly.

```swift
// Each TraceBubble for a node with a stable ID
TraceBubble(text: model.text, fill: fill, size: bubbleSize, style: .solid)
    .matchedGeometryEffect(id: node.id, in: animationNamespace)
```

**Use for:** Linked list node movement, tree node repositioning after insertions/deletions, array element repositioning after sort steps.

**Critical requirement:** The `id` must be stable across steps. The existing `TraceListNode.id`, `TraceTreeNode.id` are already string-based and stable -- this is a good fit.

#### `contentTransition(.numericText())` (iOS 16+) -- For Value Changes
**Confidence: HIGH**

When a numeric value in a node changes, this provides a smooth digit-rolling animation.

```swift
Text("\(node.value)")
    .contentTransition(.numericText())
    .animation(.spring, value: node.value)
```

**Use for:** Value updates in tree nodes, array element value changes during DP fill.

#### iOS 26 Projected Improvements
**Confidence: LOW (projected, not verified)**

Based on the trajectory from iOS 17 (PhaseAnimator, KeyframeAnimator) and iOS 18 (scroll-driven animations, improvements to transitions), iOS 26 will likely refine these APIs rather than introduce fundamentally new paradigms. The WWDC 2025 focus will likely be on:

- Further Liquid Glass / visionOS convergence (design language, not animation mechanics)
- Possible improvements to animation performance with Metal-backed rendering
- Potential enhancements to Canvas drawing performance

**Recommendation:** Build on the iOS 17+ APIs (PhaseAnimator, KeyframeAnimator, matchedGeometryEffect) which are stable and well-understood. Any iOS 26 improvements will layer on top of, not replace, these foundations.

---

## 2. Swift/SwiftUI Libraries for Data Structure Visualization

### Assessment: Build Custom, Don't Import Libraries

**Confidence: MEDIUM (based on training data ecosystem survey)**

The ecosystem of Swift/SwiftUI libraries for DSA visualization is thin. CodeBench already has more sophisticated visualization than any available open-source library. Here is what exists:

#### SwiftGraph (davebalck/SwiftGraph)
- **What:** Graph data structure library (adjacency list, weighted graphs, BFS/DFS algorithms)
- **What it is NOT:** A visualization library. It provides graph data structures and algorithms, not rendering.
- **Verdict:** Not needed. CodeBench already has `GraphLayout` with Fruchterman-Reingold force-directed layout and a full adjacency-list-based rendering pipeline.

#### Swift Algorithm Club (raywenderlich/swift-algorithm-club)
- **What:** Educational implementations of algorithms in Swift
- **Verdict:** Reference material only. Not a library to import.

#### No Meaningful SwiftUI Tree/Graph Visualization Libraries Exist
The Swift ecosystem does not have equivalents of JavaScript's D3.js, vis.js, or Python's networkx for SwiftUI. The few attempts on GitHub are either:
- Incomplete / abandoned
- UIKit-based (not SwiftUI)
- macOS-only

**Recommendation:** CodeBench's existing custom visualization framework (DataJourney) is the right approach. Continue building custom. The codebase already has:
- `TraceTreeLayout` -- binary tree layout (heap-indexed BFS positioning)
- `GraphLayout` -- force-directed + circular layout
- `TrieLayout` -- recursive subtree-width-based N-ary tree layout
- `SequenceBubbleRow` -- linear sequence with pointers, motions, and links
- Canvas-based edge rendering for all graph/tree types

---

## 3. Canvas vs SwiftUI Views: Decision Framework

### The Codebase Already Has the Right Hybrid Approach

The existing code uses a **hybrid strategy** that is architecturally correct:
- **Canvas** (Core Graphics): Edges, arrows, pointer motion curves, cycle arrows
- **SwiftUI Views** (positioned in ZStack): Nodes (TraceBubble), pointer badges (PointerBadge), labels

This is the optimal pattern. Here is the detailed analysis:

### When to Use Canvas

| Use Case | Why Canvas | Performance |
|----------|-----------|-------------|
| Edges between nodes | Many edges, no hit-testing needed | O(n) draw calls, no view diffing |
| Pointer motion curves | Bezier paths, no interaction | Direct Path drawing |
| Arrow heads | Tiny triangles, many of them | Fill paths, very fast |
| Grid lines / guides | Repetitive, non-interactive | Single draw pass |
| Cycle arrows | Complex curved paths | Single Path object |

Canvas advantages:
- **No view identity overhead:** SwiftUI does not diff or manage identity for Canvas draw calls
- **Batched rendering:** All draw calls in one render pass
- **Complex paths:** Bezier curves, arrow heads, dashed lines trivially drawn with Path

### When to Use SwiftUI Views

| Use Case | Why Views | Performance |
|----------|----------|-------------|
| Nodes (TraceBubble) | Need hit-testing, accessibility, animation | Individual identity needed |
| Pointer badges | Text rendering, capsule background | SwiftUI text layout |
| Labels / step counters | Dynamic text, localization | Text() handles all this |
| Interactive elements | Tap targets, hover states | Gesture system |

SwiftUI view advantages:
- **Identity-based animation:** `matchedGeometryEffect`, implicit animations on state changes
- **Accessibility:** `.accessibilityLabel`, `.accessibilityValue` per node
- **Hit testing:** Built-in tap gesture system
- **Text rendering:** Dynamic type, localization, proper text layout

### Performance Characteristics

**SwiftUI view composition breaks down at approximately:**
- **~200 positioned views in a ZStack:** Starts showing frame drops on older devices (A14 and below)
- **~500 views:** Noticeable lag even on A17 Pro
- **~1000+ views:** Unusable without virtualization

**For CodeBench specifically:**
- Typical DSA problem: 5-50 nodes. **Well within SwiftUI limits.**
- Worst case (large graph): 100 nodes + 200 edges. Nodes as views = 100 views (fine). Edges in Canvas = no issue.
- Extreme case (100x100 matrix): 10,000 cells. **Must use Canvas for cells or virtualize.**

**Recommendation for CodeBench:** The existing hybrid approach is correct. For the matrix grid view (`DataJourneyMatrixGridView`), consider switching cell rendering to Canvas if matrices larger than ~20x20 are needed. For all other data structures (trees up to depth 10, graphs up to 50 nodes, arrays up to 200 elements), the hybrid approach will perform well.

### Canvas + Resolved Text Pattern

The codebase already uses this pattern effectively (seen in `TreeGraphView` and `GraphView`):

```swift
Canvas { context, _ in
    // Draw edges as paths
    for edge in layout.edges {
        var path = Path()
        path.move(to: edge.from)
        path.addQuadCurve(to: edge.to, control: control)
        context.stroke(path, with: .color(edgeColor), lineWidth: 1.5)
    }
    // Draw text labels using resolved Text views
    let label = Text(motion.name)
        .font(VizTypography.secondaryLabel)
        .foregroundColor(motion.color)
    context.draw(context.resolve(label), at: labelPoint)
}
```

This is optimal: edges get Canvas performance, text gets proper SwiftUI rendering via `context.resolve()`.

---

## 4. Animation Techniques for Algorithm Visualization

### Architecture: State Machine + Discrete Steps (Already In Place)

The existing architecture is sound. Here is a refined version of the pattern with recommendations for enhancement:

#### Current Architecture (Keep)

```
DataJourneyAnimationController (timer)
    |
    v advances step index
DataJourneyView (state holder)
    |
    v withAnimation { selectedEventID = newEvent.id }
DataJourneyStructureCanvasView (renders structure at current step)
    |
    +-- previousEvent (for diff computation)
    +-- selectedEvent (current state)
    +-- pointerMarkers (computed from event)
    +-- diff highlights (computed from prev vs current)
```

This is the right architecture. The key insight: **the animation controller does not animate. It drives state transitions. SwiftUI animates the visual diff.**

#### Enhancement: Richer Per-Step Metadata

The current system has per-step data (values, pointers) but could benefit from richer step metadata for animation hinting:

```swift
// Proposed addition to DataJourneyEvent or a companion type
struct StepAnimationHint {
    enum Operation {
        case compare(indices: [Int])       // Highlight elements being compared
        case swap(index1: Int, index2: Int) // Animate a swap
        case visit(nodeId: String)          // Mark node as visited
        case insert(index: Int)             // Animate insertion
        case remove(index: Int)             // Animate removal
        case partition(pivotIndex: Int, boundary: Int) // Show partition boundary
        case slideWindow(left: Int, right: Int) // Show window boundaries
    }
    let operations: [Operation]
}
```

This would allow the visualization layer to choose the right micro-animation (PhaseAnimator pulse for compare, KeyframeAnimator for swap, etc.) based on what the algorithm step actually does.

#### Timer vs Gesture-Driven

**Timer-driven (current approach):** Correct for auto-play mode. The `Task.sleep`-based approach is clean and properly handles cancellation.

**Gesture-driven enhancements to consider:**
- **Swipe left/right:** Step forward/backward (already have tap on timeline chips)
- **Long press on play:** Temporary speed boost
- **Drag on timeline:** Scrub through steps

```swift
// Scrub gesture for timeline
.gesture(
    DragGesture(minimumDistance: 0)
        .onChanged { value in
            let progress = value.location.x / timelineWidth
            let stepIndex = Int(progress * CGFloat(totalSteps - 1))
            selectIndex(stepIndex.clamped(to: 0..<totalSteps))
        }
)
```

#### Reduce Motion Support

Already implemented via `@Environment(\.accessibilityReduceMotion)`. The existing pattern of falling back to `.linear(duration: 0.05)` is correct. Ensure all new animations also check this flag.

---

## 5. Force-Directed Graph Layout in Swift

### Assessment: The Existing Implementation is Good, Extend Don't Replace

**Confidence: HIGH (based on codebase analysis)**

The `GraphLayout` in `DataJourneyGraphView.swift` already implements a working Fruchterman-Reingold force-directed layout with:
- Repulsive forces between all node pairs (O(n^2))
- Attractive forces along edges
- Temperature-based cooling (0.9 decay)
- Boundary clamping
- 50 iterations
- Circular layout fallback for small graphs (<=6 nodes)

#### Current Implementation Strengths
- Correctly handles directed vs undirected detection
- Proper edge weight display
- Node-surface edge termination (edges end at node boundary, not center)
- Arrow heads for directed edges

#### Recommended Improvements

**1. Barnes-Hut approximation for graphs > 50 nodes:**
The current O(n^2) repulsive force calculation is fine for typical DSA problems (5-20 nodes) but would struggle with large adjacency matrices. Barnes-Hut reduces repulsive force computation to O(n log n).

```swift
// Only implement if you need to support graphs > 50 nodes
struct QuadTree {
    var bounds: CGRect
    var centerOfMass: CGPoint
    var totalMass: Int
    var children: [QuadTree?] // NW, NE, SW, SE

    func approximateForce(on point: CGPoint, theta: CGFloat = 0.8) -> CGPoint {
        let dx = centerOfMass.x - point.x
        let dy = centerOfMass.y - point.y
        let distance = sqrt(dx * dx + dy * dy)
        let size = max(bounds.width, bounds.height)

        if size / distance < theta || children.allSatisfy({ $0 == nil }) {
            // Treat as single body
            // ...compute force...
        } else {
            // Recurse into children
        }
    }
}
```

**Verdict:** Not needed now. DSA problems rarely have >50 nodes. File this for later if large graph support becomes necessary.

**2. Deterministic layout for consistent step-by-step visualization:**
The current circular initial placement is good, but force-directed layouts are inherently non-deterministic (floating-point sensitivity). For step-by-step visualization where the graph structure doesn't change between steps, cache the layout positions.

```swift
// Cache layout between steps when adjacency doesn't change
private var cachedPositions: [Int: CGPoint]?
private var cachedAdjacency: [[Int]]?

func layout(adjacency: [[Int]]) -> [CGPoint] {
    if adjacency == cachedAdjacency, let cached = cachedPositions {
        return Array(0..<adjacency.count).map { cached[$0]! }
    }
    // Compute new layout...
    cachedAdjacency = adjacency
    cachedPositions = // ...store result
}
```

**3. Stress-based layout as an alternative:**
For graphs where edge lengths should reflect weights, stress-based layout (Kamada-Kawai) is better than Fruchterman-Reingold. However, this is a low priority since most DSA graph problems use unweighted or uniformly-weighted edges.

### External Libraries Assessment

| Library | Status | Verdict |
|---------|--------|---------|
| SwiftGraph | Graph data structures only, no layout | Not needed |
| GraphViz (via C interop) | Powerful but heavy C dependency | Overkill |
| Custom (current) | Working Fruchterman-Reingold | Keep and enhance |

**Recommendation:** Keep the custom implementation. It's well-written and fits the project's needs. The main enhancement is layout caching for consistent positions across animation steps.

---

## 6. SwiftUI Performance for Complex Visualizations

### Concrete Performance Boundaries

| Scenario | View Count | Canvas Draw Calls | Expected FPS | Status |
|----------|-----------|-------------------|-------------|--------|
| Array (20 elements) | ~30 views | ~20 arrows | 60fps | Current, works |
| Linked list (15 nodes) | ~20 views | ~15 arrows + motions | 60fps | Current, works |
| Binary tree (depth 5, 31 nodes) | ~35 views | ~30 edges | 60fps | Current, works |
| Graph (20 nodes, ~40 edges) | ~25 views | ~45 lines + arrows | 60fps | Current, works |
| Matrix (10x10) | ~110 views | ~10 grid lines | 58-60fps | Borderline |
| Matrix (20x20) | ~420 views | ~40 grid lines | 40-50fps | Needs Canvas cells |
| Large graph (50 nodes, 100 edges) | ~55 views | ~120 lines + arrows | 55fps | Acceptable |
| Extreme graph (100 nodes) | ~105 views | ~300 lines | 45fps | Consider virtualization |

### Performance Optimization Techniques

**1. Stable identifiers for diffing (already good):**
The codebase uses `Identifiable` conformance with stable IDs throughout (`TraceListNode.id`, `TraceTreeNode.id`, `UUID()` for layout nodes). This is critical for SwiftUI's diffing performance.

**2. Avoid unnecessary view re-creation:**
```swift
// GOOD (current approach): Precompute layout once, position views
let layout = TraceTreeLayout(tree: tree, nodeSize: nodeSize, levelSpacing: levelSpacing)
ForEach(layout.nodes) { node in
    TraceValueNode(value: node.value, size: nodeSize)
        .position(node.position)
}

// BAD: Recomputing layout inside ForEach body
```

**3. Canvas for edges (already correct):**
Drawing 30+ edges as SwiftUI `Path` shapes would create 30+ view identities. Drawing them in a single Canvas pass creates zero view overhead.

**4. drawingGroup() for heavy Canvas content:**
If Canvas rendering becomes slow (unlikely for DSA-scale problems), `drawingGroup()` forces Metal-backed rendering:

```swift
Canvas { context, size in
    // Heavy drawing...
}
.drawingGroup() // Renders to offscreen Metal texture
```

**Use sparingly:** Only if profiling shows Canvas as a bottleneck. For typical DSA problems, it won't be.

**5. Lazy rendering for large sequences:**
For arrays/matrices with many elements, consider only rendering visible elements:

```swift
ScrollView(.horizontal) {
    LazyHStack(spacing: bubbleSpacing) {
        ForEach(items.indices, id: \.self) { index in
            TraceBubble(text: items[index].shortDescription, ...)
        }
    }
}
```

**Caution:** `LazyHStack` creates views on demand, which means animation of off-screen elements may not work as expected. For arrays up to ~100 elements, non-lazy `HStack` inside `ScrollView` (the current approach) is fine.

**6. Equatable conformance for views:**
For complex views that receive many inputs, implement `Equatable` to short-circuit unnecessary body evaluations:

```swift
struct TraceBubble: View, Equatable {
    let text: String
    let fill: Color
    let size: CGFloat
    let style: Style
    let highlighted: Bool

    static func == (lhs: TraceBubble, rhs: TraceBubble) -> Bool {
        lhs.text == rhs.text && lhs.size == rhs.size &&
        lhs.highlighted == rhs.highlighted
        // Intentionally skip fill comparison if it's derived from theme
    }

    var body: some View { ... }
}
```

---

## Recommended Stack Summary

### Core Framework

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| SwiftUI | iOS 26+ | UI framework | Already in use, first-class animation support |
| Swift | 6.2+ | Language | Already in use, strict concurrency |
| Canvas (SwiftUI) | iOS 15+ | Edge/path rendering | Already in use, optimal for non-interactive elements |

### Animation APIs (Priority Order)

| API | Min iOS | Purpose | When to Use |
|-----|---------|---------|-------------|
| `withAnimation` + state changes | 13 | Step-by-step transitions | Primary mechanism for all step changes |
| `.animation(_, value:)` | 13 | Implicit animations on data change | Bubble positions, sizes on data update |
| `matchedGeometryEffect` | 14 | Element identity across layouts | Node movement during list/tree restructuring |
| `contentTransition(.numericText())` | 16 | Value change animation | DP table fills, counter updates |
| `PhaseAnimator` | 17 | Multi-phase micro-animations | Compare pulse, visit highlight |
| `KeyframeAnimator` | 17 | Coordinated multi-property animation | Array swaps, tree rotations |

### Layout Algorithms (Custom, No External Dependencies)

| Algorithm | Purpose | Status |
|-----------|---------|--------|
| Heap-indexed BFS positioning | Binary tree layout | Exists (`TraceTreeLayout`) |
| Recursive subtree-width | N-ary tree / trie layout | Exists (`TrieLayout`) |
| Fruchterman-Reingold | Force-directed graph layout | Exists (`GraphLayout`) |
| Circular layout | Small graph layout (<=6 nodes) | Exists (`GraphLayout`) |
| Linear sequence with gaps | Linked list / array | Exists (`SequenceBubbleRow`) |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| None (zero external dependencies) | -- | -- | The entire visualization stack is custom SwiftUI |

### Explicitly NOT Recommended

| Library | Why Not |
|---------|---------|
| SwiftGraph | Graph data structures only, CodeBench already has adjacency-based layout |
| Lottie | Pre-baked animations, not dynamic data-driven visualization |
| SpriteKit | Game engine overhead, not needed for educational visualization |
| SceneKit/RealityKit | 3D rendering, completely wrong abstraction |
| UIKit animations | Would break SwiftUI integration, no benefit |
| D3.js via WKWebView | Web bridge latency, accessibility loss, platform mismatch |

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Animation driver | Task.sleep timer (current) | Combine Timer publisher | Task-based is simpler, already works, proper cancellation |
| Edge rendering | Canvas | SwiftUI Path shapes | Canvas avoids per-edge view identity overhead |
| Node rendering | SwiftUI Views | Canvas-only | Views provide accessibility, hit-testing, animation identity |
| Graph layout | Custom Fruchterman-Reingold | GraphViz via C interop | Massive dependency for marginal improvement |
| Tree layout | Custom BFS positioning | Reingold-Tilford algorithm | BFS heap-indexed is simpler, good enough for balanced trees |
| State management | @Observable / @StateObject | Redux/TCA architecture | Overkill for single-screen visualization; MVVM is sufficient |

---

## Installation

```bash
# No package installations needed.
# The entire visualization stack is custom SwiftUI with zero external dependencies.
# This is intentional and should remain so.
```

The project uses XcodeGen (`project.yml`) for project generation:

```bash
xcodegen generate
```

---

## Key Architectural Decisions for New Work

### For Array Visualization Enhancements (swaps, partitions, sliding windows)

**Use:** `SequenceBubbleRow` (existing) + `KeyframeAnimator` (new) for swap animations + `PhaseAnimator` (new) for comparison highlights.

The existing `highlightedIndices`, `changeTypes`, and `pointerMarkers` provide the data layer. The enhancement is adding richer micro-animations on top.

### For Tree Visualization Enhancements (traversal, insertions)

**Use:** `TreeGraphView` (existing) + `matchedGeometryEffect` (new) for node repositioning after insertions + `PhaseAnimator` (new) for traversal visit highlighting.

The existing `highlightedNodeIds` and `pointerMotions` (TreePointerMotion) provide the data layer.

### For Graph Visualization Enhancements (BFS/DFS, visited nodes, paths)

**Use:** `GraphView` (existing) + extend `visitedNodeIndices` to support a richer visited/frontier/unvisited state model + Canvas color-coded edges for explored vs unexplored.

The existing `visitedNodeIndices` dimming is a foundation. Extend to support:
- Unvisited: full opacity
- Frontier (current): highlighted
- Visited: dimmed with colored border

### For Linked List Enhancements (pointer rewiring)

**Use:** `SequenceBubbleRow` with `PointerMotion` (existing) + extend to support node insertion/deletion animations with `matchedGeometryEffect` on node IDs.

The existing `listPointerMotions` already shows pointer movement between steps. The enhancement is animating structural changes (node appearing/disappearing).

---

## Sources

- Apple Developer Documentation: SwiftUI Animation framework (iOS 17+ APIs: PhaseAnimator, KeyframeAnimator) -- **Not directly fetched due to tool limitations; based on training data through mid-2025**
- Codebase analysis: Full read of all 40+ Swift files in the DataJourney framework
- Fruchterman-Reingold algorithm: "Graph Drawing by Force-directed Placement" (1991) -- well-established algorithm, implementation in codebase matches published approach
- SwiftUI performance characteristics based on Apple WWDC sessions (2021-2024) and community benchmarks

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Existing codebase analysis | HIGH | Read all source files directly |
| SwiftUI animation APIs (iOS 17-18) | HIGH | Well-established APIs in training data |
| iOS 26-specific features | LOW | Cannot verify; flagged as needing validation after WWDC 2025 |
| Performance thresholds | MEDIUM | Based on training data benchmarks, not profiled on target device |
| Library ecosystem assessment | MEDIUM | Could not verify current state of Swift Package Index |
| Force-directed layout recommendations | HIGH | Based on direct codebase analysis + established graph theory |
